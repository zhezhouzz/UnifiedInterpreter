From Stdlib Require Import List ZArith Bool Lia.
From UnifiedInterpreter.Base Require Import Free Result.
From UnifiedInterpreter.CoreLanguage.Axiomatic Require Import TraceSemantics Issue316 ResourceExamples.
From UnifiedInterpreter.CoreLanguage.Derived Require Import Refocusing Automaton CoreEffects Handlers Soundness.
Import ListNotations.
Set Implicit Arguments.
Local Strategy 1000 [run_derived_interpreter run_free_interpreter].

(* ========================================================================== *)
(* 1. Issue #316 双缓冲端到端验证（对任意 F16 / exp_f16 / 三个输入 Tile 成立）  *)
(* ========================================================================== *)

Module Issue316Validation.

Definition issue_pipe_eqb (p q : issue_pipe) : bool :=
  match p, q with
  | MTE2, MTE2 | Vector, Vector => true
  | _, _ => false
  end.

Lemma issue_pipe_eqb_spec p q : issue_pipe_eqb p q = true <-> p = q.
Proof. destruct p, q; cbn; split; intro H; try reflexivity; discriminate. Qed.

Definition issue_pipe_eq_ops : eq_dec_ops issue_pipe :=
  EqDecOps issue_pipe_eqb issue_pipe_eqb_spec.

Definition in_nat_list_bool (xs : list nat) (a : nat) : bool :=
  existsb (Nat.eqb a) xs.

Lemma in_nat_list_bool_sound xs a :
  in_nat_list_bool xs a = true -> In a xs.
Proof.
  unfold in_nat_list_bool. rewrite existsb_exists.
  intros [x [Hin Heq]]. apply Nat.eqb_eq in Heq; subst; exact Hin.
Qed.

Definition is_buffer_bool (layout : allocation_layout) (a : memory_resource) : bool :=
  Nat.eqb a (buffer_a layout) || Nat.eqb a (buffer_b layout).

Lemma is_buffer_bool_sound layout a :
  is_buffer_bool layout a = true -> is_buffer layout a.
Proof.
  unfold is_buffer_bool, is_buffer. rewrite orb_true_iff, !Nat.eqb_eq. auto.
Qed.

Definition issue316_exec_target {F16 : Type} (layout : allocation_layout) (count : nat)
    : @executable_target (@Tile F16) nat issue_pipe issue_resource.
Proof.
  refine {|
    exec_cfg := target layout count;
    pipe_eq := issue_pipe_eq_ops;
    event_eq := nat_eq_ops;
    check_declared_pipe := fun _ => true;
    check_declared_resource := fun _ => true;
    check_can_read := fun r a =>
      match r with
      | TransferEngine => in_nat_list_bool (input_addresses count) a
      | VectorUnit => is_buffer_bool layout a
      end;
    check_can_write := fun r a =>
      match r with
      | TransferEngine => is_buffer_bool layout a
      | VectorUnit => Nat.eqb a output
      end
  |}.
  - intros p _; exact I.
  - intros r _; exact I.
  - intros r a H. destruct r; cbn in *.
    + apply in_nat_list_bool_sound; exact H.
    + apply is_buffer_bool_sound; exact H.
  - intros r a H. destruct r; cbn in *.
    + apply is_buffer_bool_sound; exact H.
    + apply Nat.eqb_eq; exact H.
Defined.

Lemma odd_buffers_disjoint count : buffers_disjoint odd_allocation_layout count.
Proof.
  intros a [Ha | Ha] [H0 | Hin]; subst a;
    unfold buffer_a, buffer_b, odd_allocation_layout, address_at, odd_address, output in *;
    try lia;
    unfold input_addresses in Hin; apply in_map_iff in Hin as [k [Hk _]]; lia.
Qed.

Definition issue316_exec_model {F16 : Type} (exp_f16 : F16 -> F16)
    (model : @computation_model (@Tile F16) nat issue_pipe issue_resource)
    (Hexp : implements_vexp exp_f16 model)
    : executable_model model.
Proof.
  refine {|
    exec_comp := fun r args =>
      match r, args with
      | VectorUnit, [VFloat xs] => Some (VFloat (map_tile exp_f16 xs))
      | _, _ => None
      end
  |}.
  intros r args res H.
  destruct r; [discriminate |].
  destruct args as [|a rest]; [discriminate |].
  destruct a as [?|f|?|?|?|?]; try discriminate.
  destruct rest; [| discriminate].
  inversion H; subst. apply (proj2 (Hexp f _)). reflexivity.
Defined.

(* 提取 Vector 写回 output 的所有结果值 *)
Definition vector_output_writes {F16 : Type}
    (evs : list (@event_record (@Tile F16) nat issue_pipe issue_resource))
    : list (@value (@Tile F16) nat issue_pipe) :=
  flat_map (fun r =>
    match payload r with
    | LWriteStart (Dispatch VectorUnit (Some Vector)) a v =>
        if Nat.eqb a output then [v] else []
    | _ => []
    end) evs.

(* 统计整条轨迹中曾达到的最大同时在途操作数（用于验证真正的异步流水线重叠） *)
Fixpoint max_inflight_aux {F16 : Type} (cur best : nat)
    (evs : list (@event_record (@Tile F16) nat issue_pipe issue_resource)) : nat :=
  match evs with
  | [] => best
  | r :: rest =>
      let cur' :=
        match payload r with
        | LReadStart _ _ | LWriteStart _ _ _ | LComputeStart _ _
        | LSetFlagStart _ _ _ | LWaitFlagStart _ _ _ => S cur
        | LReadEnd _ | LWriteEnd | LComputeEnd _
        | LSetFlagEnd | LWaitFlagEnd => pred cur
        | _ => cur
        end in
      max_inflight_aux cur' (Nat.max best cur') rest
  end.

Definition max_inflight {F16 : Type}
    (evs : list (@event_record (@Tile F16) nat issue_pipe issue_resource)) : nat :=
  max_inflight_aux 0 0 evs.

(* 辅助：计算满足谓词的第一个事件下标 *)
Fixpoint first_index_of {A : Type} (p : A -> bool) (xs : list A) : option nat :=
  match xs with
  | [] => None
  | x :: rest =>
      if p x then Some 0
      else option_map S (first_index_of p rest)
  end.

Fixpoint nth_index_of {A : Type} (n : nat) (p : A -> bool) (xs : list A) : option nat :=
  match xs with
  | [] => None
  | x :: rest =>
      if p x then
        match n with
        | 0 => Some 0
        | S n' => option_map S (nth_index_of n' p rest)
        end
      else option_map S (nth_index_of n p rest)
  end.

Definition is_mte2_read_from {F16 : Type} (addr : memory_resource)
    (r : @event_record (@Tile F16) nat issue_pipe issue_resource) : bool :=
  match payload r with
  | LReadStart (Dispatch TransferEngine (Some MTE2)) a => Nat.eqb a addr
  | _ => false
  end.

Definition is_mte2_write_to {F16 : Type} (addr : memory_resource)
    (r : @event_record (@Tile F16) nat issue_pipe issue_resource) : bool :=
  match payload r with
  | LWriteStart (Dispatch TransferEngine (Some MTE2)) a _ => Nat.eqb a addr
  | _ => false
  end.

Definition is_vec_write_output {F16 : Type}
    (r : @event_record (@Tile F16) nat issue_pipe issue_resource) : bool :=
  match payload r with
  | LWriteStart (Dispatch VectorUnit (Some Vector)) a _ => Nat.eqb a output
  | _ => false
  end.

Definition is_vec_compute_start {F16 : Type}
    (r : @event_record (@Tile F16) nat issue_pipe issue_resource) : bool :=
  match payload r with
  | LComputeStart (Dispatch VectorUnit (Some Vector)) _ => true
  | _ => false
  end.

Definition is_set_flag_start {F16 : Type} (src dst : issue_pipe) (fl : nat)
    (r : @event_record (@Tile F16) nat issue_pipe issue_resource) : bool :=
  match payload r with
  | LSetFlagStart p q f => issue_pipe_eqb p src && issue_pipe_eqb q dst && Nat.eqb f fl
  | _ => false
  end.

(* 判定轨迹是否展示了双缓冲重叠：
   1) MTE2 迭代 1 开始从输入地址 4 读取（为 bufB 准备）早于 Vector 迭代 0 开始写回 output；
   2) MTE2 迭代 1 向 bufB 发起写入早于 Vector 迭代 0 结束写回/释放 bufA；
   3) 同时在途操作数 >= 2；
   4) MTE2 迭代 2 第二次向 bufA 发起写入严格晚于 Vector 迭代 0 发起释放 freeA (flag 2)。 *)
Definition check_double_buffer_overlap {F16 : Type}
    (evs : list (@event_record (@Tile F16) nat issue_pipe issue_resource)) : bool :=
  let bufA_addr := buffer_a odd_allocation_layout in
  let bufB_addr := buffer_b odd_allocation_layout in
  match first_index_of (is_mte2_read_from 4) evs,
        first_index_of (is_mte2_write_to bufB_addr) evs,
        first_index_of is_vec_write_output evs,
        nth_index_of 1 (is_set_flag_start Vector MTE2 2) evs,
        nth_index_of 1 (is_mte2_write_to bufA_addr) evs with
  | Some idx_mte2_read1, Some idx_mte2_write_bufB, Some idx_vec_write0,
    Some idx_vec_release_bufA, Some idx_mte2_write_bufA_2 =>
      Nat.ltb idx_mte2_read1 idx_vec_write0 &&
      Nat.ltb idx_mte2_write_bufB idx_vec_release_bufA &&
      Nat.ltb idx_vec_release_bufA idx_mte2_write_bufA_2 &&
      Nat.leb 2 (max_inflight evs)
  | _, _, _, _, _ => false
  end.

Section RunIssue316.
Context {F16 : Type}.
Context (exp_f16 : F16 -> F16).
Context (model : @computation_model (@Tile F16) nat issue_pipe issue_resource).
Context (Hexp : implements_vexp exp_f16 model).
Context (tile0 tile1 tile2 : @Tile F16).

Definition init_input_mem (a : memory_resource) : option (@value (@Tile F16) nat issue_pipe) :=
  match a with
  | 2 => Some (VFloat tile0)
  | 4 => Some (VFloat tile1)
  | 6 => Some (VFloat tile2)
  | _ => None
  end.

Definition issue316_cpol := strict_choice_policy (Pipe := issue_pipe) (EventId := nat) init_input_mem.
Definition issue316_tgt3 := issue316_exec_target (F16 := F16) odd_allocation_layout 3.
Definition issue316_em := issue316_exec_model Hexp.

Definition issue316_run_serialized :=
  run_derived_interpreter odd_allocation_layout issue316_tgt3 issue316_em
    issue316_cpol serialized_policy 300 32 (issue316 3).

Definition issue316_run_overlapped :=
  run_derived_interpreter odd_allocation_layout issue316_tgt3 issue316_em
    issue316_cpol (overlapped_round_robin_policy 8) 300 32 (issue316 3).

Definition issue316_run_free_overlapped :=
  run_free_interpreter odd_allocation_layout issue316_tgt3 issue316_em
    issue316_cpol (overlapped_round_robin_policy 8) 300 300 32 (issue316 3).

(* 1. 串行调度：自动运行完成、无在途残留、输出 3 个正确 exp(tile_i)，且满足公理化 issue316_trace *)
Theorem issue316_serialized_valid :
  exists res,
    issue316_run_serialized = Ok res /\
    rr_inflight_count res = 0 /\
    length (rr_events res) = 125 /\
    rr_outputs res = [Some []; Some []] /\
    vector_output_writes (rr_events res) =
      [VFloat (map_tile exp_f16 tile0);
       VFloat (map_tile exp_f16 tile1);
       VFloat (map_tile exp_f16 tile2)] /\
    issue316_trace odd_allocation_layout exp_f16 model 3
      (trace_of_records nat_trace_indexer (rr_events res))
      (kappa_of_records nat_trace_indexer (rr_events res)).
Proof.
  assert (H1 : (match issue316_run_serialized with Ok res => rr_inflight_count res | Error _ => 1 end) = 0)
    by (vm_cast_no_check (eq_refl 0)).
  assert (Hlen : (match issue316_run_serialized with Ok res => length (rr_events res) | Error _ => 0 end) = 125)
    by (vm_cast_no_check (eq_refl 125)).
  assert (H2 : (match issue316_run_serialized with Ok res => rr_outputs res | Error _ => [] end) =
    ([Some []; Some []] : list (option (list (@value (@Tile F16) nat issue_pipe)))))
    by (vm_cast_no_check (eq_refl ([Some []; Some []] : list (option (list (@value (@Tile F16) nat issue_pipe)))))).
  assert (H3 : (match issue316_run_serialized with Ok res => vector_output_writes (rr_events res) | Error _ => [] end) =
    [VFloat (map_tile exp_f16 tile0); VFloat (map_tile exp_f16 tile1); VFloat (map_tile exp_f16 tile2)])
    by (vm_cast_no_check (eq_refl ([VFloat (map_tile exp_f16 tile0); VFloat (map_tile exp_f16 tile1); VFloat (map_tile exp_f16 tile2)] : list (@value (@Tile F16) nat issue_pipe)))).
  destruct issue316_run_serialized as [res|err] eqn:Hrun; [| discriminate H1].
  exists res.
  split; [reflexivity |].
  split; [exact H1 |].
  split; [exact Hlen |].
  split; [exact H2 |].
  split; [exact H3 |].
  split; [split; [exact Hexp | apply odd_buffers_disjoint] |].
  unfold issue316_run_serialized in Hrun.
  eapply (derived_interpreter_sound odd_allocation_layout issue316_tgt3 issue316_em
    issue316_cpol nat_trace_indexer serialized_policy 300 32 (issue316 3));
    [apply issue316_well_formed | exact Hrun].
Qed.

(* 2. 重叠轮转调度：自动运行完成、无在途残留、输出正确、展示真实双缓冲流水线重叠（最高 6 个在途操作），且满足 issue316_trace *)
Theorem issue316_overlapped_valid :
  exists res,
    issue316_run_overlapped = Ok res /\
    rr_inflight_count res = 0 /\
    length (rr_events res) = 125 /\
    max_inflight (rr_events res) = 6 /\
    rr_outputs res = [Some []; Some []] /\
    vector_output_writes (rr_events res) =
      [VFloat (map_tile exp_f16 tile0);
       VFloat (map_tile exp_f16 tile1);
       VFloat (map_tile exp_f16 tile2)] /\
    check_double_buffer_overlap (rr_events res) = true /\
    issue316_trace odd_allocation_layout exp_f16 model 3
      (trace_of_records nat_trace_indexer (rr_events res))
      (kappa_of_records nat_trace_indexer (rr_events res)).
Proof.
  assert (H1 : (match issue316_run_overlapped with Ok res => rr_inflight_count res | Error _ => 1 end) = 0)
    by (vm_cast_no_check (eq_refl 0)).
  assert (Hlen : (match issue316_run_overlapped with Ok res => length (rr_events res) | Error _ => 0 end) = 125)
    by (vm_cast_no_check (eq_refl 125)).
  assert (Hmax : (match issue316_run_overlapped with Ok res => max_inflight (rr_events res) | Error _ => 0 end) = 6)
    by (vm_cast_no_check (eq_refl 6)).
  assert (H2 : (match issue316_run_overlapped with Ok res => rr_outputs res | Error _ => [] end) =
    ([Some []; Some []] : list (option (list (@value (@Tile F16) nat issue_pipe)))))
    by (vm_cast_no_check (eq_refl ([Some []; Some []] : list (option (list (@value (@Tile F16) nat issue_pipe)))))).
  assert (H3 : (match issue316_run_overlapped with Ok res => vector_output_writes (rr_events res) | Error _ => [] end) =
    [VFloat (map_tile exp_f16 tile0); VFloat (map_tile exp_f16 tile1); VFloat (map_tile exp_f16 tile2)])
    by (vm_cast_no_check (eq_refl ([VFloat (map_tile exp_f16 tile0); VFloat (map_tile exp_f16 tile1); VFloat (map_tile exp_f16 tile2)] : list (@value (@Tile F16) nat issue_pipe)))).
  assert (Hov : (match issue316_run_overlapped with Ok res => check_double_buffer_overlap (rr_events res) | Error _ => false end) = true)
    by (vm_cast_no_check (eq_refl true)).
  destruct issue316_run_overlapped as [res|err] eqn:Hrun; [| discriminate H1].
  exists res.
  split; [reflexivity |].
  split; [exact H1 |].
  split; [exact Hlen |].
  split; [exact Hmax |].
  split; [exact H2 |].
  split; [exact H3 |].
  split; [exact Hov |].
  split; [split; [exact Hexp | apply odd_buffers_disjoint] |].
  unfold issue316_run_overlapped in Hrun.
  eapply (derived_interpreter_sound odd_allocation_layout issue316_tgt3 issue316_em
    issue316_cpol nat_trace_indexer (overlapped_round_robin_policy 8) 300 32 (issue316 3));
    [apply issue316_well_formed | exact Hrun].
Qed.

(* 3. 高阶 Free Monad 解释器在 Issue #316 上与一阶派生解释器完全一致且满足 issue316_trace *)
Theorem issue316_free_matches_and_valid :
  issue316_run_free_overlapped = issue316_run_overlapped /\
  exists res,
    issue316_run_free_overlapped = Ok res /\
    issue316_trace odd_allocation_layout exp_f16 model 3
      (trace_of_records nat_trace_indexer (rr_events res))
      (kappa_of_records nat_trace_indexer (rr_events res)).
Proof.
  assert (Heq : issue316_run_free_overlapped = issue316_run_overlapped).
  { unfold issue316_run_free_overlapped, issue316_run_overlapped.
    apply free_and_derived_equivalent; lia. }
  split; [exact Heq |].
  destruct issue316_overlapped_valid as [res [Hok [_ [_ [_ [_ [_ [_ Htr]]]]]]]].
  exists res; split; [rewrite Heq; exact Hok | exact Htr].
Qed.

End RunIssue316.
End Issue316Validation.

(* ========================================================================== *)
(* 2. ResourceExamples.SharedResource：无 pipeline 共享计算资源允许任意发起序   *)
(* ========================================================================== *)

Module SharedResourceValidation.

Definition empty_set_eqb (x y : Empty_set) : bool := match x with end.

Lemma empty_set_eqb_spec x y : empty_set_eqb x y = true <-> x = y.
Proof. destruct x. Qed.

Definition empty_set_eq_ops : eq_dec_ops Empty_set :=
  EqDecOps empty_set_eqb empty_set_eqb_spec.

Definition shared_res_exec_target : @executable_target unit nat Empty_set unit.
Proof.
  refine {|
    exec_cfg := SharedResource.cfg;
    pipe_eq := empty_set_eq_ops;
    event_eq := nat_eq_ops;
    check_declared_pipe := fun _ => false;
    check_declared_resource := fun _ => true;
    check_can_read := fun _ _ => false;
    check_can_write := fun _ _ => false
  |}.
  - intros p; destruct p.
  - intros r _; exact I.
  - intros r a H; discriminate.
  - intros r a H; discriminate.
Defined.

Definition shared_res_prog : @shared_program unit nat Empty_set unit :=
  Run [SharedResource.branch; SharedResource.branch].

Lemma shared_res_well_formed :
  well_formed SharedResource.cfg (instantiate_shared odd_allocation_layout 0 shared_res_prog).
Proof.
  cbn. split; [discriminate |].
  repeat apply Forall_cons; try apply Forall_nil.
  all: split; [repeat constructor; simpl; tauto |].
  all: split; [cbn; repeat constructor | split; [exact I | exists (fun _ => TFloat); cbn; auto]].
Qed.

Definition shared_res_model : @computation_model unit nat Empty_set unit :=
  model_of (fun _ _ => VFloat tt).
Definition shared_res_emodel : executable_model shared_res_model :=
  exec_model_of (fun _ _ => VFloat tt).
Definition shared_res_cpol :=
  strict_choice_policy (Float := unit) (EventId := nat) (Pipe := Empty_set) (fun _ => None).

Definition run_order_01 :=
  run_derived_interpreter odd_allocation_layout shared_res_exec_target shared_res_emodel
    shared_res_cpol (scripted_policy [ActIssue 0; ActIssue 1]) 10 8 shared_res_prog.

Definition run_order_10 :=
  run_derived_interpreter odd_allocation_layout shared_res_exec_target shared_res_emodel
    shared_res_cpol (scripted_policy [ActIssue 1; ActIssue 0]) 10 8 shared_res_prog.

Theorem shared_resource_both_orders_derived :
  exists res01 res10,
    run_order_01 = Ok res01 /\
    run_order_10 = Ok res10 /\
    rr_events res01 = [SharedResource.start 1%positive; SharedResource.start 2%positive] /\
    rr_events res10 = [SharedResource.start 2%positive; SharedResource.start 1%positive] /\
    shared_program_semantics odd_allocation_layout SharedResource.cfg shared_res_model
      shared_res_prog
      (trace_of_records nat_trace_indexer (rr_events res01))
      (kappa_of_records nat_trace_indexer (rr_events res01)) /\
    shared_program_semantics odd_allocation_layout SharedResource.cfg shared_res_model
      shared_res_prog
      (trace_of_records nat_trace_indexer (rr_events res10))
      (kappa_of_records nat_trace_indexer (rr_events res10)).
Proof.
  assert (H01e : (match run_order_01 with Ok r => rr_events r | Error _ => [] end) =
    [SharedResource.start 1%positive; SharedResource.start 2%positive])
    by (vm_cast_no_check (eq_refl [SharedResource.start 1%positive; SharedResource.start 2%positive])).
  assert (H10e : (match run_order_10 with Ok r => rr_events r | Error _ => [] end) =
    [SharedResource.start 2%positive; SharedResource.start 1%positive])
    by (vm_cast_no_check (eq_refl [SharedResource.start 2%positive; SharedResource.start 1%positive])).
  destruct run_order_01 as [r01|e01] eqn:H01; [| discriminate H01e].
  destruct run_order_10 as [r10|e10] eqn:H10; [| discriminate H10e].
  exists r01, r10.
  split; [reflexivity |].
  split; [reflexivity |].
  split; [exact H01e |].
  split; [exact H10e |].
  unfold run_order_01 in H01; unfold run_order_10 in H10.
  split; [eapply (derived_interpreter_sound odd_allocation_layout shared_res_exec_target
            shared_res_emodel shared_res_cpol nat_trace_indexer
            (scripted_policy [ActIssue 0; ActIssue 1]) 10 8 shared_res_prog);
          [exact shared_res_well_formed | exact H01] |].
  eapply (derived_interpreter_sound odd_allocation_layout shared_res_exec_target
            shared_res_emodel shared_res_cpol nat_trace_indexer
            (scripted_policy [ActIssue 1; ActIssue 0]) 10 8 shared_res_prog);
    [exact shared_res_well_formed | exact H10].
Qed.

End SharedResourceValidation.

(* ========================================================================== *)
(* 3. 内存可见性（最新完成写入）与 strict / permissive 策略对比验证             *)
(* ========================================================================== *)

Module MemoryAndChoiceValidation.

Definition bool_eq_ops : eq_dec_ops bool :=
  EqDecOps Bool.eqb Bool.eqb_true_iff.

Definition open_bool_cfg : @configuration bool unit :=
  {| declared_pipeline := fun _ => True;
     declared_resource := fun _ => True;
     can_read := fun _ _ => True;
     can_write := fun _ _ => True |}.

Definition open_bool_exec_target : @executable_target unit nat bool unit.
Proof.
  refine {|
    exec_cfg := open_bool_cfg;
    pipe_eq := bool_eq_ops;
    event_eq := nat_eq_ops;
    check_declared_pipe := fun _ => true;
    check_declared_resource := fun _ => true;
    check_can_read := fun _ _ => true;
    check_can_write := fun _ _ => true
  |}; intros; exact I.
Defined.

Definition open_model : @computation_model unit nat bool unit :=
  model_of (fun _ _ => VInt 0%Z).
Definition open_emodel : executable_model open_model :=
  exec_model_of (fun _ _ => VInt 0%Z).

(* 场景 A：对应 ResourceExamples.MemoryValues.reads_after_overwrite：
   分支 0 依次发起向 buf0 写 10、写 20、写 40；
   分支 1 在写 10 完成后发起读，并在写 20 完成、写 40 仅发起未完成时完成读 -> 必读到 20！ *)
Definition overwrite_prog : @shared_program unit nat bool unit :=
  SharedAlloc 0 (Run [
    Write tt (Dispatch tt (Some (Literal (VPipe true)))) (OVar 0) (Literal (VInt 10%Z)) (
    Write tt (Dispatch tt (Some (Literal (VPipe true)))) (OVar 0) (Literal (VInt 20%Z)) (
    Write tt (Dispatch tt (Some (Literal (VPipe true)))) (OVar 0) (Literal (VInt 40%Z)) (
    Return tt [])));
    Read tt 1 (Dispatch tt None) (OVar 0) (Return tt [OVar 1])
  ]).

Lemma overwrite_prog_wf :
  well_formed open_bool_cfg (instantiate_shared odd_allocation_layout 0 overwrite_prog).
Proof.
  cbn. split; [discriminate |].
  repeat apply Forall_cons; try apply Forall_nil.
  all: split; [cbv; repeat constructor; cbn; intuition discriminate |].
  all: split; [cbn; repeat split; repeat apply Forall_cons; try apply Forall_nil; cbv; auto |].
  all: split; [cbn; tauto | exists (fun v => match v with 0 => TMemory | _ => TInt end); cbn; repeat split; repeat constructor].
Qed.

(* SharedAlloc 0 在各分支外包了一层 CAlias，故分支 0 的 3 条 Write 的 op_id 为 (1,2), (1,4), (1,8)，分支 1 的 Read 为 (2,2) *)
Definition overwrite_script : list schedule_action :=
  [ ActIssue 0; ActFinish (1, 2)%positive;        (* Write 10 start + end *)
    ActIssue 1;                                    (* Read start (in-flight) *)
    ActIssue 0; ActFinish (1, 4)%positive;        (* Write 20 start + end *)
    ActIssue 0;                                    (* Write 40 start (still pending!) *)
    ActFinish (2, 2)%positive;                    (* Read end -> must observe VInt 20! *)
    ActIssue 1                                     (* Return [VInt 20] *)
  ].

Definition run_overwrite :=
  run_derived_interpreter odd_allocation_layout open_bool_exec_target open_emodel
    (strict_choice_policy (fun _ => None))
    (scripted_policy overwrite_script) 20 8 overwrite_prog.

Theorem overwrite_observes_latest_completed_write :
  exists res,
    run_overwrite = Ok res /\
    rr_outputs res = [None; Some [VInt 20%Z]] /\
    shared_program_semantics odd_allocation_layout open_bool_cfg open_model overwrite_prog
      (trace_of_records nat_trace_indexer (rr_events res))
      (kappa_of_records nat_trace_indexer (rr_events res)).
Proof.
  assert (Hout : (match run_overwrite with Ok res => rr_outputs res | Error _ => [] end) =
    ([None; Some [VInt 20%Z]] : list (option (list (@value unit nat bool)))))
    by (vm_cast_no_check (eq_refl ([None; Some [VInt 20%Z]] : list (option (list (@value unit nat bool)))))).
  destruct run_overwrite as [res|err] eqn:Hrun; [| discriminate Hout].
  exists res.
  split; [reflexivity |].
  split; [exact Hout |].
  unfold run_overwrite in Hrun.
  eapply (derived_interpreter_sound odd_allocation_layout open_bool_exec_target open_emodel
    (strict_choice_policy (fun _ => None)) nat_trace_indexer
    (scripted_policy overwrite_script) 20 8 overwrite_prog);
    [exact overwrite_prog_wf | exact Hrun].
Qed.

(* 场景 B：读未初始化内存（strict 拒绝 vs permissive 允许并仍满足公理语义） *)
Definition uninit_read_prog : @shared_program unit nat bool unit :=
  Run [Read tt 0 (Dispatch tt None) (Literal (VMemory 42)) (Return tt [OVar 0])].

Lemma uninit_read_wf :
  well_formed open_bool_cfg (instantiate_shared odd_allocation_layout 0 uninit_read_prog).
Proof.
  cbn. split; [discriminate |].
  repeat apply Forall_cons; try apply Forall_nil.
  split; [cbv; repeat constructor; cbn; intuition discriminate |].
  split; [cbn; repeat constructor |].
  split; [cbn; tauto | exists (fun _ => TInt); cbn; repeat split; repeat constructor].
Qed.

Theorem uninit_read_strict_rejects_scripted :
  run_derived_interpreter odd_allocation_layout open_bool_exec_target open_emodel
    (strict_choice_policy (fun _ => None))
    (scripted_policy [ActIssue 0; ActFinish (1, 1)%positive]) 20 8 uninit_read_prog =
  Error (ErrUninitMemoryRead (1, 1)%positive 42).
Proof. vm_cast_no_check (eq_refl (Error (A := @run_result unit nat bool unit) (ErrUninitMemoryRead (1, 1)%positive 42))). Qed.

Theorem uninit_read_strict_deadlocks_serialized :
  run_derived_interpreter odd_allocation_layout open_bool_exec_target open_emodel
    (strict_choice_policy (fun _ => None))
    serialized_policy 20 8 uninit_read_prog =
  Error ErrDeadlocked.
Proof. vm_cast_no_check (eq_refl (Error (A := @run_result unit nat bool unit) ErrDeadlocked)). Qed.

Definition run_uninit_permissive :=
  run_derived_interpreter odd_allocation_layout open_bool_exec_target open_emodel
    (permissive_choice_policy (fun _ => None) (fun _ _ _ => VInt 0%Z) (VInt 99%Z))
    serialized_policy 20 8 uninit_read_prog.

Theorem uninit_read_permissive_sound :
  exists res,
    run_uninit_permissive = Ok res /\
    rr_outputs res = [Some [VInt 99%Z]] /\
    shared_program_semantics odd_allocation_layout open_bool_cfg open_model uninit_read_prog
      (trace_of_records nat_trace_indexer (rr_events res))
      (kappa_of_records nat_trace_indexer (rr_events res)).
Proof.
  assert (Hout : (match run_uninit_permissive with Ok res => rr_outputs res | Error _ => [] end) =
    ([Some [VInt 99%Z]] : list (option (list (@value unit nat bool)))))
    by (vm_cast_no_check (eq_refl ([Some [VInt 99%Z]] : list (option (list (@value unit nat bool)))))).
  destruct run_uninit_permissive as [res|err] eqn:Hrun; [| discriminate Hout].
  exists res.
  split; [reflexivity |].
  split; [exact Hout |].
  unfold run_uninit_permissive in Hrun.
  eapply (derived_interpreter_sound odd_allocation_layout open_bool_exec_target open_emodel
    (permissive_choice_policy (fun _ => None) (fun _ _ _ => VInt 0%Z) (VInt 99%Z)) nat_trace_indexer
    serialized_policy 20 8 uninit_read_prog);
    [exact uninit_read_wf | exact Hrun].
Qed.

(* 场景 C：循环内动态 Alloc 分配互不相同的内存地址（对应 ResourceExamples.LocalAllocation） *)
Definition loop_alloc_prog : @shared_program unit nat bool unit :=
  Run [For 0 0 2 (Alloc tt 1 LoopEnd) (Return tt [])].

Lemma loop_alloc_wf :
  well_formed open_bool_cfg (instantiate_shared odd_allocation_layout 0 loop_alloc_prog).
Proof.
  cbn. split; [discriminate |].
  repeat apply Forall_cons; try apply Forall_nil.
  split; [cbv; repeat constructor; cbn; intuition discriminate |].
  split; [cbn; repeat constructor |].
  split; [cbn; tauto | exists (fun v => match v with 0 => TInt | _ => TMemory end); cbn; repeat split; repeat constructor].
Qed.

Definition alloc_addrs (evs : list (@event_record unit nat bool unit)) : list memory_resource :=
  flat_map (fun r => match payload r with LAlloc a => [a] | _ => [] end) evs.

Definition run_loop_alloc :=
  run_derived_interpreter odd_allocation_layout open_bool_exec_target open_emodel
    (strict_choice_policy (fun _ => None))
    serialized_policy 20 16 loop_alloc_prog.

Theorem loop_alloc_distinct_and_sound :
  exists res a1 a2,
    run_loop_alloc = Ok res /\
    alloc_addrs (rr_events res) = [a1; a2] /\
    a1 <> a2 /\
    shared_program_semantics odd_allocation_layout open_bool_cfg open_model loop_alloc_prog
      (trace_of_records nat_trace_indexer (rr_events res))
      (kappa_of_records nat_trace_indexer (rr_events res)).
Proof.
  assert (Haddrs : (match run_loop_alloc with Ok res => alloc_addrs (rr_events res) | Error _ => [] end) =
    [address_at odd_allocation_layout (InBranch (1, 2)%positive);
     address_at odd_allocation_layout (InBranch (1, 8)%positive)])
    by (vm_cast_no_check (eq_refl [address_at odd_allocation_layout (InBranch (1, 2)%positive);
                                    address_at odd_allocation_layout (InBranch (1, 8)%positive)])).
  destruct run_loop_alloc as [res|err] eqn:Hrun; [| discriminate Haddrs].
  exists res,
    (address_at odd_allocation_layout (InBranch (1, 2)%positive)),
    (address_at odd_allocation_layout (InBranch (1, 8)%positive)).
  split; [reflexivity |].
  split; [exact Haddrs |].
  split; [apply distinct_allocations; discriminate |].
  unfold run_loop_alloc in Hrun.
  eapply (derived_interpreter_sound odd_allocation_layout open_bool_exec_target open_emodel
    (strict_choice_policy (fun _ => None)) nat_trace_indexer
    serialized_policy 20 16 loop_alloc_prog);
    [exact loop_alloc_wf | exact Hrun].
Qed.

End MemoryAndChoiceValidation.
