open Stdlib
open Unified_interpreter
open Core_lang
module M = Hivm_module

let integer value = match demand value with
  | VInt n -> n | VBool b -> if b then Z.one else Z.zero
  | _ -> invalid_arg "expected an integer operand"

let buffer = function VBuffer b | VTensor (b,_) -> b | _ -> invalid_arg "expected a tensor or memref"

let dimension n =
  if Z.sign n < 0 || not (Z.fits_int n) then invalid_arg "invalid dimension or storage size";
  Z.to_int n

let type_of ast name = match List.assoc_opt name ast.M.mlir_types with
  | Some ty -> ty | None -> invalid_arg ("missing type information for " ^ name)

let shaped ast name = match type_of ast name with
  | M.Shaped ty -> ty | _ -> invalid_arg ("expected a shaped type, got " ^ name)

let element_bytes ast ty = match type_of ast ty.M.element with
  | M.Shaped {kind=Memref;_} -> 8
  | M.Integer bits | M.Float bits when bits > 0 && (bits mod 8 = 0 || bits = 1) -> (bits+7)/8
  | _ -> invalid_arg ("unsupported storage element type " ^ ty.element)

let z = Z.of_int

let strides shape =
  snd (List.fold_right (fun n (size, result) -> Z.mul (z n) size, size :: result)
         shape (Z.one, []))

let constrain_shape expected shape =
  if List.length expected <> List.length shape ||
     not (List.for_all2 (fun known n -> n >= 0 && Option.fold ~none:true ~some:((=) n) known) expected shape)
  then invalid_arg "shape disagrees with the MLIR type";
  shape

let dimensions static dynamic =
  let rest = ref dynamic in
  let shape = List.map (function Some n -> n | None -> match !rest with
    | n::ns -> rest := ns; dimension (integer n)
    | [] -> invalid_arg "missing dynamic dimension") static in
  if !rest <> [] then invalid_arg "extra dynamic dimensions";
  constrain_shape static shape

let size b =
  if List.length b.shape <> List.length b.strides then invalid_arg "stride rank differs from shape";
  if List.mem 0 b.shape then 0 else
    let first, last = List.fold_left2 (fun (lo,hi) length stride ->
      let delta = Z.mul (z (length - 1)) stride in
      Z.add lo (Z.min Z.zero delta), Z.add hi (Z.max Z.zero delta))
      (b.offset, b.offset) b.shape b.strides in
    if Z.sign first < 0 then invalid_arg "view starts before its backing storage";
    dimension (Z.add (z b.base_bytes) (Z.mul (Z.succ last) (z b.element_bytes)))

let validate b =
  let required=size b in
  if required > b.bytes then invalid_arg (Printf.sprintf "view ends at byte %d of a %d-byte allocation" required b.bytes);
  b

let descriptor ast ty =
  let element_bytes=element_bytes ast ty in
  fun shape ?offset ?layout () ->
  let shape = constrain_shape ty.M.shape shape in
  let choose name fixed supplied = match fixed,supplied with
    | Some a,Some b when not (Z.equal a b) -> invalid_arg (name ^ " disagrees with the MLIR type")
    | Some a,_ | None,Some a -> a
    | None,None -> invalid_arg ("missing dynamic " ^ name) in
  let offset,strides = match ty.layout with
    | Identity ->
        let expected = strides shape in
        Option.iter (fun given -> if given<>expected then invalid_arg "expected identity strides") layout;
        choose "offset" (Some Z.zero) offset, expected
    | Strided (fixed, fixed_strides) ->
        let declared = List.map (Option.map z) fixed_strides in
        let strides = match layout with
          | None -> List.map (fun fixed -> choose "stride" fixed None) declared
          | Some given -> List.map2 (fun fixed value -> choose "stride" fixed (Some value)) declared given in
        choose "offset" (Option.map z fixed) offset, strides
    | Opaque_layout -> invalid_arg "unsupported memref layout" in
  {storage=None; bytes=0; base_bytes=0; offset; shape; strides; element_bytes}

let adopt template = function
  | VView cells ->
      let storage = match cells with (storage,0)::_ -> Some storage | [] -> None
        | _ -> invalid_arg "allocation did not start at byte zero" in
      VBuffer (validate {template with storage; bytes=List.length cells})
  | _ -> invalid_arg "expected a reserved allocation"

let at b indices =
  if List.length indices<>List.length b.shape then invalid_arg "unexpected memory index rank";
  if List.exists2 (fun i n -> Z.sign i<0 || Z.geq i (z n)) indices b.shape then
    {b with storage=Some Invalid_address;base_bytes=0;offset=Z.zero;shape=[];strides=[];bytes=b.element_bytes}
  else
  let offset = List.fold_left2 (fun pos index stride ->
    Z.add pos (Z.mul index stride)
  ) b.offset indices b.strides in
  validate {b with offset; shape=[]; strides=[]}

let addresses b =
  let b = validate b in
  match b.storage with
  | None -> if size b=0 then [] else invalid_arg "view has no backing storage"
  | Some _ when List.mem 0 b.shape -> []
  | Some storage ->
      let width = b.element_bytes in
      if b.strides = strides b.shape then
        let base = dimension (Z.add (z b.base_bytes) (Z.mul b.offset (z width))) in
        List.init (size b - base) (fun i -> storage,base+i)
      else
        let rec visit offset acc dims strides = match dims,strides with
          | [],[] ->
              let start = dimension (Z.add (z b.base_bytes) (Z.mul offset (z width))) in
              List.rev_append (List.init width (fun i -> storage,start+i)) acc
          | size::shape,step::strides ->
              let rec next i offset acc =
                if i=size then acc
                else next (i+1) (Z.add offset step) (visit offset acc shape strides) in
              next 0 offset acc
          | _ -> invalid_arg "invalid view rank" in
        List.rev (visit b.offset [] b.shape b.strides)

let subview b ~offsets ~sizes ~steps expected =
  let offset, strides = List.fold_left2 (fun (base,strides) (offset,length,step,dim) stride ->
    Device_value.check_subview_axis ~offset ~length ~step ~dimension:dim;
    Z.add base (Z.mul offset stride), Z.mul step stride :: strides
  ) (b.offset,[]) (List.map2 (fun (offset,size) (step,dim) -> offset,size,step,dim)
                    (List.combine offsets sizes) (List.combine steps b.shape)) b.strides in
  let rec reduce shape target = match shape,target with
    | [],[] -> Some []
    | (size,stride)::rest, expected::tail
      when Option.fold ~none:true ~some:((=) size) expected ->
        (match reduce rest tail with Some kept -> Some ((size,stride)::kept)
         | None when size=1 -> reduce rest target | None -> None)
    | (1,_)::rest,_ -> reduce rest target
    | _ -> None in
  let shape,strides = match reduce (List.combine sizes (List.rev strides)) expected with
    | Some axes -> List.split axes | None -> invalid_arg "unsupported subview rank reduction" in
  validate {b with offset;shape;strides}
