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


(* TODO(smloos) implement this function.
   Will need to build data structure throughout _CONV tactics. *)
let sp_print_conv fmt conv =
  pp_print_string fmt "Conv_printing_not_implemented";;

(* TODO(smloos) implement this function. *)
let sp_print_thm_tactic fmt th_tac =
  pp_print_string fmt "thm_tactic_printing_not_implemented";;

let pp_print_tactic_log fmt taclog =
  match taclog with
    Fake_log -> pp_print_string fmt "(Fake_log)"
  | Label_tac_log (st, th) ->
     pp_print_string fmt "(Label_tac_log ";
     if ((String.length st) = 0) then () else
       pp_print_string fmt (st^" ");
     sp_print_thm fmt th;
     pp_print_string fmt ")"
  | Accept_tac_log th ->
     pp_print_string fmt "(Accept_tac_log ";
     sp_print_thm fmt th;
     pp_print_string fmt ")"
  | Conv_tac_log c ->
     pp_print_string fmt "(Conv_tac_log ";
     sp_print_conv fmt c;
     pp_print_string fmt ")"
  | Abs_tac_log -> pp_print_string fmt "(Abs_tac_log)"
  | Mk_comb_tac_log -> pp_print_string fmt "(Mk_comb_tac_log)"
  | Disch_tac_log -> pp_print_string fmt "(Disch_tac_log)"
  | Mp_tac_log th ->
     pp_print_string fmt "(Mp_tac_log ";
     sp_print_thm fmt th;
     pp_print_string fmt ")"
  | Eq_tac_log -> pp_print_string fmt "(Eq_tac_log)"
  | Undisch_tac_log tm ->
     pp_print_string fmt "(Undisch_tac_log ";
     sp_print_term fmt tm;
     pp_print_string fmt ")"
  | Spec_tac_log (tm1, tm2) ->
     pp_print_string fmt "(Spec_tac_log ";
     sp_print_term fmt tm1;
     pp_print_string fmt " ";
     sp_print_term fmt tm2;
     pp_print_string fmt ")"
  | X_gen_tac_log tm ->
     pp_print_string fmt "(X_gen_tac_log ";
     sp_print_term fmt tm;
     pp_print_string fmt ")"
  | X_choose_tac_log (tm, th) ->
     pp_print_string fmt "(X_choose_tac_log ";
     sp_print_term fmt tm;
     pp_print_string fmt " ";
     sp_print_thm fmt th;
     pp_print_string fmt ")"
  | Exists_tac_log tm ->
     pp_print_string fmt "(Exists_tac_log ";
     sp_print_term fmt tm;
     pp_print_string fmt ")"
  | Conj_tac_log -> pp_print_string fmt "(Conj_tac_log)"
  | Disj1_tac_log -> pp_print_string fmt "(Disj1_tac_log)"
  | Disj2_tac_log -> pp_print_string fmt "(Disj2_tac_log)"
  | Disj_cases_tac_log th ->
     pp_print_string fmt "(Disj_cases_tac_log ";
     sp_print_thm fmt th;
     pp_print_string fmt ")"
  | Contr_tac_log th ->
     pp_print_string fmt "(Contr_tac_log ";
     sp_print_thm fmt th;
     pp_print_string fmt ")"
  | Match_accept_tac_log th ->
     pp_print_string fmt "(Match_accept_tac_log ";
     sp_print_thm fmt th;
     pp_print_string fmt ")"
  | Match_mp_tac_log th ->
     pp_print_string fmt "(Match_mp_tac_log ";
     sp_print_thm fmt th;
     pp_print_string fmt ")"
  | Conjuncts_then2_log (thm_tac1, thm_tac2, th) ->
     pp_print_string fmt "(Conjuncts_then2_log ";
     sp_print_thm_tactic fmt thm_tac1;
     pp_print_string fmt " ";
     sp_print_thm_tactic fmt thm_tac2;
     pp_print_string fmt " ";
     sp_print_thm fmt th;
     pp_print_string fmt ")"
  | Subgoal_then_log (tm, thm_tac) ->
     pp_print_string fmt "(Subgoal_then_log ";
     sp_print_term fmt tm;
     pp_print_string fmt " ";
     sp_print_thm_tactic fmt thm_tac;
     pp_print_string fmt ")"
  | Freeze_then_log (thm_tac, th) ->
     pp_print_string fmt "(Freeze_then_log ";
     sp_print_thm_tactic fmt thm_tac;
     pp_print_string fmt " ";
     sp_print_thm fmt th;
     pp_print_string fmt ")"
  | X_meta_exists_tac_log tm ->
     pp_print_string fmt "(X_mpeta_exists_tac_log ";
     sp_print_term fmt tm;
     pp_print_string fmt ")"
  | Meta_spec_tac_log (tm, th) ->
     pp_print_string fmt "(Meta_spec_tac_log ";
     sp_print_term fmt tm;
     pp_print_string fmt " ";
     sp_print_thm fmt th;
     pp_print_string fmt ")"
  | Backchain_tac_log th ->
     pp_print_string fmt "(Backchain_tac_log ";
     sp_print_thm fmt th;
     pp_print_string fmt ")"
  | Imp_subst_tac_log th ->
     pp_print_string fmt "(Imp_subst_tac_log ";
     sp_print_thm fmt th;
     pp_print_string fmt ")"
  | Unknown_log -> pp_print_string fmt "(Unknown_log)";;

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
