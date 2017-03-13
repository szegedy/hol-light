(* ========================================================================= *)
(* Tactic logging machinery (for machine learning use)                       *)
(*                                                                           *)
(*                  (c) Copyright, Google Inc. 2017                          *)
(* ========================================================================= *)

set_jrh_lexer;;
open Fusion;;
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
