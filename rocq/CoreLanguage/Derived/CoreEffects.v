From Stdlib Require Import List ZArith.
From UnifiedInterpreter.Base Require Import Free Result.
From UnifiedInterpreter.CoreLanguage.Axiomatic Require Import TraceSemantics.
From UnifiedInterpreter.CoreLanguage.Derived Require Import Refocusing Automaton.
Import ListNotations.
Set Implicit Arguments.

(* ========================================================================== *)
(* 1. 基于 Base/Free.v 的 CoreLanguage 语义效应签名与单分支 CPS 指称             *)
(* ========================================================================== *)

Section CoreEffects.
Context {Float EventId Pipe Unit : Type}.
Local Notation Val := (@value Float EventId Pipe).
Local Notation Op := (@operand Float EventId Pipe).
Local Notation Env := (@environment Float EventId Pipe).
Local Notation RawCmd := (@command Float EventId Pipe Unit unit).
Local Notation Cursor := (@thread_cursor Float EventId Pipe Unit).

(* 语义效应 GADT：只描述单分支对运行时环境发出的语义请求，不直接暴露全局状态。 *)
Inductive core_effect : Type -> Type :=
| EAlloc        (o : op_id) : core_effect memory_resource
| EAtomic       (o : op_id) (rho : Env) (f : atomic_op) (vs : list Op) : core_effect Val
| EAssignPipe   (o : op_id) (rho : Env) (x : var) (v : Op) : core_effect Pipe
| EIssueRead    (o : op_id) (rho : Env) (d : execution Unit Op) (v : Op) : core_effect unit
| EIssueWrite   (o : op_id) (rho : Env) (d : execution Unit Op) (v1 v2 : Op) : core_effect unit
| EIssueCompute (o : op_id) (rho : Env) (d : execution Unit Op) (vs : list Op) : core_effect unit
| EIssueSetFlag (o : op_id) (rho : Env) (src dst v : Op) : core_effect unit
| EAwaitFlag    (o : op_id) (rho : Env) (src dst v : Op) : core_effect unit
| EBranch       (o : op_id) (rho : Env) (cond : Op) : core_effect bool
| EReturn       (o : op_id) (rho : Env) (vs : list Op) : core_effect (list Val).

Definition branch_comp := computation core_effect (result step_error (list Val)).

(* 单分支 CPS / Free-Monad 指称：每次执行一个已聚焦的头命令并发出一条语义效应，
   后续控制流作为高阶续体保存在 Trigger 中。 *)
Fixpoint denote_branch (fuel refocus_budget branch_idx : nat) (cur : Cursor) : branch_comp :=
  match fuel with
  | 0 => Free.Return (Error ErrOutOfFuel)
  | S fuel' =>
      match refocus refocus_budget cur with
      | None => Free.Return (Error (ErrRefocusStuck branch_idx))
      | Some cur' =>
          let tid := cursor_tid cur' in
          let path := cursor_path cur' in
          let rho := cursor_env cur' in
          let stk := cursor_stack cur' in
          let o := (tid, path) in
          match cursor_cmd cur' with
          | Alloc tt x n =>
              Trigger (EAlloc o) (fun addr =>
                denote_branch fuel' refocus_budget branch_idx
                  (ThreadCursor tid (xO path) (bind rho x (Known (VMemory addr))) n stk))
          | LetAtomic tt x f vs n =>
              Trigger (EAtomic o rho f vs) (fun res =>
                denote_branch fuel' refocus_budget branch_idx
                  (ThreadCursor tid (xO path) (bind rho x (Known res)) n stk))
          | AssignPipe tt x v n =>
              Trigger (EAssignPipe o rho x v) (fun p =>
                denote_branch fuel' refocus_budget branch_idx
                  (ThreadCursor tid (xO path) (bind rho x (Known (VPipe p))) n stk))
          | Read tt x d v n =>
              Trigger (EIssueRead o rho d v) (fun _ =>
                denote_branch fuel' refocus_budget branch_idx
                  (ThreadCursor tid (xO path) (bind rho x (Async o)) n stk))
          | Write tt d v1 v2 n =>
              Trigger (EIssueWrite o rho d v1 v2) (fun _ =>
                denote_branch fuel' refocus_budget branch_idx
                  (ThreadCursor tid (xO path) rho n stk))
          | CCompute tt x d vs n =>
              Trigger (EIssueCompute o rho d vs) (fun _ =>
                denote_branch fuel' refocus_budget branch_idx
                  (ThreadCursor tid (xO path) (bind rho x (Async o)) n stk))
          | SetFlag tt src dst v n =>
              Trigger (EIssueSetFlag o rho src dst v) (fun _ =>
                denote_branch fuel' refocus_budget branch_idx
                  (ThreadCursor tid (xO path) rho n stk))
          | WaitFlag tt src dst v n =>
              Trigger (EAwaitFlag o rho src dst v) (fun _ =>
                denote_branch fuel' refocus_budget branch_idx
                  (ThreadCursor tid (xO path) rho n stk))
          | If tt cond y n =>
              Trigger (EBranch o rho cond) (fun (b : bool) =>
                denote_branch fuel' refocus_budget branch_idx
                  (ThreadCursor tid (if b then xO path else xI path)
                                rho (if b then y else n) stk))
          | Return tt vs =>
              Trigger (EReturn o rho vs) (fun args => Free.Return (Ok args))
          | CAlias _ _ _ | Select _ _ _ _ _ | For _ _ _ _ _ | LoopEnd =>
              Free.Return (Error (ErrRefocusStuck branch_idx))
          end
      end
  end.

(* 已处于聚焦态的游标满足 refocus budget cur = Some cur（只需 budget >= 1）。 *)
Lemma refocus_idempotent budget (cur : Cursor) :
  (1 <= budget)%nat ->
  is_event_head (cursor_cmd cur) = true ->
  refocus budget cur = Some cur.
Proof.
  intros Hge Hhead. destruct budget as [|budget']; [inversion Hge |].
  destruct cur as [tid path rho cmd stk]. cbn in *.
  destruct cmd; try discriminate; reflexivity.
Qed.

End CoreEffects.
