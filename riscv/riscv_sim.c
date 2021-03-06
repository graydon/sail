#include <getopt.h>
#include <stdio.h>
#include <stdlib.h>
#include <errno.h>
#include <unistd.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <sys/mman.h>
#include <fcntl.h>

#include "elf.h"
#include "sail.h"
#include "rts.h"
#include "riscv_platform.h"
#include "riscv_platform_impl.h"
#include "riscv_sail.h"

//#define SPIKE 1
#ifdef SPIKE
#include "tv_spike_intf.h"
#else
struct tv_spike_t;
#endif

/* Selected CSRs from riscv-isa-sim/riscv/encoding.h */
#define CSR_STVEC 0x105
#define CSR_SEPC 0x141
#define CSR_SCAUSE 0x142
#define CSR_STVAL 0x143

#define CSR_MSTATUS 0x300
#define CSR_MISA 0x301
#define CSR_MEDELEG 0x302
#define CSR_MIDELEG 0x303
#define CSR_MIE 0x304
#define CSR_MTVEC 0x305
#define CSR_MEPC 0x341
#define CSR_MCAUSE 0x342
#define CSR_MTVAL 0x343
#define CSR_MIP 0x344

static bool do_dump_dts = false;
struct tv_spike_t *s = NULL;
char *term_log = NULL;
char *dtb_file = NULL;
unsigned char *dtb = NULL;
size_t dtb_len = 0;

unsigned char *spike_dtb = NULL;
size_t spike_dtb_len = 0;

static struct option options[] = {
  {"enable-dirty",                no_argument,       0, 'd'},
  {"enable-misaligned",           no_argument,       0, 'm'},
  {"ram-size",                    required_argument, 0, 'z'},
  {"mtval-has-illegal-inst-bits", no_argument,       0, 'i'},
  {"dump-dts",                    no_argument,       0, 's'},
  {"device-tree-blob",            required_argument, 0, 'b'},
  {"terminal-log",                required_argument, 0, 't'},
  {"help",                        no_argument,       0, 'h'},
  {0, 0, 0, 0}
};

static void print_usage(const char *argv0, int ec)
{
  fprintf(stdout, "Usage: %s [options] <elf_file>\n", argv0);
  struct option *opt = options;
  while (opt->name) {
    fprintf(stdout, "\t -%c\t %s\n", (char)opt->val, opt->name);
    opt++;
  }
  exit(ec);
}

static void dump_dts(void)
{
#ifdef SPIKE
  size_t dts_len = 0;
  struct tv_spike_t *s = tv_init("RV64IMAC", rv_ram_size, 0);
  tv_get_dts(s, NULL, &dts_len);
  if (dts_len > 0) {
    unsigned char *dts = (unsigned char *)malloc(dts_len + 1);
    dts[dts_len] = '\0';
    tv_get_dts(s, dts, &dts_len);
    fprintf(stdout, "%s\n", dts);
  }
#else
  fprintf(stdout, "Spike linkage is currently needed to generate DTS.\n");
#endif
  exit(0);
}

static void read_dtb(const char *path)
{
  int fd = open(path, O_RDONLY);
  if (fd < 0) {
    fprintf(stderr, "Unable to read DTB file %s: %s\n", path, strerror(errno));
    exit(1);
  }
  struct stat st;
  if (fstat(fd, &st) < 0) {
    fprintf(stderr, "Unable to stat DTB file %s: %s\n", path, strerror(errno));
    exit(1);
  }
  char *m = (char *)mmap(NULL, st.st_size, PROT_READ, MAP_PRIVATE, fd, 0);
  if (m == MAP_FAILED) {
    fprintf(stderr, "Unable to map DTB file %s: %s\n", path, strerror(errno));
    exit(1);
  }
  dtb = (unsigned char *)malloc(st.st_size);
  if (dtb == NULL) {
    fprintf(stderr, "Cannot allocate DTB from file %s!\n", path);
    exit(1);
  }
  memcpy(dtb, m, st.st_size);
  dtb_len = st.st_size;
  munmap(m, st.st_size);
  close(fd);

  fprintf(stdout, "Read %ld bytes of DTB from %s.\n", dtb_len, path);
}

char *process_args(int argc, char **argv)
{
  int c, idx = 1;
  uint64_t ram_size = 0;
  while(true) {
    c = getopt_long(argc, argv, "dmsz:b:t:v:h", options, &idx);
    if (c == -1) break;
    switch (c) {
    case 'd':
      fprintf(stderr, "enabling dirty update.\n");
      rv_enable_dirty_update = true;
      break;
    case 'm':
      fprintf(stderr, "enabling misaligned access.\n");
      rv_enable_misaligned = true;
      break;
    case 'i':
      rv_mtval_has_illegal_inst_bits = true;
    case 's':
      do_dump_dts = true;
      break;
    case 'z':
      ram_size = atol(optarg);
      if (ram_size) {
        fprintf(stderr, "setting ram-size to %ld MB\n", ram_size);
        rv_ram_size = ram_size << 20;
      }
      break;
    case 'b':
      dtb_file = strdup(optarg);
      break;
    case 't':
      term_log = strdup(optarg);
      break;
    case 'h':
      print_usage(argv[0], 0);
      break;
    default:
      fprintf(stderr, "Unrecognized optchar %c\n", c);
      print_usage(argv[0], 1);
    }
  }
  if (do_dump_dts) dump_dts();
  if (idx >= argc) print_usage(argv[0], 0);
  if (term_log == NULL) term_log = strdup("term.log");
  if (dtb_file) read_dtb(dtb_file);

  fprintf(stdout, "Running file %s.\n", argv[optind]);
  return argv[optind];
}

uint64_t load_sail(char *f)
{
  bool is32bit;
  uint64_t entry;
  load_elf(f, &is32bit, &entry);
  if (is32bit) {
    fprintf(stderr, "32-bit RISC-V not yet supported.\n");
    exit(1);
  }
  fprintf(stdout, "ELF Entry @ %lx\n", entry);
  /* locate htif ports */
  if (lookup_sym(f, "tohost", &rv_htif_tohost) < 0) {
    fprintf(stderr, "Unable to locate htif tohost port.\n");
    exit(1);
  }
  fprintf(stderr, "tohost located at %0" PRIx64 "\n", rv_htif_tohost);
  return entry;
}

void init_spike(const char *f, uint64_t entry, uint64_t ram_size)
{
#ifdef SPIKE
  bool mismatch = false;
  s = tv_init("RV64IMAC", ram_size, 1);
  if (tv_is_dirty_enabled(s) != rv_enable_dirty_update) {
    mismatch = true;
    fprintf(stderr, "inconsistent enable-dirty-update setting: spike %s, sail %s\n",
            tv_is_dirty_enabled(s) ? "on" : "off",
            rv_enable_dirty_update ? "on" : "off");
  }
  if (tv_is_misaligned_enabled(s) != rv_enable_misaligned) {
    mismatch = true;
    fprintf(stderr, "inconsistent enable-misaligned-access setting: spike %s, sail %s\n",
            tv_is_misaligned_enabled(s) ? "on" : "off",
            rv_enable_misaligned        ? "on" : "off");
  }
  if (tv_ram_size(s) != rv_ram_size) {
    mismatch = true;
    fprintf(stderr, "inconsistent ram-size setting: spike %lx, sail %lx\n",
            tv_ram_size(s), rv_ram_size);
  }
  if (mismatch) exit(1);

  /* The initialization order below matters. */
  tv_set_verbose(s, 1);
  tv_set_dtb_in_rom(s, 1);
  tv_load_elf(s, f);
  tv_reset(s);

  /* sync the insns per tick */
  rv_insns_per_tick = tv_get_insns_per_tick(s);

  /* get DTB from spike */
  tv_get_dtb(s, NULL, &spike_dtb_len);
  if (spike_dtb_len > 0) {
    spike_dtb = (unsigned char *)malloc(spike_dtb_len + 1);
    spike_dtb[spike_dtb_len] = '\0';
    if (!tv_get_dtb(s, spike_dtb, &spike_dtb_len)) {
      fprintf(stderr, "Got %ld bytes of dtb at %p\n", spike_dtb_len, spike_dtb);
    } else {
      fprintf(stderr, "Error getting DTB from Spike.\n");
      exit(1);
    }
  } else {
    fprintf(stderr, "No DTB available from Spike.\n");
  }
#else
  s = NULL;
#endif
}

void tick_spike()
{
#ifdef SPIKE
  tv_tick_clock(s);
  tv_step_io(s);
#endif
}

void init_sail_reset_vector(uint64_t entry)
{
#define RST_VEC_SIZE 8
  uint32_t reset_vec[RST_VEC_SIZE] = {
    0x297,                                      // auipc  t0,0x0
    0x28593 + (RST_VEC_SIZE * 4 << 20),         // addi   a1, t0, &dtb
    0xf1402573,                                 // csrr   a0, mhartid
    SAIL_XLEN == 32 ?
      0x0182a283u :                             // lw     t0,24(t0)
      0x0182b283u,                              // ld     t0,24(t0)
    0x28067,                                    // jr     t0
    0,
    (uint32_t) (entry & 0xffffffff),
    (uint32_t) (entry >> 32)
  };

  rv_rom_base = DEFAULT_RSTVEC;
  uint64_t addr = rv_rom_base;
  for (int i = 0; i < sizeof(reset_vec); i++)
    write_mem(addr++, (uint64_t)((char *)reset_vec)[i]);

  if (dtb && dtb_len) {
    for (size_t i = 0; i < dtb_len; i++)
      write_mem(addr++, dtb[i]);
  }

#ifdef SPIKE
  if (dtb && dtb_len) {
    // Ensure that Spike's DTB matches the one provided.
    bool matched = dtb_len == spike_dtb_len;
    if (matched) {
      for (size_t i = 0; i < dtb_len; i++)
        matched = matched && (dtb[i] == spike_dtb[i]);
    }
    if (!matched) {
      fprintf(stderr, "Provided DTB does not match Spike's!\n");
      exit(1);
    }
  } else {
    if (spike_dtb_len > 0) {
      // Use the DTB from Spike.
      for (size_t i = 0; i < spike_dtb_len; i++)
        write_mem(addr++, spike_dtb[i]);
    } else {
      fprintf(stderr, "Running without rom device tree.\n");
    }
  }
#endif

  /* zero-fill to page boundary */
  const int align = 0x1000;
  uint64_t rom_end = (addr + align -1)/align * align;
  for (int i = addr; i < rom_end; i++)
    write_mem(addr++, 0);

  /* set rom size */
  rv_rom_size = rom_end - rv_rom_base;
  /* boot at reset vector */
  zPC = rv_rom_base;
}

void init_sail(uint64_t elf_entry)
{
  model_init();
  zinit_platform(UNIT);
  zinit_sys(UNIT);
  init_sail_reset_vector(elf_entry);
}

int init_check(struct tv_spike_t *s)
{
  int passed = 1;
#ifdef SPIKE
  passed &= tv_check_csr(s, CSR_MISA, zmisa.zMisa_chunk_0);
#endif
  return passed;
}

void finish(int ec)
{
  model_fini();
#ifdef SPIKE
  tv_free(s);
#endif
  exit(ec);
}

int compare_states(struct tv_spike_t *s)
{
  int passed = 1;

#ifdef SPIKE
  // fix default C enum map for cur_privilege
  uint8_t priv = (zcur_privilege == 2) ? 3 : zcur_privilege;
  passed &= tv_check_priv(s, priv);

  passed &= tv_check_pc(s, zPC);

  passed &= tv_check_gpr(s, 1, zx1);
  passed &= tv_check_gpr(s, 2, zx2);
  passed &= tv_check_gpr(s, 3, zx3);
  passed &= tv_check_gpr(s, 4, zx4);
  passed &= tv_check_gpr(s, 5, zx5);
  passed &= tv_check_gpr(s, 6, zx6);
  passed &= tv_check_gpr(s, 7, zx7);
  passed &= tv_check_gpr(s, 8, zx8);
  passed &= tv_check_gpr(s, 9, zx9);
  passed &= tv_check_gpr(s, 10, zx10);
  passed &= tv_check_gpr(s, 11, zx11);
  passed &= tv_check_gpr(s, 12, zx12);
  passed &= tv_check_gpr(s, 13, zx13);
  passed &= tv_check_gpr(s, 14, zx14);
  passed &= tv_check_gpr(s, 15, zx15);
  passed &= tv_check_gpr(s, 15, zx15);
  passed &= tv_check_gpr(s, 16, zx16);
  passed &= tv_check_gpr(s, 17, zx17);
  passed &= tv_check_gpr(s, 18, zx18);
  passed &= tv_check_gpr(s, 19, zx19);
  passed &= tv_check_gpr(s, 20, zx20);
  passed &= tv_check_gpr(s, 21, zx21);
  passed &= tv_check_gpr(s, 22, zx22);
  passed &= tv_check_gpr(s, 23, zx23);
  passed &= tv_check_gpr(s, 24, zx24);
  passed &= tv_check_gpr(s, 25, zx25);
  passed &= tv_check_gpr(s, 25, zx25);
  passed &= tv_check_gpr(s, 26, zx26);
  passed &= tv_check_gpr(s, 27, zx27);
  passed &= tv_check_gpr(s, 28, zx28);
  passed &= tv_check_gpr(s, 29, zx29);
  passed &= tv_check_gpr(s, 30, zx30);
  passed &= tv_check_gpr(s, 31, zx31);

  /* some selected CSRs for now */

  passed &= tv_check_csr(s, CSR_MCAUSE, zmcause.zMcause_chunk_0);
  passed &= tv_check_csr(s, CSR_MEPC, zmepc);
  passed &= tv_check_csr(s, CSR_MTVAL, zmtval);
  passed &= tv_check_csr(s, CSR_MSTATUS, zmstatus);

  passed &= tv_check_csr(s, CSR_SCAUSE, zscause.zMcause_chunk_0);
  passed &= tv_check_csr(s, CSR_SEPC, zsepc);
  passed &= tv_check_csr(s, CSR_STVAL, zstval);
#endif

  return passed;
}

void flush_logs(void)
{
  fprintf(stderr, "\n");
  fflush(stderr);
  fprintf(stdout, "\n");
  fflush(stdout);
}

void run_sail(void)
{
  bool spike_done;
  bool stepped;
  bool diverged = false;

  /* initialize the step number */
  mach_int step_no = 0;
  int insn_cnt = 0;

  while (!zhtif_done) {
    { /* run a Sail step */
      sail_int sail_step;
      CREATE(sail_int)(&sail_step);
      CONVERT_OF(sail_int, mach_int)(&sail_step, step_no);
      stepped = zstep(sail_step);
      if (have_exception) goto step_exception;
      flush_logs();
    }
    if (stepped) {
      step_no++;
      insn_cnt++;
    }

#ifdef SPIKE
    { /* run a Spike step */
      tv_step(s);
      spike_done = tv_is_done(s);
      flush_logs();
    }

    if (zhtif_done) {
      if (!spike_done) {
        fprintf(stdout, "Sail done (exit-code %ld), but not Spike!\n", zhtif_exit_code);
        exit(1);
      }
    } else {
      if (spike_done) {
        fprintf(stdout, "Spike done, but not Sail!\n");
        exit(1);
      }
    }
    if (!compare_states(s)) {
      diverged = true;
      break;
    }
#endif
    if (zhtif_done) {
      /* check exit code */
      if (zhtif_exit_code == 0)
        fprintf(stdout, "SUCCESS\n");
      else
        fprintf(stdout, "FAILURE: %ld\n", zhtif_exit_code);
    }

    if (insn_cnt == rv_insns_per_tick) {
      insn_cnt = 0;
      ztick_clock(UNIT);
      ztick_platform(UNIT);

      tick_spike();
    }
  }

 dump_state:
  if (diverged) {
    /* TODO */
  }
  finish(diverged);

 step_exception:
  fprintf(stderr, "Sail exception!");
  goto dump_state;
}

void init_logs()
{
#ifdef SPIKE
  // The Spike interface uses stdout for terminal output, and stderr for logs.
  // Do the same here.
  if (dup2(1, 2) < 0) {
    fprintf(stderr, "Unable to dup 1 -> 2: %s\n", strerror(errno));
    exit(1);
  }
#endif

  if ((term_fd = open(term_log, O_WRONLY|O_CREAT|O_TRUNC, S_IRUSR|S_IRGRP|S_IROTH|S_IWUSR)) < 0) {
    fprintf(stderr, "Cannot create terminal log '%s': %s\n", term_log, strerror(errno));
    exit(1);
  }
}

int main(int argc, char **argv)
{
  char *file = process_args(argc, argv);
  init_logs();

  uint64_t entry = load_sail(file);

  /* initialize spike before sail so that we can access the device-tree blob,
   * until we roll our own.
   */
  init_spike(file, entry, rv_ram_size);
  init_sail(entry);

  if (!init_check(s)) finish(1);

  run_sail();
  flush_logs();
}
