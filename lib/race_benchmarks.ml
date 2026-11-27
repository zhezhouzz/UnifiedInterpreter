open Core_lang
open Historical_lang

type launch = Litao_benchmark.launch
type benchmark = Core of launch | Device of Vectorlayout.variant

let int n = Literal (VInt (Z.of_int n))
let k n = Const (VInt (Z.of_int n))
let flag n = Literal (VEvent n)
let issue316 ~wait_ready =
  let put p q e next = Sync (LocalSet,p,Data q,e,next) in
  let take p q e next = Sync (LocalWait,p,Data q,e,next) in
  let calc = Issue (1,1,[Var 7;Var 3],put 1 0 (Var 6) (Barrier (Pipe 1,End))) in
  let calc = if wait_ready then take 0 1 (Var 6) calc else calc in
  let body = Scalar (5,0,[Var 4],Scalar (6,1,[Var 5],Scalar (7,2,[Var 5;Var 1;Var 2],
    Scalar (8,3,[Var 4],take 1 0 (Var 6) (Issue (0,0,[Var 8;Var 7],put 0 1 (Var 6) calc)))))) in
  let drain = take 1 0 (flag 0) (take 1 0 (flag 1) (Barrier (All,Return []))) in
  let body = Alloc (1,0,[int 1024],Alloc (2,0,[int 1024],put 1 0 (flag 0)
    (put 1 0 (flag 1) (For (4,int 0,Var 0,int 1,body,drain))))) in
  let output = VView (List.init 1024 (fun j -> Input 0,j)) in
  {streams=[{id=0;pipes=[0;1];params=[3,output];body}];parameter=[0,0];
   scalar=(fun _ -> function 0 -> Mod (Arg 0,2) | 1 -> Event (Arg 0)
     | 2 -> Select (Eq (Arg 0,k 0),Arg 1,Arg 2)
     | 3 -> Input_slice (0,Mul (k 1024,Add (Arg 0,k 1)),k 1024)
     | _ -> invalid_arg "#316 scalar");
   access=(fun _ _ _ -> [Arg 0],[Arg 1]);block_edge=(fun _ _ _ _ -> false)}

let regressions =
  let location = Literal (VView [Input 0,1]) in
  let read next = Issue (0,0,[location],next) and write next = Issue (0,1,[location],next) in
  let loop body = For (1,int 0,Var 0,int 1,body,End) in
  let stream id body = {id;body;pipes=[0;1];params=[]} in
  let family streams = {streams;parameter=[0,0];scalar=(fun _ -> function
    | 0 -> Eq (Arg 0,Arg 1) | 1 -> Event (Select (Eq (Arg 0,k 19),k 0,k 1))
    | 2 -> Input_slice (0,Arg 0,k 1) | _ -> invalid_arg "unknown regression scalar");
    access=(fun _ _ -> function 0 -> [Arg 0],[] | 1 -> [],[Arg 0] | _ -> invalid_arg "access");
    block_edge=(fun s _ t _ -> s<>t)} in
  let single body = family [stream 0 body] in
  let send e next = Sync (BlockSet,0,ScalarEnd,e,next) and recv next = Sync (BlockWait,0,ScalarEnd,flag 0,next) in
  let conditional yes no next = Branch (Var 2,yes,no,next) in
  let at_zero body = Scalar (2,0,[Var 0;int 0],body) in
  let twice = recv (recv (read (write End))) in
  let broadcast streams = {(family streams) with block_edge=(fun _ _ receiver _ -> receiver=2)} in
  ["late-branch",17,single (read (loop (Scalar (2,0,[Var 1;int 16],Branch (Var 2,
       Scalar (3,0,[Var 0;int 17],Branch (Var 3,write End,End,End)),End,End)))));
   "repeated-write",2,single (loop (write End));
   "disjoint",3,single (loop (Scalar (2,2,[Var 1],Issue (0,1,[Var 2],End))));
   "barrier",3,single (loop (write (Barrier (All,End))));
   "early-return",3,single (loop (write (Return [])));
   "zero-trip",0,single (For (1,int 0,Var 0,int 1,Return [],read (write End)));
   "flag-expression",19,family [stream 0 (For (1,int 0,Var 0,int 1,End,Scalar (1,1,[Var 0],send (Var 1) End)));
       stream 1 (recv (read (write End)))];
   "handoff",1,family [stream 0 (write (send (flag 0) End));stream 1 (recv (read End))];
   "fresh-allocation",2,single (loop (Alloc (2,0,[int 1],Issue (0,1,[Var 2],End))));
   "nested-descending",2,single (For (4,Var 0,int 0,int (-1),For (1,int 0,Var 4,int 1,write End,End),End));
   "shared-parameter",3,{(family [stream 0 (Scalar (1,0,[Var 0;int 3],Branch (Var 1,write End,End,End)));
       stream 1 (Scalar (2,0,[Var 5;int 4],Branch (Var 2,read End,End,End)))]) with parameter=[0,0;1,5]};
   "opposite-inputs",0,{(family [stream 0 (at_zero (conditional End (recv End) (write (conditional (send (flag 0) End) End End))));
       stream 1 (at_zero (conditional (recv End) End (read (conditional End (send (flag 0) End) End))))]) with parameter=[0,0;1,0]};
   "single-broadcast",0,broadcast [stream 0 (send (flag 0) End);stream 2 twice];
   "two-broadcasts",0,broadcast [stream 0 (send (flag 0) End);stream 1 (send (flag 0) End);stream 2 twice]]

let concrete_fixtures =
  let view xs = Literal (VView (List.map (fun i -> Input 0,i) xs)) in
  let one = view [1] and stream id body = {id;body;pipes=[0;1];params=[]} in
  let read p v rest = Issue (p,1,[v],rest) and write p v rest = Issue (p,2,[v],rest) in
  let copies middle = Issue (0,0,[view [0];one],middle (Issue (0,0,[one;view [2]],End))) in
  let local cmd = [stream 0 cmd] and loop hi body = For (0,int 0,hi,int 1,body,End) in
  let local_signal mode event next = Sync (mode,0,Data 1,flag event,next) in
  let send rest = Sync (BlockSet,0,ScalarEnd,flag 0,rest) in
  let recv rest = Sync (BlockWait,0,ScalarEnd,flag 0,rest) in
  let allocated i = Literal (VView [Allocated {stream=0;site=[];iterations=[]},i]) in
  let use i = stream 1 (write 0 (allocated i) (read 1 (allocated i) End)) in
  let reserve = stream 0 (Alloc (0,0,[int 1],End)) in
  let fixed name streams = name,0,[],streams in
  let variable name n streams = name,n,[0,99],streams in
  let fixtures = [
    fixed "fifo-copy" (local (copies Fun.id));
    fixed "pipe-barrier" (local (copies (fun c -> Barrier (Pipe 0,c))));
    fixed "other-pipe-barrier" (local (copies (fun c -> Barrier (Pipe 1,c))));
    fixed "all-barrier" (local (copies (fun c -> Barrier (All,c))));
    fixed "overlapping-writes" (local (write 0 (view [0;1]) (write 1 (view [1;2]) End)));
    fixed "disjoint-reads-writes" (local (write 0 (view [0]) (read 1 one End)));
    fixed "two-reads" (local (read 0 one (read 1 one End)));
    fixed "three-accesses" (local (write 0 one (write 1 one (read 0 one End))));
    fixed "two-streams" [stream 0 (read 0 one End);stream 1 (write 1 one End)];
    variable "loop-write" 2 (local (loop (Var 99) (write 0 one End)));
    variable "loop-zero" 0 (local (For (0,int 0,Var 99,int 1,End,copies Fun.id)));
    fixed "stride-minus-two" (local (For (0,int 3,int (-1),int (-2),write 0 one End,End)));
    variable "return-from-loop" 3 (local (loop (Var 99) (Return [])));
    variable "blocked-before-loop" 2 (local (recv (loop (Var 99) End)));
    variable "concurrent-loop" 2 [stream 0 (loop (Var 99) (write 0 one End));stream 1 (read 1 one End)];
    fixed "allocation" (local (Alloc (0,0,[int 2],write 0 (Var 0) (read 1 (Var 0) End))));
    variable "loop-allocation" 2 (local (loop (Var 99) (Alloc (0,0,[int 1],write 0 (Var 0) End))));
    fixed "shared-allocation" [reserve;use 0];fixed "invalid-allocation-offset" [reserve;use 1];
    fixed "else-branch" (local (Branch (Literal (VBool false),End,copies Fun.id,End)));
    fixed "duplicate-set" (local (local_signal LocalSet 0 (local_signal LocalSet 0 (copies Fun.id))));
    fixed "local-handoff" (local (write 0 one (local_signal LocalSet 0 (local_signal LocalWait 0 (read 1 one End)))));
    fixed "wrong-flag" (local (local_signal LocalWait 1 (write 0 one (local_signal LocalSet 0 (read 1 one End)))));
    fixed "broadcast" [stream 0 (send End);stream 1 (recv (read 0 one End));stream 2 (recv (write 0 one End))];
    fixed "block-handoff" [stream 0 (write 0 one (send End));stream 1 (recv (read 1 one End))];
    fixed "repeated-broadcast" [stream 0 (send (send End));stream 1 (recv (recv (write 0 one End)));stream 2 (read 1 one End)];
    fixed "block-data-wait" [stream 0 (write 0 one (Sync (BlockSet,0,Data 1,flag 0,End)));
      stream 1 (Sync (BlockWait,0,Data 1,flag 0,read 1 one End))];
    variable "nested-loop" 2 (local (loop (Var 99) (For (1,int 4,int 5,int 1,write 0 one End,End))));
    fixed "zero-step" (local (For (0,int 1,int 2,int 0,End,copies Fun.id)));
    variable "late-address" 9 (local (read 0 (view [11]) (For (1,int 0,Var 99,int 1,
      Scalar (2,0,[Var 1],write 0 (Var 2) End),End))));
    fixed "large-bound-return" (local (For (0,int 0,Literal (VInt (Z.shift_left Z.one 100)),int 1,Return [],write 0 one End)))] in
  List.map (fun (name,n,parameter,streams) ->
    let family = {streams;parameter;scalar=(fun _ _ -> Input_slice (0,Add (k 3,Arg 0),k 1));
      access=(fun _ _ -> function 0 -> [Arg 0],[Arg 1] | 1 -> [Arg 0],[] | 2 -> [],[Arg 0]
        | _ -> invalid_arg "unknown fixture operation");block_edge=(fun s _ t _ -> s<>t)} in
    name,n,family) fixtures

let catalog root =
  let core ?(op_name=(function 0 -> "read" | 1 -> "write" | n -> string_of_int n)) default_n family =
    Core Litao_benchmark.{family;default_n;capacity=1;op_name;unit_name="element";fixture=`Null} in
  let pipeline wait_ready = core ~op_name:(function 0 -> "load" | _ -> "vexp") 3 (issue316 ~wait_ready) in
  let two_loads () =
    let buffer n = Literal (VView [Input n,0]) in
    let load n next = Issue (0,0,[buffer n;buffer 2],next) in
    let body = For (1,int 0,Var 0,int 1,load 0 (load 1 End),End) in
    core ~op_name:(fun _ -> "load") 1
      {streams=[{id=0;pipes=[0];params=[];body}];parameter=[0,0];
       scalar=(fun _ _ -> invalid_arg "two_loads has no scalar primitive");
       access=(fun _ _ _ -> [Arg 0],[Arg 1]);block_edge=(fun _ _ _ _ -> false)} in
  ["fixture/hivm-two-loads",two_loads;
   "issue316/ordered",(fun () -> pipeline true);
   "issue316/missing-ready",(fun () -> pipeline false);
   "vectorlayout/ok",(fun () -> Device Vectorlayout.Ok);
   "vectorlayout/fail",(fun () -> Device Vectorlayout.Fail)] @
  List.map (fun (name,n,f) -> "regression/" ^ name,(fun () -> core n f)) regressions @
  List.map (fun (name,n,f) -> "fixture/" ^ name,(fun () ->
    core ~op_name:(function 0 -> "copy" | 1 -> "read" | _ -> "write") n f)) concrete_fixtures @
  List.concat_map (fun (c : Litao_benchmark.case) -> List.map (fun variant ->
    "litao/" ^ c.name ^ "/" ^ variant,(fun () -> Core (Litao_benchmark.load c variant))) ["buggy";"fixed"])
    (Litao_benchmark.discover root)
