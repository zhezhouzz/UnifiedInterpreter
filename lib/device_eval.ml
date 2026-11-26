open Device_ast
open Device_value

type access = { bank : bank; first : int; limit : int }
type packed = {
  destination : view; origin : int array; source_layout : layout; predicate : vector;
  packing : packing; registers : int; capacity : int;
}
type gathered = { source : bank; source_bit : int; raw : int64 }
exception Invalid_indirect_address of int
type evidence = Packed of packed | Gather of view * gathered array
type observation = { operation : string; reads : access list; writes : access list;
                     possible_reads : access list; possible_writes : access list;
                     masks : access list; offsets : access list; indexed : access list;
                     detail : string; evidence : evidence option }
type context = {
  loc : location; memory : memory; register_bytes : int; counters : (string,int) Hashtbl.t;
  control : (int,bool) Hashtbl.t; mutable reads : access list; mutable writes : access list;
  mutable observe : observation -> unit;
}
let add_access intervals bank first width =
  match intervals with
  | x :: rest when x.bank = bank && first <= x.limit && first + width >= x.first ->
      {bank; first = min first x.first; limit = max (first + width) x.limit} :: rest
  | _ -> {bank; first; limit = first + width} :: intervals

let ranges xs =
  let sorted = List.sort (fun a b -> match compare a.bank b.bank with
    | 0 -> Int.compare a.first b.first | order -> order) xs in
  List.rev (List.fold_left (fun acc x -> add_access acc x.bank x.first (x.limit-x.first)) [] sorted)

let record ?evidence ?(possible_reads=[]) ?(possible_writes=[]) ?(masks=[]) ?(offsets=[]) ?(indexed=[]) c operation detail =
  c.observe {operation; detail; evidence; reads = ranges c.reads; writes = ranges c.writes;
             possible_reads;possible_writes;masks;offsets;indexed};
  c.reads <- []; c.writes <- []
let flush c operation = if c.reads <> [] || c.writes <> [] then record c operation ""
let read c v ix =
  let a = index v ix in
  c.reads <- add_access c.reads v.bank a (bits v.ty);
  read_bits c.memory v a
let write c v ix x =
  let a = index v ix in
  c.writes <- add_access c.writes v.bank a (bits v.ty);
  write_bits c.memory v a x

let size v = product v.shape

let extent v = if size v = 0 then [] else
  [{bank=v.bank;first=v.bit;limit=index v (Array.map (fun n -> n-1) v.shape) + bits v.ty}]

let tensor_index t at =
  if Array.length t.dimensions <> Array.length at then invalid_arg "tensor coordinate rank";
  let index = ref 0 in
  Array.iteri (fun axis i ->
    let extent = t.dimensions.(axis) in
    if i<0 || i>=extent then invalid_arg "tensor coordinate out of bounds";
    index := plus (times !index extent) i) at;
  !index

let tensor_cell t at = match t.cells.(tensor_index t at) with
  | Some value -> value | None -> invalid_arg "read of an uninitialized tensor element"

let shaped_value = function
  | View v -> v.ty,v.shape | Tensor t -> t.element,t.dimensions
  | Reg _ -> invalid_arg "expected a shaped operand"

let element c value at = match value with
  | View v -> read c v at
  | Tensor t -> tensor_cell t at
  | Reg r -> single r

let storage_extent = function View v -> extent v | Tensor _ | Reg _ -> []

let indexed_address v raw =
  let pos = host_int raw in
  if Array.length v.shape<>1 then invalid_arg "indexed buffer must have rank one";
  if pos<0 || pos>=v.shape.(0) then raise (Invalid_indirect_address pos);
  [|pos|]

let rec eval c env expr =
  let ev = eval c env in
  let number e = integer (ev e) and vector e = reg (ev e) in
  let indices xs = Array.of_list (List.map number xs) in
  let geometry dimensions steps =
    let shape = indices dimensions in
    ignore (product shape);
    let strides = if steps = [] then contiguous shape else indices steps in
    if Array.length shape <> Array.length strides || Array.exists ((>) 0) strides then
      invalid_arg "invalid strides";
    shape,strides in
  match expr with
  | Var x -> (match List.assoc_opt x env with Some v -> v | None -> invalid_arg ("unbound " ^ x))
  | Int (ty,n) -> if is_float ty then invalid_arg "integer literal type" else scalar ty n
  | Float (ty,f) -> scalar ty (encode ty f)
  | Block -> scalar I32 (Int64.of_int c.loc.block)
  | Subblock -> (match c.loc.core with Cube -> invalid_arg "cube has no vector subblock"
    | Vector n -> scalar I32 (Int64.of_int n))
  | Counter key ->
      let n = Option.value ~default:0 (Hashtbl.find_opt c.counters key) in
      scalar I64 (Int64.of_int n)
  | Range (start,n) ->
      let r = vector start in
      let x = single r in
      vec r.layout.element (Array.init n (fun i -> truncate r.layout.element (Int64.add x (Int64.of_int i))))
  | Broadcast (e,n) -> let r = vector e in Reg {r with lanes = Array.make n (single r)}
  | Splat_lane (e,i,n) -> let r = vector e in Reg {r with lanes = Array.make n r.lanes.(i)}
  | Binary (op,a,b) -> let a = vector a in binary op a (vector b)
  | Compare (op,a,b) -> let a = vector a in compare_lanes op a (vector b)
  | Select (p,a,b) ->
      let p = vector p in
      if p.layout.element <> I1 then invalid_arg "select predicate";
      (match ev a,ev b with
       | (View _ as a),(View _ as b) -> if single p<>0L then a else b
       | Reg a,Reg b ->
           ignore (same a b);
           Reg {(wider a b) with lanes=Array.init (common_width [p;a;b])
             (fun i -> lane (if lane p i <> 0L then a else b) i)}
       | _ -> invalid_arg "select operands differ")
  | Cast (ty,e) -> cast ty (vector e)
  | Bitcast (ty,e) ->
      let r = vector e in
      if bits r.layout.element <> bits ty then invalid_arg "bitcast element width";
      Reg {r with layout = {r.layout with element = ty}}
  | Layout_cast (layout,e) ->
      let r = vector e in
      if layout.element <> r.layout.element || layout.lane_bits < bits layout.element
      then invalid_arg "invalid vector layout";
      Reg {r with layout}
  | Register_group (registers,e) ->
      if registers <= 0 then invalid_arg "empty register group";
      Reg {(vector e) with registers}
  | Pge n -> vec I1 (Array.make n 1L)
  | Plt (n,limit) -> let limit = number limit in
      vec I1 (Array.init n (fun i -> if i < limit then 1L else 0L))
  | Reduce_max e ->
      let r = vector e in
      let maximum a b =
        if is_float r.layout.element then encode r.layout.element
          (Float.max (decode r.layout.element a) (decode r.layout.element b))
        else if signed r.layout.element a >= signed r.layout.element b then a else b in
      scalar r.layout.element (Array.fold_left maximum r.lanes.(0) r.lanes)
  | Buffer (space,ty,byte,dimensions,steps) ->
      let bank = match space with GM i -> Global i | UB -> Unified c.loc
        | Vector_ub i -> Unified {c.loc with core = Vector i} | L1 -> Cbuf c.loc.block
        | L0A -> Matrix_a c.loc.block | L0B -> Matrix_b c.loc.block | L0C -> Acc c.loc.block in
      let shape,strides = geometry dimensions steps in
      View {bank; ty; bit = times 8 (number byte); shape; strides}
  | Strided_view (base,offset,dimensions,steps) ->
      let v = view (ev base) in
      let shape,strides = geometry dimensions steps in
      View {v with bit=plus v.bit (times (number offset) (bits v.ty));shape;strides}
  | Reinterpret_view (base,offset,dimensions,steps) ->
      let v = view (ev base) in
      let shape,strides = geometry dimensions steps in
      View {v with bit=times (number offset) (bits v.ty);shape;strides}
  | Slice (e,starts,sizes,steps) ->
      let v = view (ev e) in
      let off = indices starts and shape = indices sizes and step = indices steps in
      if Array.length off <> Array.length v.shape || Array.length off <> Array.length shape
         || Array.length shape <> Array.length step then invalid_arg "slice rank";
      let bit = ref v.bit in
      let strides = Array.mapi (fun i stride ->
        if off.(i) < 0 || shape.(i) < 0 || step.(i) <= 0 ||
           (shape.(i) > 0 && plus off.(i) (times (shape.(i)-1) step.(i)) >= v.shape.(i))
        then invalid_arg "slice extent";
        bit := plus !bit (times (times off.(i) stride) (bits v.ty));
        times stride step.(i)) v.strides in
      View {v with bit = !bit; shape; strides}
  | Reshape (e,dims) ->
      let v = view (ev e) and shape = indices dims in
      let source = contiguous v.shape in
      if Array.exists2 (fun (n,s) d -> n > 1 && s <> d) (Array.combine v.shape v.strides) source
        || product v.shape <> product shape then invalid_arg "non-contiguous reshape";
      View {v with shape; strides = contiguous shape}
  | Read (e,ix,n) ->
      let v = view (ev e) and ix = indices ix in
      if Array.length ix=0 && n=1 then scalar v.ty (read c v ix)
      else
        let last = Array.length ix - 1 in
        let start = ix.(last) in
        vec v.ty (Array.init n (fun i -> ix.(last) <- start+i; read c v ix))
  | Empty_tensor (element,dims) ->
      let dimensions = indices dims in
      Tensor {element;dimensions;cells=Array.make (product dimensions) None}
  | Tensor_fill (value,shape) ->
      let scalar = vector value and template = tensor (ev shape) in
      if scalar.layout.element<>template.element then invalid_arg "tensor fill type";
      Tensor {template with cells=Array.make (Array.length template.cells) (Some (single scalar))}
  | Tensor_range (origin,steps,shape) ->
      let template = tensor (ev shape) in
      let as_int64 e = let r = vector e in
        if is_float r.layout.element then invalid_arg "expected an integer range bound";
        signed r.layout.element (single r) in
      let start = as_int64 origin and steps = List.map as_int64 steps in
      if is_float template.element || List.length steps<>Array.length template.dimensions then
        invalid_arg "invalid tensor range";
      let cells = Array.mapi (fun i _ ->
        let coord = Array.to_list (coords template.dimensions i) in
        let raw = List.fold_left2 (fun x scale coord ->
          Int64.add x (Int64.mul scale (Int64.of_int coord))) start steps coord in
        Some (truncate template.element raw)) template.cells in
      Tensor {template with cells}
  | Tensor_compare (pred,left,right,shape) ->
      let left = ev left and right = ev right and template = tensor (ev shape) in
      if template.element<>I1 then invalid_arg "expected a tensor of predicates";
      let lanes v = match v with
        | Reg r -> r
        | Tensor _ ->
            let ty,dimensions = shaped_value v in
            if dimensions<>template.dimensions then invalid_arg "comparison shape mismatch";
            let cells = Array.init (product dimensions) (fun i -> element c v (coords dimensions i)) in
            reg (vec ty cells)
        | View _ -> invalid_arg "tensor comparison requires SSA values" in
      if Array.length template.cells=0 then Tensor template else
        let compare = reg (compare_lanes pred (lanes left) (lanes right)) in
        let cells = Array.init (product template.dimensions) (fun i -> Some (lane compare i)) in
        Tensor {template with cells}
  | Tensor_get (source,at) ->
      let t = tensor (ev source) in
      scalar t.element (tensor_cell t (indices at))
  | Tensor_insert (value,at,source) ->
      let t = tensor (ev source) and value = vector value in
      if t.element<>value.layout.element then invalid_arg "tensor insert type";
      let cells = Array.copy t.cells in
      cells.(tensor_index t (indices at)) <- Some (single value);
      Tensor {t with cells}
  | Gather_tensor (source,offsets,mask,other,shape) ->
      let src = view (ev source) and offsets = ev offsets and mask = ev mask
      and other = ev other and t = tensor (ev shape) in
      let offset_ty,offset_shape = shaped_value offsets and mask_ty,mask_shape = shaped_value mask
      and other_ty,other_shape = shaped_value other in
      if src.ty<>t.element || offset_ty<>I64 || not (List.mem mask_ty [I1;I8]) || other_ty<>t.element ||
         List.exists ((<>) t.dimensions) [offset_shape;mask_shape;other_shape]
      then invalid_arg "indirect tensor load types";
      let cells = Array.mapi (fun i _ ->
        let at = coords t.dimensions i in
        Some (if element c mask at=0L then element c other at
              else read c src (indexed_address src (element c offsets at)))) t.cells in
      record ~possible_reads:(extent src @ List.concat_map storage_extent [offsets;mask;other])
        ~masks:(storage_extent mask) ~offsets:(storage_extent offsets) ~indexed:(extent src) c "indirect_load" "";
      Tensor {t with cells}

let memory_op c env op =
  let ev = eval c env in
  let buf x = view (ev x) and vec x = reg (ev x) in
  let store dst ix data pred pack =
    let dst = buf dst and data = vec data in
    let coord = Array.of_list (List.map (fun e -> integer (ev e)) ix) in
    let length = Array.length data.lanes in
    let enabled, count, evidence = match pred,pack with
      | None,None -> (fun _ -> true), length, None
      | Some p, Some mode ->
          let p = vec p in
          if p.layout.element <> I1 || Array.length p.lanes <> length then invalid_arg "store predicate";
          let scale = match mode with Norm -> 1 | Pk -> 2 | Pk4 -> 4 in
          if data.layout.lane_bits <> bits dst.ty * scale then invalid_arg "store packing and layout disagree";
          if times p.layout.lane_bits data.registers <> data.layout.lane_bits then invalid_arg "store predicate granularity";
          let capacity = times (times c.register_bytes 8) data.registers / data.layout.lane_bits in
          (fun i -> p.lanes.(i) <> 0L), min capacity length,
          Some (Packed {destination=dst;origin=Array.copy coord;source_layout=data.layout;
                        predicate=p;packing=mode;registers=data.registers;capacity})
      | _ -> assert false in
    if data.layout.element <> dst.ty then invalid_arg "store element type";
    if Array.length coord=0 && count=1 then (
      if enabled 0 then write c dst coord data.lanes.(0))
    else (
      let last = Array.length coord - 1 in
      let base = coord.(last) in
      for i = 0 to count-1 do if enabled i then (
        coord.(last) <- base+i; write c dst coord data.lanes.(i)) done);
    record ?evidence c (if Option.is_some pack then "masked_store" else "store") "" in
  let each v f = for i = 0 to size v - 1 do f (coords v.shape i) done in
  let nz row col = [|col / 16;row / 16;row mod 16;col mod 16|] in
  match op with
  | Store (d,i,x) -> store d i x None None
  | Masked_store (d,i,p,x,mode) -> store d i x (Some p) (Some mode)
  | Fill (d,e) -> let d = buf d and r = vec e in
      if d.ty <> r.layout.element then invalid_arg "fill type";
      let x = single r in each d (fun ix -> write c d ix x); record c "vbrc" ""
  | Copy (a,b) | Copy_tensor (a,b) ->
      let a = ev a and b = buf b in
      (match op with Copy_tensor _ -> ignore (tensor a) | _ -> ignore (view a));
      let ty,shape = shaped_value a in
      if shape <> b.shape || ty <> b.ty then invalid_arg "copy shape or type";
      let data = Array.init (product shape) (fun i -> element c a (coords shape i)) in
      Array.iteri (fun i x -> write c b (coords b.shape i) x) data; record c "copy" ""
  | Indirect_load (s,o,m,f,d) ->
      let src = buf s and offsets = buf o and mask = buf m and other = buf f and dst = buf d in
      if offsets.shape <> dst.shape || mask.shape <> dst.shape || other.shape <> dst.shape ||
        src.ty <> dst.ty || other.ty <> dst.ty || offsets.ty <> I64 || not (List.mem mask.ty [I1;I8])
      then invalid_arg "indirect_load types";
      let reads = Array.init (size dst) (fun i ->
        let ix = coords dst.shape i in
        let from,pos = if read c mask ix = 0L then other,ix else
          src,indexed_address src (read c offsets ix) in
        let raw = read c from pos in
        write c dst ix raw; {source=from.bank;source_bit=index from pos;raw}) in
      record ~evidence:(Gather (dst,reads)) ~possible_reads:(List.concat_map extent [src;offsets;mask;other])
        ~masks:(extent mask) ~offsets:(extent offsets) ~indexed:(extent src) c "indirect_load" ""
  | Indirect_store (s,o,m,d) | Scatter_tensor (s,o,m,d) ->
      let src = ev s and offsets = ev o and mask = ev m and dst = buf d in
      (match op with Scatter_tensor _ -> ignore (tensor src) | _ -> ());
      let ty,shape = shaped_value src and index_ty,index_shape = shaped_value offsets
      and mask_ty,mask_shape = shaped_value mask in
      if shape <> index_shape || shape <> mask_shape || ty <> dst.ty ||
        index_ty <> I64 || not (List.mem mask_ty [I1;I8]) then invalid_arg "indirect_store types";
      for i = 0 to product shape - 1 do
        let ix = coords shape i in
        if element c mask ix <> 0L then
          write c dst (indexed_address dst (element c offsets ix)) (element c src ix)
      done;
      record ~possible_reads:(List.concat_map storage_extent [src;offsets;mask]) ~possible_writes:(extent dst)
        ~masks:(storage_extent mask) ~offsets:(storage_extent offsets) ~indexed:(extent dst) c "indirect_store" ""
  | Nd2nz (s,d) ->
      let src = buf s and dst = buf d in
      if Array.length src.shape <> 2 || src.ty <> dst.ty then invalid_arg "nd2nz";
      each src (fun ix -> write c dst (nz ix.(0) ix.(1)) (read c src ix));
      record c "nd2nz" ""
  | Mmad (a,b,d,init,m,k,n,bt) ->
      let a = buf a and b = buf b and dst = buf d and init = truth (ev init) in
      if a.ty <> F16 || b.ty <> F16 || dst.ty <> F32 then invalid_arg "mmad types";
      let left = Array.init m (fun i -> Array.init k (fun j -> decode F16 (read c a (nz i j)))) in
      let right = Array.init n (fun j -> Array.init k (fun i ->
        decode F16 (read c b (if bt then nz j i else nz i j)))) in
      for i = 0 to m-1 do for j = 0 to n-1 do
        let ij = nz i j in
        let sum = ref (if init then 0. else decode F32 (read c dst ij)) in
        for h = 0 to k-1 do
          sum := Int32.float_of_bits (Int32.bits_of_float (!sum +. left.(i).(h) *. right.(j).(h)))
        done;
        write c dst ij (encode F32 !sum)
      done done; record c "mmadL1" ""
  | Fixpipe_row_split (s,d0,d1) ->
      let src = buf s and dest = [|buf d0; buf d1|] in
      Array.iteri (fun sub dst ->
        if dst.ty <> F32 || src.ty <> F32 then invalid_arg "fixpipe type";
        each dst (fun ix -> write c dst ix (read c src (nz (sub * dst.shape.(0) + ix.(0)) ix.(1))))) dest;
      record c "fixpipe" "nz2nd ROW_SPLIT"
  | _ -> invalid_arg "expected a memory operation"
