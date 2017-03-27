(* ========================================================================= *)
(* Tactic logging machinery (for machine learning use)                       *)
(*                                                                           *)
(*                  (c) Copyright, Google Inc. 2017                          *)
(* ========================================================================= *)

set_jrh_lexer;;
open List;;
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

let sexp_goal (gl:goal) =
  let asl,w = gl in
  (* TODO(geoffreyi): Should we ignore the string tag on hypotheses? *)
  Snode [Sleaf "g"; Snode (map (fun (_,th) -> sexp_thm th) asl); sexp_term w]

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
let sexp_conv conv = Sleaf "Conv_printing_not_implemented";;

(* TODO(smloos) implement this function. *)
let sexp_thm_tactic th_tac = Sleaf "thm_tactic_printing_not_implemented";;

let proof_stats = Hashtbl.create 40

let num_total_tactics = ref 0

let increment_proof_stats (name:string) =
  if Hashtbl.mem proof_stats name then
    let value = Hashtbl.find proof_stats name + 1 in
    Hashtbl.replace proof_stats name value
  else
    Hashtbl.add proof_stats name 1;
  incr num_total_tactics

let print_statistics () =
  Printf.printf "***** TACTICS STATISTICS *****\n";
  (* let pairs = Hashtbl.fold (fun k v acc -> (k, v) :: acc) h []; *)
  Hashtbl.iter (fun name count ->
                 Printf.printf "%s: %d\n" name count) proof_stats;
  Printf.printf "TOTAL: %d\n" !num_total_tactics

let tactic_name taclog =
  match taclog with
    Fake_log -> "Fake_log"
  | Label_tac_log (st, th) -> "Label_tac_log"
  | Accept_tac_log th -> "Accept_tac_log"
  | Conv_tac_log c -> "Conv_tac_log"
  | Abs_tac_log -> "Abs_tac_log"
  | Mk_comb_tac_log -> "Mk_comb_tac_log"
  | Disch_tac_log -> "Disch_tac_log"
  | Mp_tac_log th -> "Mp_tac_log"
  | Eq_tac_log -> "Eq_tac_log"
  | Undisch_tac_log tm -> "Undisch_tac_log"
  | Spec_tac_log (tm1, tm2) -> "Spec_tac_log"
  | X_gen_tac_log tm -> "X_gen_tac_log"
  | X_choose_tac_log (tm, th) -> "X_choose_tac_log"
  | Exists_tac_log tm -> "Exists_tac_log"
  | Conj_tac_log -> "Conj_tac_log"
  | Disj1_tac_log -> "Disj1_tac_log"
  | Disj2_tac_log -> "Disj2_tac_log"
  | Disj_cases_tac_log th -> "Disj_cases_tac_log"
  | Contr_tac_log th -> "Contr_tac_log"
  | Match_accept_tac_log th -> "Match_accept_tac_log"
  | Match_mp_tac_log th -> "Match_mp_tac_log"
  | Conjuncts_then2_log (thm_tac1, thm_tac2, th) -> "Conjuncts_then2_log"
  | Subgoal_then_log (tm, thm_tac) -> "Subgoal_then_log"
  | Freeze_then_log (thm_tac, th) -> "Freeze_then_log"
  | X_meta_exists_tac_log tm -> "X_mpeta_exists_tac_log"
  | Meta_spec_tac_log (tm, th) -> "Meta_spec_tac_log"
  | Backchain_tac_log th -> "Backchain_tac_log"
  | Imp_subst_tac_log th -> "Imp_subst_tac_log"
  | Unknown_log -> "Unknown_log"

let sexp_tactic_log taclog =
  let simple s = Snode [Sleaf s] in
  let thm s th = Snode [Sleaf s; sexp_thm th] in
  let term s tm = Snode [Sleaf s; sexp_term tm] in
  match taclog with
    Fake_log -> simple "Fake_log"
  | Label_tac_log (st, th) -> Snode [Sleaf "Label_tac_log"; Sleaf st; sexp_thm th]
  | Accept_tac_log th -> thm "Accept_tac_log" th
  | Conv_tac_log c -> Snode [Sleaf "Conv_tac_log"; sexp_conv c]
  | Abs_tac_log -> simple "Abs_tac_log"
  | Mk_comb_tac_log -> simple "Mk_comb_tac_log"
  | Disch_tac_log -> simple "Disch_tac_log"
  | Mp_tac_log th -> thm "Mp_tac_log" th
  | Eq_tac_log -> simple "Eq_tac_log"
  | Undisch_tac_log tm -> term "Undisch_tac_log" tm
  | Spec_tac_log (tm1, tm2) -> Snode [Sleaf "Spec_tac_log"; sexp_term tm1; sexp_term tm2]
  | X_gen_tac_log tm -> term "X_gen_tac_log" tm
  | X_choose_tac_log (tm, th) -> Snode [Sleaf "X_choose_tac_log"; sexp_term tm; sexp_thm th]
  | Exists_tac_log tm -> term "Exists_tac_log" tm
  | Conj_tac_log -> simple "Conj_tac_log"
  | Disj1_tac_log -> simple "Disj1_tac_log"
  | Disj2_tac_log -> simple "Disj2_tac_log"
  | Disj_cases_tac_log th -> thm "Disj_cases_tac_log" th
  | Contr_tac_log th -> thm "Contr_tac_log" th
  | Match_accept_tac_log th -> thm "Match_accept_tac_log" th
  | Match_mp_tac_log th -> thm "Match_mp_tac_log" th
  | Conjuncts_then2_log (thm_tac1, thm_tac2, th) ->
      Snode [Sleaf "Conjuncts_then2_log"; sexp_thm_tactic thm_tac1; sexp_thm_tactic thm_tac2;
             sexp_thm th]
  | Subgoal_then_log (tm, thm_tac) ->
      Snode [Sleaf "Subgoal_then_log"; sexp_term tm; sexp_thm_tactic thm_tac]
  | Freeze_then_log (thm_tac, th) ->
      Snode [Sleaf "Freeze_then_log"; sexp_thm_tactic thm_tac; sexp_thm th]
  | X_meta_exists_tac_log tm -> term "X_mpeta_exists_tac_log" tm
  | Meta_spec_tac_log (tm, th) -> Snode [Sleaf "Meta_spec_tac_log"; sexp_term tm; sexp_thm th]
  | Backchain_tac_log th -> thm "Backchain_tac_log" th
  | Imp_subst_tac_log th -> thm "Imp_subst_tac_log" th
  | Unknown_log -> simple "Unknown_log";;

let rec sexp_proof_log plog =
  let Proof_log ((gl:goal), (taclog:tactic_log), (logl:proof_log list)) = plog in
  Snode [Sleaf "p"; sexp_goal gl; sexp_tactic_log taclog; Snode (map sexp_proof_log logl)]

let rec add_proof_stats plog =
  let Proof_log ((gl:goal), (taclog:tactic_log), (logl:proof_log list)) = plog in
  increment_proof_stats (tactic_name taclog);
  List.iter add_proof_stats logl
