(* ========================================================================= *)
(* Tactic logging machinery (for machine learning use)                       *)
(*                                                                           *)
(*                  (c) Copyright, Google Inc. 2017                          *)
(* ========================================================================= *)

set_jrh_lexer;;
open Fusion;;
open Printer;;
open Equal;;
open Drule;;

type goal = (string * thm) list * term;;

type justification = instantiation -> (thm * proof_log) list -> thm * proof_log

and goalstate = (term list * instantiation) * goal list * justification

and tactic = goal -> goalstate

and thm_tactic = thm -> tactic

and tactic_log =
  | Fake_log (* see VALID *)
  | Label_tac_log of string * thm
  | Accept_tac_log of thm
  | Conv_tac_log of conv (* TODO will need to expand since conv:term->thm *)
  | Abs_tac_log
  | Mk_comb_tac_log
  | Disch_tac_log
  | Mp_tac_log of thm
  | Eq_tac_log
  | Undisch_tac_log of term
  | Spec_tac_log of term * term
  | X_gen_tac_log of term
  | X_choose_tac_log of term * thm
  | Exists_tac_log of term
  | Conj_tac_log
  | Disj1_tac_log
  | Disj2_tac_log
  | Disj_cases_tac_log of thm
  | Contr_tac_log of thm
  | Match_accept_tac_log of thm
  | Match_mp_tac_log of thm
  | Conjuncts_then2_log of thm_tactic * thm_tactic * thm
  | Subgoal_then_log of term * thm_tactic
  | Freeze_then_log of thm_tactic * thm
  | X_meta_exists_tac_log of term
  | Meta_spec_tac_log of term * thm
  | Backchain_tac_log of thm
  | Imp_subst_tac_log of thm
  | Unknown_log

and proof_log = Proof_log of goal * tactic_log * proof_log list;;

(* ------------------------------------------------------------------------- *)
(* Parseable S-Expression printer for goals.                                 *)
(* ------------------------------------------------------------------------- *)

let sp_print_goal fmt (gl:goal) =
  let asl,w = gl in
  let rec print_hyp asl =
    match asl with
      [] -> ()
    | (str,th)::[] -> sp_print_thm fmt th
    | (str,th)::tl -> sp_print_thm fmt th;
                      Format.pp_print_string fmt " ";
                      print_hyp tl
  in Format.pp_print_string fmt "(g (";
     print_hyp asl;
     Format.pp_print_string fmt ") ";
     sp_print_term fmt w;
     Format.pp_print_string fmt ")";;

(* ------------------------------------------------------------------------- *)
(* Parseable S-Expression printer for proof logs.                            *)
(* ------------------------------------------------------------------------- *)

let proof_fmt : Format.formatter option =
  try
    let filename = Sys.getenv "PROOF_LOG_OUTPUT" in
    (* TODO figure out where to close this channel. *)
    let proof_log_oc = open_out filename in
    Some Format.formatter_of_out_channel proof_log_oc
  with Not_found -> None;;

(* TODO move to printing *)
let pp_print_tactic_log fmt taclog =
  let tactype =
    match taclog with
      Fake_log -> "(Fake_log)"
    | Label_tac_log (st, th) -> "(Label_tac_log)"
    | Accept_tac_log th -> "(Accept_tac_log)"
    | Conv_tac_log c -> "(Conv_tac_log)"
    | Abs_tac_log -> "(Abs_tac_log)"
    | Mk_comb_tac_log -> "(Mk_comb_tac_log)"
    | Disch_tac_log -> "(Disch_tac_log)"
    | Mp_tac_log th -> "(Mp_tac_log)"
    | Eq_tac_log -> "(Eq_tac_log)"
    | Undisch_tac_log tm -> "(Undisch_tac_log)"
    | Spec_tac_log (tm1, tm2) -> "Spec_tac_log)"
    | X_gen_tac_log tm -> "(X_gen_tac_log)"
    | X_choose_tac_log (tm, th) -> "(X_choose_tac_log)"
    | Exists_tac_log tm -> "(Exists_tac_log)"
    | Conj_tac_log -> "(Conj_tac_log)"
    | Disj1_tac_log -> "(Disj1_tac_log)"
    | Disj2_tac_log -> "(Disj2_tac_log)"
    | Disj_cases_tac_log th -> "(Disj_cases_tac_log)"
    | Contr_tac_log th -> "(Contr_tac_log)"
    | Match_accept_tac_log th -> "(Match_accept_tac_log)"
    | Match_mp_tac_log th -> "(Match_mp_tac_log)"
    | Conjuncts_then2_log (thm_tac1, thm_tac2, th) -> "(Conjuncts_then2_log)"
    | Subgoal_then_log (tm, thm_tac) -> "(Subgoal_then_log)"
    | Freeze_then_log (thm_tac, th) -> "(Freeze_then_log)"
    | X_meta_exists_tac_log tm -> "(X_meta_exists_tac_log)"
    | Meta_spec_tac_log (tm, th) -> "(Meta_spec_tac_log)"
    | Backchain_tac_log th -> "(Backchain_tac_log)"
    | Imp_subst_tac_log th -> "(Imp_subst_tac_log)"
    | Unknown_log -> "(Unknown)" in
  Format.pp_print_string fmt tactype;;

let rec sp_print_proof_log fmt plog =
  let Proof_log ((gl:goal), (taclog:tactic_log), (logl:proof_log list)) = plog in
  Format.pp_print_string fmt "(p ";
  sp_print_goal fmt gl;
  Format.pp_print_string fmt " ";
  pp_print_tactic_log fmt taclog;
  Format.pp_print_string fmt " (";
  if logl = [] then () else
     sp_print_proof_log_list fmt logl;
  Format.pp_print_string fmt "))";
and sp_print_proof_log_list fmt logl =
  match logl with
    [] -> ()
  | hd::[] -> sp_print_proof_log fmt hd;
  | hd::tl -> sp_print_proof_log fmt hd;
              Format.pp_print_string fmt " ";
              sp_print_proof_log_list fmt tl;;
