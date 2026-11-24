(* Standalone check driver exercising Rocq-extracted derived_core_interpreter.cmo
   directly, without linking the hand-written lib/ OCaml interpreter. *)

open Derived_core_interpreter

let rec pos_to_int = function
  | XH -> 1
  | XO p -> 2 * pos_to_int p
  | XI p -> (2 * pos_to_int p) + 1

let z_to_int = function
  | Z0 -> 0
  | Zpos p -> pos_to_int p
  | Zneg p -> -(pos_to_int p)

let op_id_to_pair (t, p) = (pos_to_int t, pos_to_int p)

let assert_summary label expected actual =
  match actual with
  | None -> failwith (label ^ ": returned None")
  | Some ((((len, inflight), max_inf), overlap), outs) ->
      let outs_i = List.map z_to_int outs in
      let got = (len, inflight, max_inf, overlap, outs_i) in
      if got <> expected then
        failwith
          (Printf.sprintf
             "%s: mismatch (got len=%d inflight=%d max_inf=%d overlap=%b)"
             label len inflight max_inf overlap)

let () =
  (* 1. Issue #316 serialized (max_inflight=2), overlapped derived & free (max_inflight=6) *)
  assert_summary "issue316_serialized"
    (125, 0, 2, true, [ 101; 102; 103 ])
    DerivedExtractionDemo.demo_issue316_serialized_summary;
  assert_summary "issue316_overlapped"
    (125, 0, 6, true, [ 101; 102; 103 ])
    DerivedExtractionDemo.demo_issue316_overlapped_summary;
  assert_summary "issue316_free_overlapped"
    (125, 0, 6, true, [ 101; 102; 103 ])
    DerivedExtractionDemo.demo_issue316_free_overlapped_summary;

  (* 2. SharedResource both issue orders *)
  (match DerivedExtractionDemo.demo_shared_order_01 with
  | Ok res -> (
      match List.map (fun r -> op_id_to_pair r.owner) res.rr_events with
      | [ (1, 1); (2, 1) ] -> ()
      | _ -> failwith "shared_order_01: unexpected owners")
  | Error _ -> failwith "shared_order_01: expected Ok");
  (match DerivedExtractionDemo.demo_shared_order_10 with
  | Ok res -> (
      match List.map (fun r -> op_id_to_pair r.owner) res.rr_events with
      | [ (2, 1); (1, 1) ] -> ()
      | _ -> failwith "shared_order_10: unexpected owners")
  | Error _ -> failwith "shared_order_10: expected Ok");

  (* 3. Overwrite observes latest completed write (20, not in-flight 40) *)
  (match DerivedExtractionDemo.demo_overwrite with
  | Ok res -> (
      match res.rr_outputs with
      | [ None; Some [ VInt z ] ] when z_to_int z = 20 -> ()
      | _ -> failwith "overwrite: expected [None; Some [VInt 20]]")
  | Error _ -> failwith "overwrite: expected Ok");

  (* 4. Uninitialized memory read: strict rejects/deadlocks, permissive succeeds *)
  (match DerivedExtractionDemo.demo_uninit_strict_scripted with
  | Error (ErrUninitMemoryRead (o, 42)) when op_id_to_pair o = (1, 1) -> ()
  | _ -> failwith "uninit_strict_scripted: expected ErrUninitMemoryRead((1,1),42)");
  (match DerivedExtractionDemo.demo_uninit_strict_deadlock with
  | Error ErrDeadlocked -> ()
  | _ -> failwith "uninit_strict_deadlock: expected ErrDeadlocked");
  (match DerivedExtractionDemo.demo_uninit_permissive with
  | Ok res -> (
      match res.rr_outputs with
      | [ Some [ VInt z ] ] when z_to_int z = 99 -> ()
      | _ -> failwith "uninit_permissive: expected [Some [VInt 99]]")
  | Error _ -> failwith "uninit_permissive: expected Ok");

  (* 5. Early Async Use (Issue #920 style): strict rejects, permissive succeeds *)
  (match DerivedExtractionDemo.demo_early_async_strict with
  | Error (ErrEarlyAsyncUse (c, p))
    when op_id_to_pair c = (1, 2) && op_id_to_pair p = (1, 1) ->
      ()
  | _ -> failwith "early_async_strict: expected ErrEarlyAsyncUse((1,2),(1,1))");
  (match DerivedExtractionDemo.demo_early_async_permissive with
  | Ok res ->
      if res.rr_inflight_count <> 0 then
        failwith "early_async_permissive: expected 0 inflight";
      (match res.rr_outputs with
      | [ Some [ VInt z ] ] when z_to_int z = 777 -> ()
      | _ -> failwith "early_async_permissive: expected [Some [VInt 777]]");
      if List.length res.rr_events <> 3 then
        failwith "early_async_permissive: expected 3 events"
  | Error _ -> failwith "early_async_permissive: expected Ok");

  (* 6. Loop-local Alloc produces distinct addresses *)
  (match DerivedExtractionDemo.demo_loop_alloc with
  | Ok res -> (
      let addrs =
        List.filter_map
          (fun r -> match r.payload with LAlloc a -> Some a | _ -> None)
          res.rr_events
      in
      match addrs with
      | [ a1; a2 ] when a1 <> a2 -> ()
      | _ -> failwith "loop_alloc: expected 2 distinct alloc addresses")
  | Error _ -> failwith "loop_alloc: expected Ok");

  print_endline
    "Derived CoreLanguage extraction: Issue #316 (serialized + overlapped + free), SharedResource, Overwrite, UninitRead, EarlyAsyncUse, and LoopAlloc all passed."
