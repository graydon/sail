Require Import Sail2_values.

Definition string_sub (s : string) (start : Z) (len : Z) : string :=
  String.substring (Z.to_nat start) (Z.to_nat len) s.

Definition string_startswith s expected :=
  let prefix := String.substring 0 (String.length expected) s in
  generic_eq prefix expected.

Definition string_drop s (n : {n : Z & ArithFact (n >= 0)}) :=
  let n := Z.to_nat (projT1 n) in
  String.substring n (String.length s - n) s.

Definition string_length s : {n : Z & ArithFact (n >= 0)} :=
 build_ex (Z.of_nat (String.length s)).

Definition string_append := String.append.

Local Open Scope char_scope.
Local Definition hex_char (c : Ascii.ascii) : option Z :=
match c with
| "0" => Some 0
| "1" => Some 1
| "2" => Some 2
| "3" => Some 3
| "4" => Some 4
| "5" => Some 5
| "6" => Some 6
| "7" => Some 7
| "8" => Some 8
| "9" => Some 9
| "a" => Some 10
| "b" => Some 11
| "c" => Some 12
| "d" => Some 13
| "e" => Some 14
| "f" => Some 15
| _ => None
end.
Local Close Scope char_scope.
Local Fixpoint more_digits (s : string) (base : Z) (acc : Z) (len : nat) : Z * nat :=
match s with
| EmptyString => (acc, len)
| String "_" t => more_digits t base acc (S len)
| String h t =>
  match hex_char h with
  | None => (acc, len)
  | Some i => 
    if i <? base
    then more_digits t base (base * acc + i) (S len)
    else (acc, len)
  end
end.
Local Definition int_of (s : string) (base : Z) (len : nat) : option (Z * {n : Z & ArithFact (n >= 0)}) :=
match s with
| EmptyString => None
| String h t =>
  match hex_char h with
  | None => None
  | Some i =>
    if i <? base
    then
    let (i, len') := more_digits t base i (S len) in
    Some (i, build_ex (Z.of_nat len'))
    else None
  end
end.

(* I've stuck closely to OCaml's int_of_string, because that's what's currently
   used elsewhere. *)

Definition maybe_int_of_prefix (s : string) : option (Z * {n : Z & ArithFact (n >= 0)}) :=
match s with
| EmptyString => None
| String "0" (String ("x"|"X") t) => int_of t 16 2
| String "0" (String ("o"|"O") t) => int_of t 8 2
| String "0" (String ("b"|"B") t) => int_of t 2 2
| String "0" (String "u" t) => int_of t 10 2
| String "-" t =>
  match int_of t 10 1 with
  | None => None
  | Some (i,len) => Some (-i,len)
  end
| _ => int_of s 10 0
end.

Definition maybe_int_of_string (s : string) : option Z :=
match maybe_int_of_prefix s with
| None => None
| Some (i,len) =>
  if projT1 len =? projT1 (string_length s)
  then Some i
  else None
end.

Fixpoint n_leading_spaces (s:string) : nat :=
  match s with
  | EmptyString => 0
  | String " " t => S (n_leading_spaces t)
  | _ => 0
  end.

Definition opt_spc_matches_prefix s : option (unit * {n : Z & ArithFact (n >= 0)}) :=
  Some (tt, build_ex (Z.of_nat (n_leading_spaces s))).

Definition spc_matches_prefix s : option (unit * {n : Z & ArithFact (n >= 0)}) :=
  match n_leading_spaces s with
  | O => None
  | S n => Some (tt, build_ex (Z.of_nat (S n)))
  end.

Definition hex_bits_n_matches_prefix sz `{ArithFact (sz >= 0)} s : option (mword sz * {n : Z & ArithFact (n >= 0)}) :=
  match maybe_int_of_prefix s with
  | None => None
  | Some (n, len) =>
    if andb (0 <=? n) (n <? pow 2 sz)
    then Some (of_int sz n, len)
    else None
  end.

Definition hex_bits_3_matches_prefix s := hex_bits_n_matches_prefix 3 s.
Definition hex_bits_4_matches_prefix s := hex_bits_n_matches_prefix 4 s.
Definition hex_bits_5_matches_prefix s := hex_bits_n_matches_prefix 5 s.
Definition hex_bits_6_matches_prefix s := hex_bits_n_matches_prefix 6 s.
Definition hex_bits_7_matches_prefix s := hex_bits_n_matches_prefix 7 s.
Definition hex_bits_8_matches_prefix s := hex_bits_n_matches_prefix 8 s.
Definition hex_bits_9_matches_prefix s := hex_bits_n_matches_prefix 9 s.
Definition hex_bits_10_matches_prefix s := hex_bits_n_matches_prefix 10 s.
Definition hex_bits_11_matches_prefix s := hex_bits_n_matches_prefix 11 s.
Definition hex_bits_12_matches_prefix s := hex_bits_n_matches_prefix 12 s.
Definition hex_bits_13_matches_prefix s := hex_bits_n_matches_prefix 13 s.
Definition hex_bits_14_matches_prefix s := hex_bits_n_matches_prefix 14 s.
Definition hex_bits_15_matches_prefix s := hex_bits_n_matches_prefix 15 s.
Definition hex_bits_16_matches_prefix s := hex_bits_n_matches_prefix 16 s.
Definition hex_bits_20_matches_prefix s := hex_bits_n_matches_prefix 20 s.
Definition hex_bits_21_matches_prefix s := hex_bits_n_matches_prefix 21 s.
Definition hex_bits_28_matches_prefix s := hex_bits_n_matches_prefix 28 s.
Definition hex_bits_32_matches_prefix s := hex_bits_n_matches_prefix 32 s.
Definition hex_bits_33_matches_prefix s := hex_bits_n_matches_prefix 33 s.

Local Definition zero : N := Ascii.N_of_ascii "0".
Local Fixpoint string_of_N (limit : nat) (n : N) (acc : string) : string :=
match limit with
| O => acc
| S limit' =>
  let (d,m) := N.div_eucl n 10 in
  let acc := String (Ascii.ascii_of_N (m + zero)) acc in
  if N.ltb 0 d then string_of_N limit' d acc else acc
end.
Local Fixpoint pos_limit p :=
match p with
| xH => S O
| xI p | xO p => S (pos_limit p)
end.
Definition string_of_int (z : Z) : string :=
match z with
| Z0 => "0"
| Zpos p => string_of_N (pos_limit p) (Npos p) ""
| Zneg p => String "-" (string_of_N (pos_limit p) (Npos p) "")
end.


