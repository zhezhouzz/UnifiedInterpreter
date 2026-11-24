open Unified_interpreter
open Core_lang
open Bug_traces
open Symbolic

let int n = Literal (VInt (Z.of_int n))
let constant n = Const (VInt (Z.of_int n))
let location = Literal (VView [Input 0, 1])
let read next = Issue (0,0,[location],next)
let write next = Issue (0,1,[location],next)
let stream id body = {id; body; pipes = [0;1]; params = []}
let family streams = {
  streams; parameter = [0,0];
  scalar = (fun _ -> function
    | 0 -> Eq (Arg 0,Arg 1)
    | 1 -> Event (Select (Eq (Arg 0,constant 19),constant 0,constant 1))
    | 2 -> Input_slice (0,Arg 0,constant 1)
    | _ -> invalid_arg "unknown scalar");
  access = (fun _ _ -> function 0 -> [Arg 0],[] | 1 -> [],[Arg 0] | _ -> invalid_arg "unknown access");
  block_edge = (fun s _ u _ -> s <> u)
}

let check_found f check =
  match find_symbolic_race f with
  | Race {n; witness} ->
      let p = instantiate f n in
      let order a b trace =
        replay p trace;
        let target = function
          | Done {id; item = Operation _; _} when id = a || id = b -> Some id
          | _ -> None in
        assert (List.filter_map target trace = [a;b]) in
      order witness.first witness.second witness.first_then_second;
      order witness.second witness.first witness.second_then_first;
      assert (witness.conflicts <> []);
      check n witness
  | No_race -> failwith "expected a symbolic race"
  | Unknown reason -> failwith ("unexpected unknown: " ^ reason)

let safe f = match find_symbolic_race f with
  | No_race -> () | Race _ -> failwith "unexpected symbolic race"
  | Unknown reason -> failwith ("unexpected unknown: " ^ reason)

let () =
  let body = Scalar (2,0,[Var 1; int 16],
    Branch (Var 2,Scalar (3,0,[Var 0; int 17],Branch (Var 3,write End,End,End)),End,End)) in
  let loop body = For (1,int 0,Var 0,int 1,body,End) in
  check_found (family [stream 0 (read (loop body))]) (fun n w ->
    assert (Z.equal n (Z.of_int 17));
    assert (w.first.iterations = [] && w.second.iterations = [16]));
  check_found (family [stream 0 (loop (write End))]) (fun n w ->
    assert (Z.equal n (Z.of_int 2) && w.first.site = w.second.site && w.first.iterations <> w.second.iterations);
    let render = function
      | Issued ({iterations = [i]; _}, Control) -> Printf.sprintf "For(%d)" i
      | Issued ({iterations = [i]; _}, Submit (_,Operation _)) -> Printf.sprintf "Issued(W%d)" i
      | Done {id = {iterations = [i]; _}; position; _} -> Printf.sprintf "Done(W%d,%d)" i position
      | _ -> failwith "unexpected event in shortest write trace" in
    List.iter (fun trace ->
      Printf.printf "N=%s  %s\n" (Z.to_string n) (String.concat " " (List.map render trace))
    ) [w.first_then_second; w.second_then_first]);
  let disjoint = Scalar (2,2,[Var 1],Issue (0,1,[Var 2],End)) in
  safe (family [stream 0 (loop disjoint)]);
  safe (family [stream 0 (loop (write (Barrier (All,End))))]);
  safe (family [stream 0 (loop (write (Return [])))]);
  let after = For (1,int 0,Var 0,int 1,Return [],read (write End)) in
  check_found (family [stream 0 after]) (fun n _ -> assert (Z.equal n Z.zero));
  let send flag next = Sync (BlockSet,0,ScalarEnd,flag,next) in
  let recv next = Sync (BlockWait,0,ScalarEnd,Literal (VEvent 0),next) in
  let sender = Scalar (1,1,[Var 0],send (Var 1) End) in
  check_found (family [stream 0 (For (1,int 0,Var 0,int 1,End,sender));
                       stream 1 (recv (read (write End)))])
    (fun n _ -> assert (Z.equal n (Z.of_int 19)));
  safe (family [stream 0 (write (send (Literal (VEvent 0)) End)); stream 1 (recv (read End))]);
  let fresh = Alloc (2,0,[int 1],Issue (0,1,[Var 2],End)) in
  safe (family [stream 0 (loop fresh)]);
  let outer = For (4,Var 0,int 0,int (-1),For (1,int 0,Var 4,int 1,write End,End),End) in
  check_found (family [stream 0 outer]) (fun n witness ->
    assert (Z.geq n (Z.of_int 2) && List.length witness.first.iterations = 2));
  let shared = { (family [stream 0 (Scalar (1,0,[Var 0; int 3],Branch (Var 1,write End,End,End)));
                          stream 1 (Scalar (2,0,[Var 5; int 4],Branch (Var 2,read End,End,End)))])
                 with parameter = [0,0; 1,5] } in
  safe shared;
  (* 两种输入各允许一个相反顺序；同一输入始终由通知强制排序。 *)
  let notify = send (Literal (VEvent 0)) End in
  let conditional yes no next = Branch (Var 2,yes,no,next) in
  let at_zero body = Scalar (2,0,[Var 0; int 0],body) in
  let opposite_inputs = { (family [
      stream 0 (at_zero (conditional End (recv End) (write (conditional notify End End))));
      stream 1 (at_zero (conditional (recv End) End (read (conditional End notify End))))])
    with parameter = [0,0; 1,0] } in
  List.iter (fun n ->
    let p = instantiate opposite_inputs (Z.of_int n) in
    assert ((generate_bug_traces ~backend:Search ~loop_bound:0 p).races = [])
  ) [0;1];
  safe opposite_inputs;
  (* 一个 key 有两个可能的发送流。来自同一次广播的令牌只能消费一次。 *)
  let event0 = Literal (VEvent 0) in
  let twice = recv (recv (read (write End))) in
  let broadcasts streams = { (family streams) with block_edge = (fun _ _ receiver _ -> receiver = 2) } in
  safe (broadcasts [stream 0 (send event0 End); stream 2 twice]);
  check_found (broadcasts [stream 0 (send event0 End); stream 1 (send event0 End); stream 2 twice])
    (fun n _ -> assert (Z.equal n Z.zero));
  let unsupported = family [stream 0 (Scalar (1,0,[Literal (VFloat 0.); Literal (VFloat 1.)],
    Branch (Var 1,read (write End),End,End)))] in
  (match find_symbolic_race unsupported with Unknown reason -> assert (reason <> "") | _ -> assert false)
