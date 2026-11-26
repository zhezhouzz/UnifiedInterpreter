open Unified_interpreter
open Core_lang
open Bug_traces

let int n = Literal (VInt (Z.of_int n))
let flag n = Literal (VEvent n)
let addresses offsets = List.map (fun offset -> Input 0, offset) offsets
let view offsets = Literal (VView (addresses offsets))
let as_view = function VView v -> v | _ -> invalid_arg "view"
let stream id body = { id; params = []; pipes = [0; 1]; body }
let program streams = {
  streams;
  scalar_eval = (fun _ op args -> match op, args with
    | 0, [VInt i] -> VInt (Z.erem i (Z.of_int 2))
    | 1, [VInt i] -> VEvent (Z.to_int i)
    | 2, [VInt i; a; b] -> if Z.equal i Z.zero then a else b
    | 3, [VInt i] -> VView (addresses [3 + Z.to_int i])
    | _ -> invalid_arg "scalar operation");
  footprint = (fun _ _ op args -> match op, List.map as_view args with
    | 0, [src; dst] -> { reads = src; writes = dst }
    | 1, [src] -> { reads = src; writes = [] }
    | 2, [dst] -> { reads = []; writes = dst }
    | _ -> invalid_arg "operation");
  block_edge = (fun sender _ receiver _ -> sender <> receiver);
}

let copy pipe src dst rest = Issue (pipe, 0, [src; dst], rest)
let read pipe v rest = Issue (pipe, 1, [v], rest)
let write pipe v rest = Issue (pipe, 2, [v], rest)
let local body = program [stream 0 body]
let one = view [1]

(* 小程序的参照实现逐一枚举前缀。队列直接保存待完成项，
   每次完成按当前位置移除；每条路径独立保留。 *)
let exhaustive ~loop_bound p =
  let streams = List.map (fun s -> s, stream_plan ~loop_bound p s) p.streams in
  let directions = Hashtbl.create 16 and truncated = ref false in
  let rec visit length completed streams queues tokens allocated =
    List.iteri (fun i (s, plan) -> match plan.actions with
      | [] -> if plan.cutoff then truncated := true
      | (id, action) :: rest ->
          let advance ?(allocated = allocated) ?(completed = completed) queues tokens =
            let streams = List.mapi (fun j v -> if j = i then s, { plan with actions = rest } else v) streams in
            visit (length + 1) completed streams queues tokens allocated in
          let enqueue queues pipe item =
            let key = s.id, pipe in
            let q = Option.value ~default:[] (List.assoc_opt key queues) in
            (key, q @ [id, item]) :: List.remove_assoc key queues in
          (match action with
           | Submit (pipe, item) -> advance (enqueue queues pipe item) tokens
           | Fence pipes -> advance (List.fold_left (fun qs pipe -> enqueue qs pipe Bar) queues pipes) tokens
           | Scalar_wait k -> if List.mem k tokens then advance queues (List.filter ((<>) k) tokens)
           | Immediate (Set ks) -> if List.for_all (fun k -> not (List.mem k tokens)) ks then
                 advance queues (ks @ tokens)
           | Immediate (Operation (_,fp)) ->
               if List.for_all (function Input _,_ -> true | a -> List.mem a allocated) (fp.reads @ fp.writes) then (
                 List.iter (fun (a,old) ->
                   let hits = List.sort_uniq compare (List.filter (fun v -> List.mem v (fp.reads @ fp.writes)) old.writes
                     @ List.filter (fun v -> List.mem v fp.writes) old.reads) in
                   if hits <> [] then
                     let size = Option.fold ~none:(length+1) ~some:(fun (_,n) -> min n (length+1))
                       (Hashtbl.find_opt directions (a,id)) in Hashtbl.replace directions (a,id) (hits,size)) completed;
                 advance ~completed:((id,fp)::completed) queues tokens)
           | Immediate (Wait_peers ks) ->
               if List.for_all (fun k -> List.mem k tokens) ks then
                 advance queues (List.filter (fun k -> not (List.mem k ks)) tokens)
           | Immediate (Wait _ | Bar) -> invalid_arg "unexpected scalar operation"
           | Reserve (_, view) -> advance ~allocated:(view @ allocated) queues tokens
           | Control -> advance queues tokens)
    ) streams;
    List.iter (fun (key, items) ->
      let rec choose earlier = function
        | [] -> ()
        | (id, item) :: rest ->
            let finish completed tokens =
              let queue = List.rev_append earlier rest in
              visit (length + 1) completed streams ((key, queue) :: List.remove_assoc key queues) tokens allocated in
            let valid = function (Input _, _) -> true | a -> List.mem a allocated in
            (match item with
             | Operation (_, fp) when not (List.for_all valid (fp.reads @ fp.writes)) -> ()
             | Operation (_, fp) ->
                 List.iter (fun (a, old) ->
                   let conflicts = List.sort_uniq compare
                     (List.filter (fun v -> List.mem v (fp.reads @ fp.writes)) old.writes @
                      List.filter (fun v -> List.mem v fp.writes) old.reads) in
                   if conflicts <> [] then (
                     let size = match Hashtbl.find_opt directions (a, id) with
                       | None -> length + 1 | Some (_, n) -> min (length + 1) n in
                     Hashtbl.replace directions (a, id) (conflicts, size))
                 ) completed;
                 finish ((id, fp) :: completed) tokens
             | Wait k -> if List.mem k tokens then finish completed (List.filter ((<>) k) tokens)
             | Wait_peers ks -> if List.for_all (fun k -> List.mem k tokens) ks then
                 finish completed (List.filter (fun k -> not (List.mem k ks)) tokens)
             | Set ks -> if earlier = [] && List.for_all (fun k -> not (List.mem k tokens)) ks then
                           finish completed (ks @ tokens)
             | Bar -> if earlier = [] then finish completed tokens);
            match item with Bar | Wait _ | Wait_peers _ -> () | _ -> choose ((id, item) :: earlier) rest
      in choose [] items
    ) queues
  in
  visit 0 [] streams [] [] [];
  Hashtbl.filter_map_inplace (fun (a, b) v ->
    if Hashtbl.mem directions (b, a) then Some v else None) directions;
  directions, !truncated

let validate ?loop_bound p result =
  let directions = Hashtbl.create 16 in
  let check a b addresses trace =
    replay ?loop_bound p trace;
    let completed = List.filter_map (function Done { id; item = Operation _; _ }
      | Issued (id,Immediate (Operation _)) -> Some id | _ -> None) trace in
    assert (List.filter (fun id -> id = a || id = b) completed = [a; b]);
    assert (not (Hashtbl.mem directions (a, b)));
    Hashtbl.add directions (a, b) (addresses, List.length trace) in
  List.iter (fun r ->
    check r.first r.second r.conflicts r.first_then_second;
    check r.second r.first r.conflicts r.second_then_first) result.races;
  directions

let check ?(bound = 3) ?(truncated = false) count p =
  let expected, cut = exhaustive ~loop_bound:bound p in
  assert (cut = truncated && Hashtbl.length expected = 2 * count);
  let verify ?loop_bound backend =
    let result = generate_bug_traces ~backend ?loop_bound p in
    let actual = validate ?loop_bound p result in
    assert (result.truncated = cut && Hashtbl.length actual = Hashtbl.length expected);
    Hashtbl.iter (fun pair info -> assert (Hashtbl.find actual pair = info)) expected
  in
  List.iter (verify ~loop_bound:bound) [Search; Solve];
  if not cut then List.iter verify [Search;Solve]

let () =
  let copies rest = copy 0 (view [0]) one (rest (copy 0 one (view [2]) End)) in
  let p = local (copies Fun.id) in
  check 1 p;
  check 1 (local (write 0 one (write scalar_pipe one End)));
  let set next = Sync (LocalSet,0,Data 1,flag 0,next) in
  let counted = local (set (set (Barrier (All,copies Fun.id)))) in
  List.iter (fun backend ->
    assert ((generate_bug_traces ~backend counted).races=[]);
    match (generate_bug_traces ~backend ~capacity:2 counted).races with
    | [w] -> List.iter (replay ~capacity:2 counted) [w.first_then_second;w.second_then_first]
    | _ -> assert false) [Search;Solve];
  (match (generate_bug_traces ~loop_bound:0 p).races with
   | [r] ->
       assert (r.conflicts = addresses [1]);
       let positions = List.filter_map (function Done { position; _ } -> Some position | _ -> None) in
       assert (positions r.first_then_second = [0; 0] && positions r.second_then_first = [1; 0]);
       let invalid = List.map (function Done e -> Done { e with position = 0 } | e -> e) r.second_then_first in
       (match replay ~loop_bound:0 p invalid with
        | () -> assert false | exception Invalid_argument _ -> ())
   | _ -> assert false);
  check 0 (local (copies (fun cmd -> Barrier (Pipe 0, cmd))));
  check 1 (local (copies (fun cmd -> Barrier (Pipe 1, cmd))));
  check 0 (local (copies (fun cmd -> Barrier (All, cmd))));
  check 1 (local (write 0 (view [0; 1]) (write 1 (view [1; 2]) End)));
  check 0 (local (write 0 (view [0]) (read 1 one End)));
  check 0 (local (read 0 one (read 1 one End)));
  check 3 (local (write 0 one (write 1 one (read 0 one End))));
  check 1 (program [stream 0 (read 0 one End); stream 1 (write 1 one End)]);
  let loop hi body = For (0, int 0, int hi, int 1, body, End) in
  check ~bound:0 ~truncated:true 0 (local (loop 2 (write 0 one End)));
  check ~bound:1 ~truncated:true 0 (local (loop 2 (write 0 one End)));
  check ~bound:2 1 (local (loop 2 (write 0 one End)));
  check ~bound:0 1 (local (For (0, int 0, int 0, int 1, End, copies Fun.id)));
  check ~bound:2 1 (local (For (0, int 3, int (-1), int (-2), write 0 one End, End)));
  check ~bound:1 0 (local (loop 3 (Return [])));
  check ~bound:1 0 (local (Sync (BlockWait, 0, ScalarEnd, flag 0, loop 2 End)));
  check ~bound:1 ~truncated:true 1
    (program [stream 0 (loop 2 (write 0 one End)); stream 1 (read 1 one End)]);
  let scoped = Alloc (0, 0, [int 2], write 0 (Var 0) (read 1 (Var 0) End)) in
  check 1 (local scoped);
  check 0 (local (loop 2 (Alloc (0, 0, [int 1], write 0 (Var 0) End))));
  let shared offset = Literal (VView [Allocated { stream = 0; site = []; iterations = [] }, offset]) in
  let use offset = stream 1 (write 0 (shared offset) (read 1 (shared offset) End)) in
  check 1 (program [stream 0 (Alloc (0, 0, [int 1], End)); use 0]);
  check 0 (program [stream 0 (Alloc (0, 0, [int 1], End)); use 1]);
  check 1 (local (Branch (Literal (VBool false), End, copies Fun.id, End)));
  let local_sync mode f next = Sync (mode, 0, Data 1, flag f, next) in
  check 1 (local (local_sync LocalSet 0 (local_sync LocalSet 0 (copies Fun.id))));
  check 0 (local (write 0 one (local_sync LocalSet 0 (local_sync LocalWait 0 (read 1 one End)))));
  check 0 (local (local_sync LocalWait 1 (write 0 one (local_sync LocalSet 0 (read 1 one End)))));
  let send next = Sync (BlockSet, 0, ScalarEnd, flag 0, next) in
  let recv next = Sync (BlockWait, 0, ScalarEnd, flag 0, next) in
  check 1 (program [stream 0 (send End); stream 1 (recv (read 0 one End));
                    stream 2 (recv (write 0 one End))]);
  check 0 (program [stream 0 (write 0 one (send End)); stream 1 (recv (read 1 one End))]);
  check 0 (program [stream 0 (send (send End)); stream 1 (recv (recv (write 0 one End)));
                    stream 2 (read 1 one End)]);
  let two_senders =
    program [stream 0 (send End); stream 1 (send End);
             stream 2 (recv (recv (write 0 one (read 1 one End))))] in
  check 1 { two_senders with block_edge = (fun _ _ receiver _ -> receiver = 2) };
  let data_send next = Sync (BlockSet, 0, Data 1, flag 0, next) in
  let data_wait next = Sync (BlockWait, 0, Data 1, flag 0, next) in
  check 0 (program [stream 0 (write 0 one (data_send End));
                    stream 1 (data_wait (read 1 one End))]);
  check ~bound:2 1 (local (loop 2 (For (1, int 4, int 5, int 1, write 0 one End, End))));
  check ~bound:1 ~truncated:true 0 (local (loop 1 (loop 2 End)));
  check ~bound:0 0 (local (For (0, int 1, int 2, int 0, End, copies Fun.id)))

(* #316 每轮从 GM 加载一块 tile，在 Vector 管线上读取所选 UB，
   所有迭代共享输出地址。 *)
let issue316 ~wait_ready n =
  Symbolic.instantiate (Race_benchmarks.issue316 ~wait_ready) (Z.of_int n)

let check_pipeline n =
  let p = issue316 ~wait_ready:true n in
  let plan = stream_plan ~loop_bound:n p (List.hd p.streams) in
  let queues = Array.init 2 (fun _ -> Queue.create ()) in
  let put id pipe item = Queue.add (Done { id; pipe; position = 0; item }) queues.(pipe) in
  let issued = List.map (fun (id, action) ->
    (match action with Submit (pipe, item) -> put id pipe item
     | Fence pipes -> List.iter (fun pipe -> put id pipe Bar) pipes | _ -> ());
    Issued (id, action)
  ) plan.actions in
  let reverse = ref [] in
  let finish pipe count = for _ = 1 to count do reverse := Queue.take queues.(pipe) :: !reverse done in
  finish 1 2;
  finish 0 6;
  finish 1 8;
  if n = 3 then (finish 0 3; finish 1 4);
  finish 0 3;
  finish 1 1;
  assert (Array.for_all Queue.is_empty queues);
  let completed = List.rev !reverse in
  replay ~loop_bound:n p (issued @ completed);
  let ops = List.filter_map (function
    | Done { id; pipe; item = Operation (_, fp); _ } -> Some (pipe, id.iterations, fp)
    | _ -> None) completed in
  (match ops with
   | (0, [0], a) :: (0, [1], b) :: (1, [0], exp_a) :: (1, [1], exp_b) :: later ->
       assert (a.writes <> b.writes && exp_a.reads = a.writes && exp_b.reads = b.writes);
       assert (exp_a.writes = exp_b.writes);
       (match n, later with 2, [] -> ()
        | 3, [0, [2], c; 1, [2], exp_c] ->
            assert (c.writes = a.writes && exp_c.reads = a.writes && exp_c.writes = exp_a.writes)
        | _ -> assert false)
   | _ -> assert false);
  List.iter (fun result -> assert (not result.truncated && result.races = []))
    [generate_bug_traces ~loop_bound:n p; generate_bug_traces ~backend:Solve p]

let () =
  let body = Scalar (2, 3, [Var 1], write 0 (Var 2) End) in
  let cmd = read 0 (view [11]) (For (1, int 0, Var 0, int 1, body, End)) in
  let p = program [{ (stream 0 cmd) with params = [0, VInt (Z.of_int 9)] }] in
  let capped = generate_bug_traces ~backend:Solve ~loop_bound:8 p in
  assert (capped.truncated && capped.races = []);
  let full = generate_bug_traces ~backend:Solve p in
  assert (not full.truncated);
  (match full.races with
   | [r] ->
       assert (r.first.iterations = [] && r.second.iterations = [8]);
       assert (r.conflicts = addresses [11])
   | _ -> assert false);
  let directions = validate p full in
  let search = generate_bug_traces ~backend:Search ~loop_bound:9 p in
  let reference = validate ~loop_bound:9 p search in
  assert (not search.truncated && Hashtbl.length reference = 2);
  Hashtbl.iter (fun pair info -> assert (Hashtbl.find directions pair = info)) reference;
  (* 循环终点可以超出机器整数范围。首轮 Return 应立即结束该流。 *)
  let far = Literal (VInt (Z.shift_left Z.one 100)) in
  check ~bound:1 0 (local (For (0, int 0, far, int 1, Return [], write 0 one End)))

let () =
  List.iter check_pipeline [2; 3];
  let p = issue316 ~wait_ready:false 1 in
  List.iter (fun backend ->
    let result = generate_bug_traces ~backend ~loop_bound:1 p in
    ignore (validate ~loop_bound:1 p result);
    match result.races with
    | [r] -> assert (List.length r.conflicts = 1024)
    | _ -> assert false
  ) [Search; Solve]

let symbolic_pipeline = Race_benchmarks.issue316

let () =
  let f = symbolic_pipeline ~wait_ready:false in
  (match find_symbolic_race f with
   | Race {n; witness} ->
       assert (Z.sign n > 0 && List.length witness.conflicts = 1024);
       let p = issue316 ~wait_ready:false (Z.to_int n) in
       ignore (validate p {races = [witness]; truncated = false});
       Printf.printf "#316 without ready wait: N=%s, %d conflicting addresses, witness lengths %d/%d\n"
         (Z.to_string n) (List.length witness.conflicts)
         (List.length witness.first_then_second) (List.length witness.second_then_first)
   | No_race -> failwith "missing UB race" | Unknown reason -> failwith reason);
  match find_symbolic_race (symbolic_pipeline ~wait_ready:true) with
  | No_race -> ()
  | Race _ -> failwith "ordered #316 reported as racing"
  | Unknown reason -> failwith ("#316: " ^ reason)
