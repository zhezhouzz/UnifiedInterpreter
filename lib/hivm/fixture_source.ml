open Unified_interpreter
open Core_lang
module P = Bug_traces.Symbolic

let buffer = "memref<?xi32, #hivm.address_space<gm>>"
let slot = "memref<1x" ^ buffer ^ ">"
let pipes = [0, Device.V; 1, Device.MTE2]
let pipe p = "PIPE_" ^ Device.pipe_name (List.assoc p pipes)
let shared = function "fixture/shared-allocation" | "fixture/invalid-allocation-offset" -> true | _ -> false
let entry s = "@stream_" ^ string_of_int s
type view = {base:string; offset:string; length:string; indirect:bool}
type value = Number of string | Bool of string | View of view
let number = function Number s -> s | _ -> invalid_arg "expected integer"
let boolean = function Bool s -> s | _ -> invalid_arg "expected boolean"
let view = function View v -> v | _ -> invalid_arg "expected view"

let source name (launch : Race_benchmarks.launch) =
  let out = Buffer.create 4096 and serial = ref 0 and indent = ref 0 in
  let line fmt = Printf.ksprintf (fun s ->
    Buffer.add_string out (String.make (!indent * 2) ' ' ^ s ^ "\n")) fmt in
  let nested f = incr indent; let result = f () in decr indent; result in
  let fresh () = incr serial; "%v" ^ string_of_int !serial in
  let define fmt = Printf.ksprintf (fun expr -> let x = fresh () in line "%s = %s" x expr; x) fmt in
  let integer z = define "arith.constant %s : i128" (Z.to_string z) in
  let constant i = integer (Z.of_int i) in
  let index x = define "arith.index_cast %s : i128 to index" x in
  let helpers = Hashtbl.create 8 in
  let loc site = "loc(\"site" ^ String.concat "" (List.map (Printf.sprintf ".%d") site) ^ "\")" in
  let stream (s : Core_lang.stream) =
    let params = List.filter_map (fun (id,x) -> if id=s.id then Some x else None) launch.family.parameter in
    let abi = ["%mem: " ^ buffer] @ (if shared name then ["%slot: " ^ slot] else [])
      @ List.map (fun x -> Printf.sprintf "%%n%d: i128" x) params in
    line "func.func %s(%s) {" (entry s.id) (String.concat ", " abi);
    nested (fun () ->
      let yes = define "arith.constant true" and no = define "arith.constant false" in
      let literal = function
        | VBool b -> Bool (if b then yes else no)
        | VEvent f -> Number (constant f) | VInt i -> Number (integer i)
        | VView ((bank,first)::tail as cells) ->
            List.iteri (fun i cell -> if cell <> (bank,first+i+1) then invalid_arg "noncontiguous fixture view") tail;
            let base,indirect = match bank with Input 0 -> "%mem",false
              | Allocated {stream=0;site=[];iterations=[]} when shared name -> "%slot",true
              | _ -> invalid_arg "unknown fixture storage" in
            View {base;indirect;offset=constant first;length=constant (List.length cells)}
        | _ -> invalid_arg "unsupported fixture literal" in
      let rec expr args = function
        | P.Arg i -> List.nth args i | Const v -> literal v | Event e -> expr args e
        | Add (a,b) -> Number (define "arith.addi %s, %s : i128" (number (expr args a)) (number (expr args b)))
        | Eq (a,b) -> Bool (define "arith.cmpi eq, %s, %s : i128" (number (expr args a)) (number (expr args b)))
        | Select (c,a,b) -> Number (define "arith.select %s, %s, %s : i128"
              (boolean (expr args c)) (number (expr args a)) (number (expr args b)))
        | Input_slice (0,off,len) -> View {base="%mem";indirect=false;offset=number (expr args off);
                                            length=number (expr args len)}
        | _ -> invalid_arg "unknown fixture scalar expression" in
      let rec block env site cmd =
        let get = function Var x -> List.assoc x env | Literal x -> literal x in
        let next env cmd = block env (site @ [0]) cmd in
        let continue alive branch rest =
          if rest=End then alive
          else if alive=yes then block env (site @ [branch]) rest
          else let result = fresh () in
            line "%s = scf.if %s -> (i1) {" result alive;
            nested (fun () -> let v=block env (site @ [branch]) rest in line "scf.yield %s : i1" v);
            line "} else {"; nested (fun () -> line "scf.yield %s : i1" no); line "}"; result in
        match cmd with
        | End -> yes | Return [] -> no | Return _ -> invalid_arg "unexpected fixture result"
        | Scalar (x,f,vs,rest) -> next ((x,expr (List.map get vs) (launch.family.scalar s.id f))::env) rest
        | Alloc (x,0,[dim],rest) ->
            let len = number (get dim) in
            let size = index len in
            let base = if shared name then (
                Hashtbl.replace helpers ("reserve",false) ();
                define "func.call @reserve(%%slot, %s) : (%s, index) -> %s %s" size slot buffer (loc site))
              else define "memref.alloc(%s) : %s %s" size buffer (loc site) in
            next ((x,View {base;offset=constant 0;length=len;indirect=false})::env) rest
        | Alloc _ -> invalid_arg "unexpected fixture allocation"
        | Issue (p,f,args,rest) ->
            let op = launch.op_name f and views = List.map (fun x -> view (get x)) args in
            (match op,views,launch.family.access s.id p f with
             | "read",[_],([P.Arg 0],[]) | "write",[_],([],[P.Arg 0]) -> ()
             | "copy",[src;dst],([P.Arg 0],[P.Arg 1]) when not src.indirect && not dst.indirect -> ()
             | _ -> invalid_arg ("unsupported fixture footprint for " ^ op));
            let indirect = (List.hd views).indirect in
            if List.exists (fun v -> v.indirect<>indirect) views then invalid_arg "mixed descriptor operands";
            Hashtbl.replace helpers (op,indirect) ();
            let operands = List.concat_map (fun v -> [v.base;index v.offset;index v.length]) views in
            let types = List.concat_map (fun _ -> [if indirect then slot else buffer;"index";"index"]) views in
            line "func.call @%s%s(%s) {hivm.pipe = #hivm.pipe<%s>} : (%s) -> () %s"
              op (if indirect then "_shared" else "") (String.concat ", " operands) (pipe p)
              (String.concat ", " types) (loc site);
            next env rest
        | Barrier (target,rest) ->
            line "hivm.hir.pipe_barrier[<%s>] %s" (match target with All -> "PIPE_ALL" | Pipe p -> pipe p) (loc site);
            next env rest
        | Sync (mode,p,q,flag,rest) ->
            let q = match q with ScalarEnd -> "PIPE_S" | Data q -> pipe q in
            let event = match flag with Literal (VEvent k) -> Either.Left k
              | _ -> Either.Right (define "arith.trunci %s : i128 to i64" (number (get flag))) in
            (match mode with
             | LocalSet | LocalWait ->
                 let flag = match event with Left k -> Printf.sprintf "<EVENT_ID%d>" k | Right v -> v in
                 line "hivm.hir.%s[<%s>, <%s>, %s] %s" (if mode=LocalSet then "set_flag" else "wait_flag")
                   (pipe p) q flag (loc site)
             | BlockSet | BlockWait ->
                 let flag = match event with Left k -> string_of_int k | Right v -> v in
                 line "hivm.hir.%s[<VECTOR>, <%s>, <%s>] flag = %s %s"
                   (if mode=BlockSet then "sync_block_set" else "sync_block_wait") (pipe p) q flag (loc site));
            next env rest
        | Branch (test,a,b,rest) ->
            let result=fresh () in
            line "%s = scf.if %s -> (i1) {" result (boolean (get test));
            let arm i cmd = nested (fun () -> let v=block env (site @ [i]) cmd in line "scf.yield %s : i1" v) in
            arm 0 a; line "} else {"; arm 1 b; line "}"; continue result 2 rest
        | For (x,lo,hi,Literal (VInt step),body,rest) ->
            let lo=number (get lo) and hi=number (get hi) and stride=integer step in
            let result=fresh () and iv=fresh () and alive=fresh () and k=fresh () and live=fresh () in
            line "%s:2 = scf.while (%s = %s, %s = %s) : (i128, i1) -> (i128, i1) {"
              result iv lo alive (if Z.equal step Z.zero then no else yes);
            nested (fun () ->
              let cmp=define "arith.cmpi %s, %s, %s : i128" (if Z.sign step<0 then "sgt" else "slt") iv hi in
              let test=define "arith.andi %s, %s : i1" cmp alive in
              line "scf.condition(%s) %s, %s : i128, i1" test iv alive);
            line "} do {"; line "^bb0(%s: i128, %s: i1):" k live;
            nested (fun () -> let running=block ((x,Number k)::env) (site @ [0]) body in
              let v=define "arith.addi %s, %s : i128" k stride in line "scf.yield %s, %s : i128, i1" v running);
            line "}"; continue (result ^ "#1") 1 rest
        | For _ -> invalid_arg "expected a literal fixture stride" in
      let env=List.map (fun x -> x,Number (Printf.sprintf "%%n%d" x)) params in
      ignore (block env [] s.body); line "return");
    line "}" in
  let helper (op,indirect) =
    if op="reserve" then (
      line "func.func private @reserve(%%slot: %s, %%n: index) -> %s {" slot buffer;
      nested (fun () -> line "%%mem = memref.alloc(%%n) : %s" buffer; line "%%z = arith.constant 0 : index";
        line "memref.store %%mem, %%slot[%%z] : %s" slot; line "return %%mem : %s" buffer); line "}")
    else (
      let ty=if indirect then slot else buffer in
      let dest=if op="copy" then ", %dst: " ^ buffer ^ ", %d: index, %dn: index" else "" in
      line "func.func private @%s%s(%%src: %s, %%s: index, %%n: index%s) {" op
        (if indirect then "_shared" else "") ty dest;
      nested (fun () ->
        line "%%z = arith.constant 0 : index"; line "%%one = arith.constant 1 : index";
        let base=if indirect then define "memref.load %%src[%%z] : %s" slot else "%src" in
        line "scf.for %%j = %%z to %%n step %%one {";
        nested (fun () ->
          let i=define "arith.addi %%s, %%j : index" in
          (match op with
           | "read" -> ignore (define "memref.load %s[%s] : %s" base i buffer)
           | "write" -> let v=define "arith.constant 1 : i32" in line "memref.store %s, %s[%s] : %s" v base i buffer
           | "copy" -> let v=define "memref.load %s[%s] : %s" base i buffer in
               let d=define "arith.addi %%d, %%j : index" in line "memref.store %s, %%dst[%s] : %s" v d buffer
           | _ -> invalid_arg ("unknown fixture operation " ^ op)));
        line "}"; line "return"); line "}") in
  line "module {";
  nested (fun () -> List.iter stream launch.family.streams;
    Hashtbl.to_seq_keys helpers |> List.of_seq |> List.sort compare |> List.iter helper);
  line "}"; Buffer.contents out
