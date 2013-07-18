(* generated by Ott 0.22 from: l2_parse.ott *)


type text = string

type l =
  | Unknown
  | Trans of string * l option
  | Range of Lexing.position * Lexing.position

type 'a annot = l * 'a

exception Parse_error_locn of l * string

type ml_comment = 
  | Chars of string
  | Comment of ml_comment list

type lex_skip =
  | Com of ml_comment
  | Ws of string
  | Nl

type lex_skips = lex_skip list option

let pp_lex_skips ppf sk = 
  match sk with
    | None -> ()
    | Some(sks) ->
        List.iter
          (fun sk ->
             match sk with
               | Com(ml_comment) ->
                   (* TODO: fix? *)
                   Format.fprintf ppf "(**)"
               | Ws(r) ->
                   Format.fprintf ppf "%s" r (*(Ulib.Text.to_string r)*)
               | Nl -> Format.fprintf ppf "\\n")
          sks

let combine_lex_skips s1 s2 =
  match (s1,s2) with
    | (None,_) -> s2
    | (_,None) -> s1
    | (Some(s1),Some(s2)) -> Some(s2@s1)

type terminal = lex_skips


type x = terminal * text (* identifier *)
type ix = terminal * text (* infix identifier *)

type 
base_kind_aux =  (* base kind *)
   BK_type of terminal (* kind of types *)
 | BK_nat of terminal (* kind of natural number size expressions *)
 | BK_order of terminal (* kind of vector order specifications *)
 | BK_effects of terminal (* kind of effect sets *)


type 
efct_aux =  (* effect *)
   Effect_rreg of terminal (* read register *)
 | Effect_wreg of terminal (* write register *)
 | Effect_rmem of terminal (* read memory *)
 | Effect_wmem of terminal (* write memory *)
 | Effect_undef of terminal (* undefined-instruction exception *)
 | Effect_unspec of terminal (* unspecified values *)
 | Effect_nondet of terminal (* nondeterminism from intra-instruction parallelism *)


type 
id_aux =  (* Identifier *)
   Id of x
 | DeIid of terminal * x * terminal (* remove infix status *)


type 
base_kind = 
   BK_aux of base_kind_aux * l


type 
efct = 
   Effect_aux of efct_aux * l


type 
id = 
   Id_aux of id_aux * l


type 
kind_aux =  (* kinds *)
   K_kind of (base_kind * terminal) list


type 
atyp_aux =  (* expression of all kinds *)
   ATyp_id of id (* identifier *)
 | ATyp_constant of (terminal * int) (* constant *)
 | ATyp_times of atyp * terminal * atyp (* product *)
 | ATyp_sum of atyp * terminal * atyp (* sum *)
 | ATyp_exp of terminal * terminal * atyp (* exponential *)
 | ATyp_inc of terminal (* increasing (little-endian) *)
 | ATyp_dec of terminal (* decreasing (big-endian) *)
 | ATyp_efid of terminal * id
 | ATyp_set of terminal * terminal * (efct * terminal) list * terminal (* effect set *)
 | ATyp_wild of terminal (* Unspecified type *)
 | ATyp_fn of atyp * terminal * atyp * atyp (* Function type (first-order only in user code) *)
 | ATyp_tup of (atyp * terminal) list (* Tuple type *)
 | ATyp_app of id * (atyp) list (* type constructor application *)

and atyp = 
   ATyp_aux of atyp_aux * l


type 
kind = 
   K_aux of kind_aux * l


type 
'a nexp_constraint_aux =  (* constraint over kind $_$ *)
   NC_fixed of atyp * terminal * atyp
 | NC_bounded_ge of atyp * terminal * atyp
 | NC_bounded_le of atyp * terminal * atyp
 | NC_nat_set_bounded of id * terminal * terminal * ((terminal * int) * terminal) list * terminal


type 
kinded_id_aux =  (* optionally kind-annotated identifier *)
   KOpt_none of id (* identifier *)
 | KOpt_kind of kind * id (* kind-annotated variable *)


type 
'a nexp_constraint = 
   NC_aux of 'a nexp_constraint_aux * 'a annot


type 
kinded_id = 
   KOpt_aux of kinded_id_aux * l


type 
'a typquant_aux =  (* type quantifiers and constraints *)
   TypQ_tq of terminal * (kinded_id) list * terminal * ('a nexp_constraint * terminal) list * terminal
 | TypQ_no_constraint of terminal * (kinded_id) list * terminal (* sugar, omitting constraints *)
 | TypQ_no_forall (* sugar, omitting quantifier and constraints *)


type 
lit_aux =  (* Literal constant *)
   L_unit of terminal * terminal (* $() : _$ *)
 | L_zero of terminal (* $_ : _$ *)
 | L_one of terminal (* $_ : _$ *)
 | L_true of terminal (* $_ : _$ *)
 | L_false of terminal (* $_ : _$ *)
 | L_num of (terminal * int) (* natural number constant *)
 | L_hex of terminal * string (* bit vector constant, C-style *)
 | L_bin of terminal * string (* bit vector constant, C-style *)
 | L_string of terminal * string (* string constant *)


type 
'a typquant = 
   TypQ_aux of 'a typquant_aux * 'a annot


type 
lit = 
   L_aux of lit_aux * l


type 
'a typschm_aux =  (* type scheme *)
   TypSchm_ts of 'a typquant * atyp


type 
'a pat_aux =  (* Pattern *)
   P_lit of lit (* literal constant pattern *)
 | P_wild of terminal (* wildcard *)
 | P_as of terminal * 'a pat * terminal * id * terminal (* named pattern *)
 | P_typ of terminal * atyp * 'a pat * terminal (* typed pattern *)
 | P_id of id (* identifier *)
 | P_app of id * ('a pat) list (* union constructor pattern *)
 | P_record of terminal * ('a fpat * terminal) list * terminal * bool * terminal (* struct pattern *)
 | P_vector of terminal * ('a pat * terminal) list * terminal (* vector pattern *)
 | P_vector_indexed of terminal * (((terminal * int) * terminal * 'a pat) * terminal) list * terminal (* vector pattern (with explicit indices) *)
 | P_vector_concat of ('a pat * terminal) list (* concatenated vector pattern *)
 | P_tup of terminal * ('a pat * terminal) list * terminal (* tuple pattern *)
 | P_list of terminal * ('a pat * terminal) list * terminal (* list pattern *)

and 'a pat = 
   P_aux of 'a pat_aux * 'a annot

and 'a fpat_aux =  (* Field pattern *)
   FP_Fpat of id * terminal * 'a pat

and 'a fpat = 
   FP_aux of 'a fpat_aux * 'a annot


type 
'a typschm = 
   TypSchm_aux of 'a typschm_aux * 'a annot


type 
'a exp_aux =  (* Expression *)
   E_block of terminal * ('a exp * terminal) list * terminal (* block (parsing conflict with structs?) *)
 | E_id of id (* identifier *)
 | E_lit of lit (* literal constant *)
 | E_cast of terminal * atyp * terminal * 'a exp (* cast *)
 | E_app of 'a exp * ('a exp) list (* function application *)
 | E_app_infix of 'a exp * id * 'a exp (* infix function application *)
 | E_tuple of terminal * ('a exp * terminal) list * terminal (* tuple *)
 | E_if of terminal * 'a exp * terminal * 'a exp * terminal * 'a exp (* conditional *)
 | E_vector of terminal * ('a exp * terminal) list * terminal (* vector (indexed from 0) *)
 | E_vector_indexed of terminal * (((terminal * int) * terminal * 'a exp) * terminal) list * terminal (* vector (indexed consecutively) *)
 | E_vector_access of 'a exp * terminal * 'a exp * terminal (* vector access *)
 | E_vector_subrange of 'a exp * terminal * 'a exp * terminal * 'a exp * terminal (* subvector extraction *)
 | E_vector_update of terminal * 'a exp * terminal * 'a exp * terminal * 'a exp * terminal (* vector functional update *)
 | E_vector_update_subrange of terminal * 'a exp * terminal * 'a exp * terminal * 'a exp * terminal * 'a exp * terminal (* vector subrange update (with vector) *)
 | E_list of terminal * ('a exp * terminal) list * terminal (* list *)
 | E_cons of 'a exp * terminal * 'a exp (* cons *)
 | E_record of terminal * 'a fexps * terminal (* struct *)
 | E_record_update of terminal * 'a exp * terminal * 'a fexps * terminal (* functional update of struct *)
 | E_field of 'a exp * terminal * id (* field projection from struct *)
 | E_case of terminal * 'a exp * terminal * ((terminal * 'a pexp)) list * terminal (* pattern matching *)
 | E_let of 'a letbind * terminal * 'a exp (* let expression *)
 | E_assign of 'a lexp * terminal * 'a exp (* imperative assignment *)

and 'a exp = 
   E_aux of 'a exp_aux * 'a annot

and 'a lexp_aux =  (* lvalue expression *)
   LEXP_id of id (* identifier *)
 | LEXP_vector of 'a lexp * terminal * 'a exp * terminal (* vector element *)
 | LEXP_vector_range of 'a lexp * terminal * 'a exp * terminal * 'a exp * terminal (* subvector *)
 | LEXP_field of 'a lexp * terminal * id (* struct field *)

and 'a lexp = 
   LEXP_aux of 'a lexp_aux * 'a annot

and 'a fexp_aux =  (* Field-expression *)
   FE_Fexp of id * terminal * 'a exp

and 'a fexp = 
   FE_aux of 'a fexp_aux * 'a annot

and 'a fexps_aux =  (* Field-expression list *)
   FES_Fexps of ('a fexp * terminal) list * terminal * bool

and 'a fexps = 
   FES_aux of 'a fexps_aux * 'a annot

and 'a pexp_aux =  (* Pattern match *)
   Pat_exp of 'a pat * terminal * 'a exp

and 'a pexp = 
   Pat_aux of 'a pexp_aux * 'a annot

and 'a letbind_aux =  (* Let binding *)
   LB_val_explicit of 'a typschm * 'a pat * terminal * 'a exp (* value binding, explicit type ('a pat must be total) *)
 | LB_val_implicit of terminal * 'a pat * terminal * 'a exp (* value binding, implicit type ('a pat must be total) *)

and 'a letbind = 
   LB_aux of 'a letbind_aux * 'a annot


type 
'a funcl_aux =  (* Function clause *)
   FCL_Funcl of id * 'a pat * terminal * 'a exp


type 
rec_opt_aux =  (* Optional recursive annotation for functions *)
   Rec_nonrec (* non-recursive *)
 | Rec_rec of terminal (* recursive *)


type 
'a effects_opt_aux =  (* Optional effect annotation for functions *)
   Effects_opt_pure (* sugar for empty effect set *)
 | Effects_opt_effects of terminal


type 
'a tannot_opt_aux =  (* Optional type annotation for functions *)
   Typ_annot_opt_none
 | Typ_annot_opt_some of terminal * terminal


type 
naming_scheme_opt_aux =  (* Optional variable-naming-scheme specification for variables of defined type *)
   Name_sect_none
 | Name_sect_some of terminal * terminal * terminal * terminal * string * terminal


type 
'a funcl = 
   FCL_aux of 'a funcl_aux * 'a annot


type 
rec_opt = 
   Rec_aux of rec_opt_aux * l


type 
'a effects_opt = 
   Effects_opt_aux of 'a effects_opt_aux * 'a annot


type 
'a tannot_opt = 
   Typ_annot_opt_aux of 'a tannot_opt_aux * 'a annot


type 
index_range_aux =  (* index specification, for bitfields in register types *)
   BF_single of (terminal * int) (* single index *)
 | BF_range of (terminal * int) * terminal * (terminal * int) (* index range *)
 | BF_concat of index_range * terminal * index_range (* concatenation of index ranges *)

and index_range = 
   BF_aux of index_range_aux * l


type 
naming_scheme_opt = 
   Name_sect_aux of naming_scheme_opt_aux * l


type 
'a fundef_aux =  (* Function definition *)
   FD_function of terminal * rec_opt * 'a tannot_opt * 'a effects_opt * ('a funcl * terminal) list


type 
'a type_def_aux =  (* Type definition body *)
   TD_abbrev of terminal * id * naming_scheme_opt * terminal * 'a typschm (* type abbreviation *)
 | TD_record of terminal * id * naming_scheme_opt * terminal * terminal * terminal * 'a typquant * terminal * ((atyp * id) * terminal) list * terminal * bool * terminal (* struct type definition *)
 | TD_variant of terminal * id * naming_scheme_opt * terminal * terminal * terminal * 'a typquant * terminal * ((atyp * id) * terminal) list * terminal * bool * terminal (* union type definition *)
 | TD_enum of terminal * id * naming_scheme_opt * terminal * terminal * terminal * (id * terminal) list * terminal * bool * terminal (* enumeration type definition *)
 | TD_register of terminal * id * terminal * terminal * terminal * terminal * terminal * terminal * terminal * terminal * terminal * ((index_range * terminal * id) * terminal) list * terminal (* register mutable bitfield type definition *)


type 
'a default_typing_spec_aux =  (* Default kinding or typing assumption *)
   DT_kind of terminal * base_kind * id
 | DT_typ of terminal * 'a typschm * id


type 
'a val_spec_aux =  (* Value type specification *)
   VS_val_spec of terminal * 'a typschm * id


type 
'a fundef = 
   FD_aux of 'a fundef_aux * 'a annot


type 
'a type_def = 
   TD_aux of 'a type_def_aux * 'a annot


type 
'a default_typing_spec = 
   DT_aux of 'a default_typing_spec_aux * 'a annot


type 
'a val_spec = 
   VS_aux of 'a val_spec_aux * 'a annot


type 
'a def_aux =  (* Top-level definition *)
   DEF_type of 'a type_def (* type definition *)
 | DEF_fundef of 'a fundef (* function definition *)
 | DEF_val of 'a letbind (* value definition *)
 | DEF_spec of 'a val_spec (* top-level type constraint *)
 | DEF_default of 'a default_typing_spec (* default kind and type assumptions *)
 | DEF_reg_dec of terminal * terminal * id (* register declaration *)
 | DEF_scattered_function of terminal * terminal * rec_opt * 'a tannot_opt * 'a effects_opt * id (* scattered function definition header *)
 | DEF_scattered_funcl of terminal * terminal * 'a funcl (* scattered function definition clause *)
 | DEF_scattered_variant of terminal * terminal * id * naming_scheme_opt * terminal * terminal * terminal * 'a typquant (* scattered union definition header *)
 | DEF_scattered_unioncl of terminal * id * terminal * terminal * id (* scattered union definition member *)
 | DEF_scattered_end of terminal * id (* scattered definition end *)


type 
'a def = 
   DEF_aux of 'a def_aux * 'a annot


type 
'a typ_lib_aux =  (* library types and syntactic sugar for them *)
   Typ_lib_unit of terminal (* unit type with value $()$ *)
 | Typ_lib_bool of terminal (* booleans $_$ and $_$ *)
 | Typ_lib_bit of terminal (* pure bit values (not mutable bits) *)
 | Typ_lib_nat of terminal (* natural numbers 0,1,2,... *)
 | Typ_lib_string of terminal * string (* UTF8 strings *)
 | Typ_lib_enum of terminal * terminal * terminal * terminal (* natural numbers _ .. _+_-1, ordered by _ *)
 | Typ_lib_enum1 of terminal * terminal * terminal (* sugar for \texttt{enum nexp 0 inc} *)
 | Typ_lib_enum2 of terminal * terminal * terminal * terminal * terminal (* sugar for \texttt{enum (nexp'-nexp+1) nexp inc} or \texttt{enum (nexp-nexp'+1) nexp' dec} *)
 | Typ_lib_vector of terminal * terminal * terminal * terminal * terminal (* vector of _, indexed by natural range *)
 | Typ_lib_vector2 of atyp * terminal * terminal * terminal (* sugar for vector indexed by [ _ ] *)
 | Typ_lib_vector3 of atyp * terminal * terminal * terminal * terminal * terminal (* sugar for vector indexed by [ _.._ ] *)
 | Typ_lib_list of terminal * atyp (* list of _ *)
 | Typ_lib_set of terminal * atyp (* finite set of _ *)
 | Typ_lib_reg of terminal * atyp (* mutable register components holding _ *)


type 
'a ctor_def_aux =  (* Datatype constructor definition clause *)
   CT_ct of id * terminal * 'a typschm


type 
'a defs =  (* Definition sequence *)
   Defs of ('a def) list


type 
'a typ_lib = 
   Typ_lib_aux of 'a typ_lib_aux * l


type 
'a ctor_def = 
   CT_aux of 'a ctor_def_aux * 'a annot



