(* ========================================================================= *)
(* Replay a tactic log as a proof                                            *)
(*                                                                           *)
(*                  (c) Copyright, Google Inc. 2017                          *)
(* ========================================================================= *)

set_jrh_lexer;;
open List;;
open Fusion;;
open Log;;
open Tactics;;

(* Tactics filled in by future files *)
let backchain_tac : thm_tactic option ref = ref None
let imp_subst_tac : thm_tactic option ref = ref None

let get name x = match !x with
    None -> failwith ("Downstream tactic "^name^" not filled in")
  | Some t -> t

let replay_tactic_log log : tactic = match log with
  | Fake_log -> failwith "Can't replay Fake_log"
  | Label_tac_log (s, th) -> LABEL_TAC s th
  | Accept_tac_log th -> ACCEPT_TAC th
  | Conv_tac_log conv -> CONV_TAC conv
  | Abs_tac_log -> ABS_TAC
  | Mk_comb_tac_log -> MK_COMB_TAC
  | Disch_tac_log -> DISCH_TAC
  | Mp_tac_log th -> MP_TAC th
  | Eq_tac_log -> EQ_TAC
  | Undisch_tac_log tm -> UNDISCH_TAC tm
  | Spec_tac_log (tm1, tm2) -> SPEC_TAC (tm1, tm2)
  | X_gen_tac_log tm -> X_GEN_TAC tm
  | X_choose_tac_log (tm, th) -> X_CHOOSE_TAC tm th
  | Exists_tac_log tm -> EXISTS_TAC tm
  | Conj_tac_log -> CONJ_TAC
  | Disj1_tac_log -> DISJ1_TAC
  | Disj2_tac_log -> DISJ2_TAC
  | Disj_cases_tac_log th -> DISJ_CASES_TAC th
  | Contr_tac_log th -> CONTR_TAC th
  | Match_accept_tac_log th -> MATCH_ACCEPT_TAC th
  | Match_mp_tac_log th -> MATCH_MP_TAC th
  | Conjuncts_then2_log (tac1, tac2, th) -> CONJUNCTS_THEN2 tac1 tac2 th
  | Subgoal_then_log (tm, tac) -> SUBGOAL_THEN tm tac
  | Freeze_then_log (tac, th) -> FREEZE_THEN tac th
  | X_meta_exists_tac_log tm -> X_META_EXISTS_TAC tm
  | Meta_spec_tac_log (tm, th) -> META_SPEC_TAC tm th
  | Backchain_tac_log th -> (get "BACKCHAIN_TAC" backchain_tac) th
  | Imp_subst_tac_log th -> (get "IMP_SUBST_TAC" imp_subst_tac) th
  | Unify_accept_tac_log (tml,th) -> Itab.UNIFY_ACCEPT_TAC tml th

let rec replay_proof_log (Proof_log (_, tac, logs)) : tactic =
  let delay log = fun g -> replay_proof_log log g in
  replay_tactic_log tac THENL (map delay logs);;

Log.replay_proof_log_ref := Some replay_proof_log
