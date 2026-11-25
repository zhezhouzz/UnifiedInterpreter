open Core_lang
open Parametric_lang

module Json = Yojson.Safe.Util
let field key json = Json.member key json
let string key json = Json.to_string (field key json)
let list key json = Json.to_list (field key json)
let number n = Const (VInt (Z.of_int n))
let a = Arg 0 and b = Arg 1

type case = {name : string; directory : string; launch : Yojson.Safe.t}
let discover root =
  let rec walk dir =
    let file = Filename.concat dir "case.json" in
    if Sys.file_exists file then
      let json = Yojson.Safe.from_file file in
      [{name=string "id" json;directory=dir;launch=field "execution" json}]
    else Sys.readdir dir |> Array.to_list |> List.concat_map (fun name ->
      let path = Filename.concat dir name in if Sys.is_directory path then walk path else []) in
  walk root |> List.sort (fun x y -> String.compare x.name y.name)

let pipe = function
  | "S" -> scalar_pipe | "V" -> 0 | "MTE2" -> 1 | "MTE3" -> 2
  | "FIX" -> 3 | "MTE1" -> 4 | "M" -> 5 | p -> invalid_arg ("unknown pipe " ^ p)

let optional_int default = function `Null -> default | value -> Json.to_int value
let trip_argument = function
  | "double-buffer" -> Some 2 | "zero-trip-alias" | "cross-loop-placement" -> Some 0
  | "add-Ascend910B1" -> Some 6 | _ -> None

type launch = { family : family; default_n : int; capacity : int; op_name : int -> string; unit_name : string;
                fixture : Yojson.Safe.t }

let load case variant =
  let file = Filename.concat case.directory (variant ^ ".program.core") in
  let functions = Yojson.Safe.from_file file and config = case.launch in
  let arguments = field "arguments" config in
  let argument i = if arguments = `Null then `Null else field (string_of_int i) arguments in
  let entry = list "streams" config |> List.map Json.to_string |> Array.of_list in
  let kinds = match field "kinds" config with
    | `Null -> Array.make (Array.length entry) "AIV"
    | j -> Array.of_list (List.map Json.to_string (Json.to_list j)) in
  let tile = optional_int 32 (field "tile" config) in
  let parameter = ref [] and scalars = Hashtbl.create 32 and accesses = Hashtbl.create 8 in
  let register table value = let index = Hashtbl.length table in Hashtbl.add table index value; index in
  let names = Hashtbl.create 8 in
  let access name value = let i=register accesses value in Hashtbl.add names i name;i in
  let stream id name =
    let func = field name functions in
    let names = Hashtbl.create 32 in
    let var value = match Hashtbl.find_opt names value with Some x -> x | None ->
      let x = Hashtbl.length names in Hashtbl.add names value x; x in
    let subblock = Array.to_list (Array.sub kinds 0 id) |> List.filter ((=) "AIV") |> List.length in
    let params = List.mapi (fun i p ->
      let x = var (field "id" p) in
      if trip_argument case.name = Some i then parameter := (id,x) :: !parameter;
      let view bank bytes = VView (List.init bytes (fun j -> Input bank,j)) in
      let value = match argument i,string "type" p with
        | `Int n,_ -> VInt (Z.of_int n)
        | `String "ub:offsets","memref<16xi64, #hivm.address_space<ub>>" -> view (-2) 128
        | `String "ub:mask","memref<16xi8, #hivm.address_space<ub>>" -> view (-3) 16
        | `Null,("i64" | "index" | "i32") -> VInt Z.zero
        | `Null,"memref<?xi8, #hivm.address_space<gm>>" -> view i tile
        | `Null,"memref<?xf32, #hivm.address_space<gm>>" -> view i (tile*4)
        | `Null,"memref<256xf32, #hivm.address_space<gm>>" -> view i 1024
        | `Null,"memref<32xf32, #hivm.address_space<gm>>" -> view i 128
        | `Null,"memref<16xf32, #hivm.address_space<gm>>" -> view i 64
        | `Null,"memref<1xf32, #hivm.address_space<gm>>" -> view i 4
        | _,ty -> invalid_arg ("unsupported argument " ^ ty) in
      x,value) (list "params" func) in
    let rec block commands = List.fold_right command commands End
    and command c rest =
      let args = List.map (fun x -> Var (var x)) (list "args" c) in
      let op = string "cmd" c in
      match op with
      | "return" -> Return args | "end" -> End
      | "if" -> (match args,list "bodies" c with
          | [test],[yes;no] -> Branch (test,block (Json.to_list yes),block (Json.to_list no),rest)
          | _ -> invalid_arg "invalid if")
      | "for" -> (match args,list "bodies" c,list "bindings" c with
          | [lo;hi;step],[body],[`List [`List [x]]] ->
              For (var (field "id" x),lo,hi,step,block (Json.to_list body),rest)
          | _ -> invalid_arg "invalid for")
      | "scalar" ->
          let attrs = field "attrs" c and fn = string "fn" c in
          let expr = match fn with
            | "arith.constant" ->
                let token = List.hd (String.split_on_char ' ' (string "value" attrs)) in
                if list "types" c = [`String "f32"] then Const (VFloat (float_of_string token))
                else Const (VInt (Z.of_string token))
            | "arith.cmpi" -> (match string "predicate" attrs with
                | "0 : i64" -> Eq (a,b) | "2 : i64" -> Lt (a,b) | s -> invalid_arg s)
            | "arith.muli" -> Mul (a,b) | "arith.remsi" -> Remainder (a,b)
            | "arith.trunci" -> Sub (Mod (Add (a,number 2147483648),4294967296),number 2147483648)
            | "arith.index_cast" -> a
            | "arith.select" -> Select (a,b,Arg 2)
            | "hivm.hir.get_block_idx" | "annotation.mark" | "hivm.hir.set_mask_norm" -> number 0
            | "hivm.hir.get_sub_block_idx" -> number (if kinds.(id)="AIV" then subblock else 0)
            | "affine.apply" when string "map" attrs = "affine_map<()[s0, s1] -> (s0 - s1)>" -> Sub (a,b)
            | "affine.max" when string "map" attrs = "affine_map<()[s0, s1] -> (s1, s0)>" -> Select (Lt (a,b),b,a)
            | "affine.min" when string "map" attrs = "affine_map<()[s0, s1] -> (s1 + 256, s0)>" ->
                let limit = Add (b,number 256) in Select (Lt (a,limit),a,limit)
            | "memref.subview" when string "static_offsets" attrs="array<i64: 0>" &&
                string "static_strides" attrs="array<i64: 1>" &&
                string "static_sizes" attrs="array<i64: -9223372036854775808>" ->
                  Subview (a,number 0,Mul (number 4,b))
            | "memref.reinterpret_cast" when string "static_sizes" attrs="array<i64: 256>" &&
                string "static_offsets" attrs="array<i64: -9223372036854775808>" &&
                string "static_strides" attrs="array<i64: 1>" -> Subview (a,Mul (number 4,b),number 1024)
            | "hivm.hir.pointer_cast" ->
                let bank,count = match list "types" c with
                  | [`String "memref<256xf32, #hivm.address_space<cc>>"] -> 101+2*id,256
                  | [`String "memref<256xf32, #hivm.address_space<ub>>"] -> 100+2*id,256
                  | [`String "memref<32xf32, #hivm.address_space<ub>>"] -> 100+2*id,32
                  | [`String "memref<16xf32, #hivm.address_space<ub>>"] -> 100+2*id,16
                  | [`String "memref<1xf32, #hivm.address_space<ub>>"] -> 100+2*id,1
                  | _ -> invalid_arg "unknown pointer type" in
                Input_slice (bank,a,number (4*count))
            | _ -> invalid_arg ("unknown scalar " ^ fn) in
          let x = match list "results" c with [] -> -1 | [x] -> var x | _ -> invalid_arg fn in
          Scalar (x,register scalars expr,args,rest)
      | "issue" ->
          let operands = List.map (fun x -> Arg (Json.to_int x)) (list "read_operands" c) in
          let dst = Arg (Json.to_int (field "write_operand" c)) in
          let writes = match field "gm_rmw_operand" c with
            | `Null -> [dst]
            | `Int i when field "ub:offsets" (field "initial" config) = `String "identity"
                        && field "ub:mask" (field "initial" config) = `Int 1 -> [Arg i;dst]
            | _ -> invalid_arg "unknown indirect addressing fixture" in
          Issue (pipe (string "p" c),access (string "fn" c) (operands,writes),args,rest)
      | "scalarstore" ->
          Issue (scalar_pipe,access "scalarstore" ([],[Subview (b,Mul (number 4,Arg 2),number 4)]),args,rest)
      | "pipebarrier" ->
          Barrier ((match string "p" c with "ALL" -> All | p -> Pipe (pipe p)),rest)
      | "setflag" | "waitflag" | "syncblockset" | "syncblockwait" ->
          let mode = match op with "setflag" -> LocalSet | "waitflag" -> LocalWait
            | "syncblockset" -> BlockSet | _ -> BlockWait in
          let q = match string "q" c with "S" -> ScalarEnd | q -> Data (pipe q) in
          Sync (mode,pipe (string "p" c),q,Literal (VEvent (Json.to_int (field "event" c))),rest)
      | _ -> invalid_arg ("unknown command " ^ op) in
    {id;params;body=block (list "body" func);
     pipes=List.map pipe (if kinds.(id)="AIC" then ["MTE1";"MTE2";"M";"FIX"] else ["MTE2";"V";"MTE3"])} in
  let streams = Array.mapi stream entry |> Array.to_list in
  let block_edge s _ t _ = match field "targets" config with
    | `Assoc targets when List.mem_assoc (string_of_int s) targets ->
        List.mem (`Int t) (Json.to_list (List.assoc (string_of_int s) targets))
    | _ -> kinds.(s) <> kinds.(t) in
  {family={streams;parameter= !parameter;scalar=(fun _ -> Hashtbl.find scalars);
           access=(fun _ _ -> Hashtbl.find accesses);block_edge};
   default_n=Option.fold ~none:0 ~some:(fun i -> Json.to_int (argument i)) (trip_argument case.name);
   capacity=optional_int 1 (field "capacity" config);op_name=Hashtbl.find names;unit_name="byte";
   fixture=`Assoc ["launch",config;"program_digest",`String (Digest.to_hex (Digest.file file))]}
