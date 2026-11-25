open Device_ast
open Device_value

type config = { length : int; dimension : int; group : int; kv_heads : int; splits : int }
let default = {length=160; dimension=128; group=2; kv_heads=1; splits=1}
type input = {
  config : config; blocks : int; memory : memory; bindings : (string * value) list;
}

let pages c = (c.length + 127) / 128
let heads c = c.group * c.kv_heads
let gm memory id = Hashtbl.find memory (Global id)
let checked_size xs = product (Array.of_list xs)

let make config =
  let c = config in
  if c.length < 0 || c.dimension < 1 || c.dimension > 128 ||
     (c.group <> 1 && c.group <> 2) || c.kv_heads < 1 || c.splits < 1 then
    invalid_arg "expected nonnegative length, positive splits and KV heads, dimension 1..128, group 1..2";
  let p = pages c and h = checked_size [c.group;c.kv_heads] in
  let launch = checked_size [c.splits;c.kv_heads] in
  let blocks = min 28 launch in
  let memory = Hashtbl.create (10 + blocks * 4) and bindings = ref [] in
  let bind n value = bindings := ("arg" ^ string_of_int n,value)::!bindings in
  let buffer n ty count =
    let b = Bytes.make (checked_size [count;bits ty / 8]) '\000' in
    Hashtbl.add memory (Global n) b;
    bind n (View {bank=Global n;ty;bit=0;shape=[|count|];strides=[|1|]}); b in
  let query = buffer 2 F16 (checked_size [c.length;h;c.dimension]) in
  for token = 0 to c.length-1 do for head = 0 to h-1 do for k = 0 to c.dimension-1 do
    let x = 1 + (token*3 + head*5 + k) mod 7 in
    Bytes.set_uint16_le query (2*((token*h+head)*c.dimension+k)) (Int64.to_int (half_bits (float x)))
  done done done;
  let keys = buffer 3 F16 (checked_size [p;128;c.kv_heads;c.dimension]) in
  let table = buffer 4 I32 p in
  for page = 0 to p-1 do
    let physical = p-1-page in
    Bytes.set_int32_le table (4*page) (Int32.of_int physical);
    for token = 0 to 127 do for head = 0 to c.kv_heads-1 do for k = 0 to c.dimension-1 do
      let x = 1 + (page + token*2 + head*3 + k*5) mod 11 in
      let index = ((physical*128+token)*c.kv_heads+head)*c.dimension+k in
      Bytes.set_uint16_le keys (2*index) (Int64.to_int (half_bits (float x)))
    done done done
  done;
  List.iter (fun (n,x) -> Bytes.set_int32_le (buffer n I32 1) 0 (Int32.of_int x))
    [5,0;6,(c.length-1)/32;7,c.length;8,c.length];
  let out = buffer 9 F32 (checked_size [c.length;h;p]) in
  for i = 0 to Bytes.length out / 4 - 1 do Bytes.set_int32_le out (4*i) (Int32.bits_of_float 12345.) done;
  List.iter (fun (n,x) -> bind n (scalar I32 (Int64.of_int x)))
    [12,c.group;13,c.dimension;14,1;15,c.splits;17,h*c.dimension;18,c.dimension;
     19,128*c.kv_heads*c.dimension;20,c.kv_heads*c.dimension;21,c.dimension;22,p;
     23,p;24,h*p;25,c.splits;26,c.kv_heads;27,1];
  bind 16 (scalar F32 (encode F32 0.125));
  for block = 0 to blocks-1 do
    List.iter (fun sub -> Hashtbl.add memory (Unified {block;core=Vector sub}) (Bytes.make 157760 '\000')) [0;1];
    Hashtbl.add memory (Cbuf block) (Bytes.make 65536 '\000');
    Hashtbl.add memory (Matrix_a block) (Bytes.make 16384 '\000');
    Hashtbl.add memory (Matrix_b block) (Bytes.make 32768 '\000');
    Hashtbl.add memory (Acc block) (Bytes.make 32768 '\000')
  done;
  {config;blocks;memory;bindings= !bindings}

(* 两个归档入口均保留四个未引用的 ABI 形参。给解释器完整的 28 个实参。 *)
let hivm_arguments input =
  let memory = Hashtbl.copy input.memory in
  let empty n =
    Hashtbl.add memory (Global n) Bytes.empty;
    "arg" ^ string_of_int n,View {bank=Global n;ty=I8;bit=0;shape=[|0|];strides=[|1|]} in
  let unused = [empty 0;empty 1;"arg10",scalar I32 0L;"arg11",scalar I32 0L] in
  {input with memory;bindings=unused @ input.bindings}

let make_hivm config = hivm_arguments (make config)

let run ?schedule variant input =
  Device_run.run ?schedule (Vectorlayout.make variant input.blocks) input.memory input.bindings

let output input (result : Device_run.result) =
  let c = input.config and data = gm result.memory 9 in
  {Tensor.dims=[c.length;heads c;pages c];
   data=Array.init (Bytes.length data / 4) (fun i -> Int32.float_of_bits (Bytes.get_int32_le data (4*i)))}

(* 由实际存储和随后的 gather 事件取得同一行列的证据。 *)
let first_missed_lane (result : Device_run.result) =
  let rec find = function
    | [] -> None
    | (e : Device_run.event)::rest ->
        match Option.bind e.observation (fun o -> o.evidence) with
        | Some (Device_eval.Packed s) ->
            let n = Array.length s.predicate.lanes in
            let rec first i =
              if i >= n then None else if s.predicate.lanes.(i) <> 0L then Some i else first (i+1) in
            (match first s.capacity with
             | None -> find rest
             | Some i ->
                 let row = s.origin.(0) and col = s.origin.(1)+i in
                 let sample = List.find_map (fun (next : Device_run.event) ->
                   if next.stream <> e.stream then None else
                   match Option.bind next.observation (fun o -> o.evidence) with
                   | Some (Device_eval.Gather (dst,samples)) -> Some (dst,samples.(row*dst.shape.(1)+col))
                   | _ -> None) rest in
                 Option.map (fun (dst,read) -> e.stream,s.destination,row,col,dst,read) sample)
        | _ -> find rest in
  find result.events

(* 按 tensor 层的下标直接读取 GM，计算每一页的 causal maximum。 *)
let reference input =
  let memory = input.memory and c = input.config in
  let word n i = Int32.to_int (Bytes.get_int32_le (gm memory n) (4*i)) in
  let elem buf i = half_float (Bytes.get_uint16_le buf (2*i)) in
  let param n = List.assoc ("arg" ^ string_of_int n) input.bindings in
  let stride n = integer (param n) in
  let f32 x = Int32.float_of_bits (Int32.bits_of_float x) in
  let scale = f32 (decode F32 (single (reg (param 16))) *. f32 1.44269502) in
  let query = gm memory 2 and keys = gm memory 3 and out = Bytes.copy (gm memory 9) in
  let q0 = word 5 0 + 32 * word 6 0 and kvlen = word 7 0 in
  for q = q0 to min (q0+31) (word 8 0-1) do
    for head = 0 to heads c-1 do
      for page = 0 to (kvlen+127)/128-1 do
        let maximum = ref neg_infinity in
        for j = page*128 to min (min (page*128+127) (kvlen-1)) q do
          let a = q * stride 17 + head * stride 18 in
          let b = word 4 page * stride 19 + (j mod 128) * stride 20 + (head/c.group) * stride 21 in
          let sum = ref 0. in
          for k = 0 to c.dimension-1 do
            sum := f32 (!sum +. elem query (a+k) *. elem keys (b+k))
          done;
          let score = f32 (!sum *. scale) in
          if not (Float.is_nan score) then maximum := Float.max !maximum score
        done;
        Bytes.set_int32_le out (4*(q*stride 24 + head*stride 23 + page)) (Int32.bits_of_float !maximum)
      done
    done
  done;
  out

type difference = { token : int; head : int; page : int; actual : float; expected : float }
let differences config expected actual =
  if Bytes.length expected <> Bytes.length actual then invalid_arg "output size differs";
  let p = pages config and h = heads config in
  let count = ref 0 and first = ref None in
  for i = 0 to Bytes.length expected / 4 - 1 do
    let x = Bytes.get_int32_le actual (4*i) and y = Bytes.get_int32_le expected (4*i) in
    if x <> y then begin
      incr count;
      if !first = None then first := Some {token=i/(h*p);head=i/p mod h;page=i mod p;
        actual=Int32.float_of_bits x;expected=Int32.float_of_bits y}
    end
  done;
  !count,!first
