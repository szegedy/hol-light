(* ========================================================================= *)
(* Replay a tactic log as a proof                                            *)
(*                                                                           *)
(*                  (c) Copyright, Google Inc. 2017                          *)
(* ========================================================================= *)

set_jrh_lexer;;
open Lib;;
open List;;
open Fusion;;
open Basics;;
open Log;;
open Tactics;;
open Printer;;
open Itab;;

(* ------------------------------------------------------------------------- *)
(* Replay a proof log, turning it back into a tactic                         *)
(* ------------------------------------------------------------------------- *)

(* Tactics filled in by future files *)
let backchain_tac : thm_tactic option ref = ref None
let imp_subst_tac : thm_tactic option ref = ref None
let asm_meson_tac : (thm list -> tactic) option ref = ref None
let asm_metis_tac : (thm list -> tactic) option ref = ref None
let pure_rewrite_tac : (thm list -> tactic) option ref = ref None
let rewrite_tac : (thm list -> tactic) option ref = ref None
let pure_once_rewrite_tac : (thm list -> tactic) option ref = ref None
let once_rewrite_tac : (thm list -> tactic) option ref = ref None

let get name x = match !x with
    None -> failwith ("Downstream tactic "^name^" not filled in")
  | Some t -> t

type env = ((int * int) * thm) list

let replay_tactic_log (env : env) log : tactic =
  let rec lookup src = match src with
    | Unknown_src -> failwith ("Can't replay Unknown_src in " ^ tactic_name log)
    | Premise_src th -> th
    | Hypot_src (n,k) -> assoc (n,k) env
    | Conj_left_src s -> ASSUME (fst (dest_conj (concl (lookup s))))
    | Conj_right_src s -> ASSUME (snd (dest_conj (concl (lookup s))))
    | Assume_src tm -> ASSUME tm in
  let replay_ttac ttac src = ttac (lookup src) in
  let rewrite ty = match ty with
      Pure_rewrite_type -> get "PURE_REWRITE_TAC" pure_rewrite_tac
    | Rewrite_type -> get "REWRITE_TAC" rewrite_tac
    | Pure_once_rewrite_type -> get "PURE_ONCE_REWRITE_TAC" pure_once_rewrite_tac
    | Once_rewrite_type -> get "ONCE_REWRITE_TAC" once_rewrite_tac in
  match log with
    | Fake_log -> failwith "Can't replay Fake_log"
    | Freeze_then_log th -> failwith "TODO: Can't replay Freeze_then_log"
    | Cheat_tac_log -> failwith "Can't replay Cheat_tac_log"
    (* Non-thm parameterized tactics *)
    | Abs_tac_log -> ABS_TAC
    | Mk_comb_tac_log -> MK_COMB_TAC
    | Disch_tac_log -> DISCH_TAC
    | Eq_tac_log -> EQ_TAC
    | Conj_tac_log -> CONJ_TAC
    | Disj1_tac_log -> DISJ1_TAC
    | Disj2_tac_log -> DISJ2_TAC
    | Refl_tac_log -> REFL_TAC
    | Itaut_tac_log -> ITAUT_TAC
    | Ants_tac_log -> ANTS_TAC
    | Raw_pop_tac_log n -> RAW_POP_TAC n
    | Undisch_tac_log tm -> UNDISCH_TAC tm
    | Spec_tac_log (tm1, tm2) -> SPEC_TAC (tm1, tm2)
    | X_gen_tac_log tm -> X_GEN_TAC tm
    | Exists_tac_log tm -> EXISTS_TAC tm
    | X_meta_exists_tac_log tm -> X_META_EXISTS_TAC tm
    (* thm_tactic *)
    | Label_tac_log (s, th) -> replay_ttac (LABEL_TAC s) th
    | Accept_tac_log th -> replay_ttac ACCEPT_TAC th
    | Mp_tac_log th -> replay_ttac MP_TAC th
    | X_choose_tac_log (tm, th) -> replay_ttac (X_CHOOSE_TAC tm) th
    | Disj_cases_tac_log th -> replay_ttac DISJ_CASES_TAC th
    | Contr_tac_log th -> replay_ttac CONTR_TAC th
    | Match_accept_tac_log th -> replay_ttac MATCH_ACCEPT_TAC th
    | Match_mp_tac_log th -> replay_ttac MATCH_MP_TAC th
    (* other *)
    | Conv_tac_log conv -> failwith "TODO: Can't replay Conv_tac_log"
    | Conjuncts_then2_log (tac1, tac2, th) -> failwith "TODO: Can't replay Conjuncts_then2_log"
    | Raw_subgoal_tac_log tm -> RAW_SUBGOAL_TAC tm
    | Backchain_tac_log th -> replay_ttac (get "BACKCHAIN_TAC" backchain_tac) th
    | Imp_subst_tac_log th -> replay_ttac (get "IMP_SUBST_TAC" imp_subst_tac) th
    | Unify_accept_tac_log (tml,th) -> replay_ttac (UNIFY_ACCEPT_TAC tml) th
    | Trans_tac_log (th,tm) -> replay_ttac (fun th -> TRANS_TAC th tm) th
    | Asm_meson_tac_log thl -> (get "ASM_MESON_TAC" asm_meson_tac) (map lookup thl)
    | Asm_metis_tac_log thl -> (get "ASM_METIS_TAC" asm_metis_tac) (map lookup thl)
    | Rewrite_tac_log (ty,thl) -> rewrite ty (map lookup thl)

(* Check that logged goals match goals generated during replay.  This ensures
   failful replay especially when we add or remove hypotheses. *)
let assert_goals_match: goal -> goal -> unit =
  let term t t' =
    let rec eq t t' = match (t,t') with
        (Var (s,ty), Var (s',ty')) -> s = s' && ty = ty'
      | (Const (s,ty), Const (s',ty')) -> s = s' && ty = ty'
      | (Comb (f,x), Comb (f',x')) -> eq f f' && eq x x'
      | (Abs (x,e), Abs (x',e')) -> eq x x' && eq e e'
      | _ -> false in
    let show t = print_to_string sexp_print (sexp_term t) in
    if not (eq t t') then failwith ("assert_goals_match: " ^ show t ^ " != " ^ show t') in
  let thm th th' =
    term (concl th) (concl th');
    List.iter (uncurry term) (zip (hyp th) (hyp th')) in
  let hyp ((s,t),(s',t')) =
    thm t t';
    if s != s' then failwith ("assert_goals_match: " ^ s ^ " != " ^ s') in
  fun (asl,w) (asl',w') ->
    if length asl != length asl' then
      let show asl = string_of_int (length asl) in
      failwith ("assert_goals_match: different numbers of hypotheses: " ^
        show asl ^ " != " ^ show asl')
    else (term w w'; List.iter hyp (zip asl asl'));;

let replay_proof_log : src proof_log -> tactic =
  let rec proof n (env : env) (Proof_log ((asl,_ as g), tac, logs)) g' =
    (try assert_goals_match g g'
     with Failure s -> failwith (s ^ ", tactic " ^ tactic_name tac));
    let rec hyps k env asl = match asl with
        [] -> env
      | (_,a)::asl -> hyps (succ k) (((n,k),a)::env) asl in
    let env = hyps 0 env asl in
    (replay_tactic_log env tac THENL (map (proof (succ n) env) logs)) g'
  in proof 0 []

(* ------------------------------------------------------------------------- *)
(* Finalize a proof_log, freezing out the srcs of thms                       *)
(* ------------------------------------------------------------------------- *)

(* The initialize proof logging produces `thm proof_log` objects with magic
 * thm objects interspersed.  A few of these are premises, but most are
 * hypotheses, pieces of hypotheses, theorems proved via manual forward proof
 * from hypotheses, etc.
 *
 * The finalization pass fills in the sources of these thms where possible,
 * failing back to Unknown_src if not.  For now, the machinery is only capable
 * of noticing hypotheses and pieces of hypotheses.  Filling in everything else
 * is hard, but a possible (and unimplemented) alternative is checking whether
 * METIS_TAC is capable of filling them in. *)

let finalize_proof_log : int -> thm proof_log -> src proof_log = fun before_thms log ->
  (* env : (thm * src) list *)
  let tactic env log =
    let thm th =
      try assoc th env with Not_found ->
      if thm_id th < before_thms then Premise_src th else
      match dest_thm th with
          [h],c when h == c -> Assume_src c
        | _ -> if false then (
                 Printf.printf "Unknown src for tactic %s:\n" (tactic_name log);
                 if false then (
                   Printf.printf "  thm: %s\n" (string_of_thm th);
                   List.iter (fun (th,s) -> Printf.printf "  %s: %s\n"
                                            (print_to_string sexp_print (sexp_src s))
                                            (string_of_thm th)) env));
               Unknown_src
    in match log with
      | Fake_log -> failwith "Can't finalize Fake_log"
      | Conv_tac_log conv -> Conv_tac_log conv
      | Abs_tac_log -> Abs_tac_log
      | Mk_comb_tac_log -> Mk_comb_tac_log
      | Disch_tac_log -> Disch_tac_log
      | Label_tac_log (s,th) -> Label_tac_log (s,thm th)
      | Accept_tac_log th -> Accept_tac_log (thm th)
      | Mp_tac_log th -> Mp_tac_log (thm th)
      | Eq_tac_log -> Eq_tac_log
      | Undisch_tac_log tm -> Undisch_tac_log tm
      | Spec_tac_log (tm1,tm2) -> Spec_tac_log (tm1,tm2)
      | X_gen_tac_log tm -> X_gen_tac_log tm
      | X_choose_tac_log (tm,th) -> X_choose_tac_log (tm,thm th)
      | Exists_tac_log tm -> Exists_tac_log tm
      | Conj_tac_log -> Conj_tac_log
      | Disj1_tac_log -> Disj1_tac_log
      | Disj2_tac_log -> Disj2_tac_log
      | Disj_cases_tac_log th -> Disj_cases_tac_log (thm th)
      | Contr_tac_log th -> Contr_tac_log (thm th)
      | Match_accept_tac_log th -> Match_accept_tac_log (thm th)
      | Match_mp_tac_log th -> Match_mp_tac_log (thm th)
      | Conjuncts_then2_log (tac1,tac2,th) -> Conjuncts_then2_log (tac1,tac2,thm th)
      | Raw_subgoal_tac_log tm -> Raw_subgoal_tac_log tm
      | Freeze_then_log th -> Freeze_then_log (thm th)
      | X_meta_exists_tac_log tm -> X_meta_exists_tac_log tm
      | Backchain_tac_log th -> Backchain_tac_log (thm th)
      | Imp_subst_tac_log th -> Imp_subst_tac_log (thm th)
      | Unify_accept_tac_log (tml,th) -> Unify_accept_tac_log (tml,thm th)
      | Refl_tac_log -> Refl_tac_log
      | Trans_tac_log (th,tm) -> Trans_tac_log (thm th,tm)
      | Itaut_tac_log -> Itaut_tac_log
      | Cheat_tac_log -> Cheat_tac_log
      | Ants_tac_log -> Ants_tac_log
      | Raw_pop_tac_log n -> Raw_pop_tac_log n
      | Asm_meson_tac_log thl -> Asm_meson_tac_log (map thm thl)
      | Asm_metis_tac_log thl -> Asm_metis_tac_log (map thm thl)
      | Rewrite_tac_log (ty,thl) -> Rewrite_tac_log (ty, map thm thl) in
  let rec proof n env (Proof_log (asl,_ as g, tac, logs)) =
    let rec hyp env s th =
      let env = (th,s)::env in
      try let l,r = dest_conj (concl th) in
          hyp (hyp env (Conj_left_src s) (ASSUME l))
                       (Conj_right_src s) (ASSUME r)
      with Failure _ -> env in
    let rec hyps k env asl = match asl with
        [] -> env
      | (_,th)::asl -> hyps (succ k) (hyp env (Hypot_src (n,k)) th) asl in
    let env = hyps 0 env asl in
    Proof_log (g, tactic env tac, map (proof (succ n) env) logs)
  in
    if false then (
      sexp_print std_formatter (sexp_proof_log sexp_thm log);
      Printf.printf "\n");
    proof 0 [] log

(* ------------------------------------------------------------------------- *)
(* Make the above machinery available in log.ml for tactic.ml use            *)
(* ------------------------------------------------------------------------- *)

let () =
  Log.replay_proof_log_ref := Some replay_proof_log;
  Log.finalize_proof_log_ref := Some finalize_proof_log
