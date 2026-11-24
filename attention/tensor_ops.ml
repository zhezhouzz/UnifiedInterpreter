module E = Extracted_semantics.Unified_semantics
open Numeric

let ( let* ) result continuation =
  match result with E.Ok value -> continuation value | E.Error error -> E.Error error

let size shape =
  List.fold_left (fun total dim ->
    if dim < 0 || (dim <> 0 && total > Sys.max_array_length / dim)
    then invalid_arg "invalid tensor size";
    total * dim) 1 shape

let coordinate shape indices =
  if List.for_all ((<=) 0) indices && E.coordinate_in_bounds indices shape then
    E.Ok (E.linear_coordinate shape indices)
  else E.Error E.InvalidShape

let read value indices =
  let* index = coordinate (E.shape0 value) indices in
  let* elements = E.elements1 value in
  match List.nth elements index with
  | Undefined -> E.Error E.ReadUninitialized
  | cell -> E.Ok cell

let destination_cells value =
  match value with
  | E.EmptyTensor (shape,_) -> Array.make (size shape) Undefined
  | E.DefinedTensor (E.PackTensor (_,_,cells)) -> Array.of_list cells

let insert cell value indices =
  let shape = E.shape0 value in
  let* index = coordinate shape indices in
  let cells = destination_cells value in
  cells.(index) <- cell;
  E.make_value shape (E.element_type value) (Array.to_list cells)

let insert_slice source target offsets sizes strides =
  let shape = E.shape0 target and ty = E.element_type target in
  if not (E.slice_in_bounds shape offsets sizes strides) ||
     E.shape0 source <> sizes || E.element_type source <> ty then
    E.Error E.InvalidShape
  else
    let* source = E.elements1 source in
    let cells = destination_cells target in
    List.iter2 (fun indices cell ->
      let dst = E.slice_coordinate offsets strides indices in
      cells.(E.linear_coordinate shape dst) <- cell) (E.tensor_indices sizes) source;
    E.make_value shape ty (Array.to_list cells)

let operand_type = function
  | E.ScalarOperand (ty,_) -> ty
  | E.TensorOperand value -> E.element_type value

let expand dst ty operand =
  let* cells = E.expand_operand (E.EmptyTensor (E.shape0 dst,ty)) operand in
  E.Ok (Array.of_list cells)

let arange offset strides dst =
  let shape = E.shape0 dst and ty = E.element_type dst in
  if strides = [] || List.length strides <> List.length shape then E.Error E.InvalidShape
  else
    let values = List.map (fun indices ->
      let value = List.fold_left2 (fun base i stride ->
        Int64.add base (Int64.mul (Int64.of_int i) stride)) offset indices strides in
      if is_float ty then Floating (Int64.to_float value)
      else Integer (canonical ty value)) (E.tensor_indices shape) in
    E.make_value shape ty values

let predicate mode comparison =
  match mode with
  | "eq" -> comparison = 0 | "ne" -> comparison <> 0
  | "lt" -> comparison < 0 | "le" -> comparison <= 0
  | "gt" -> comparison > 0 | "ge" -> comparison >= 0
  | _ -> invalid_arg "unsupported vector comparison"

let compare mode lhs rhs dst =
  let ty = operand_type lhs in
  let* a = expand dst ty lhs in
  let* b = expand dst ty rhs in
  let compare a b =
    match a,b with
    | Integer a,Integer b -> predicate mode (Int64.compare a b)
    | _ ->
        let a = as_float a and b = as_float b in
        if Float.is_nan a || Float.is_nan b then mode = "ne"
        else predicate mode (Float.compare a b) in
  let result = Array.map2 (fun a b -> Integer (if compare a b then 1L else 0L)) a b in
  E.make_value (E.shape0 dst) (E.element_type dst) (Array.to_list result)

let select condition lhs rhs dst =
  let ty = E.element_type dst in
  let* mask = expand dst (E.IntegerType (1,E.Signless)) condition in
  let* a = expand dst ty lhs in
  let* b = expand dst ty rhs in
  let result = Array.mapi (fun i active -> if as_int active <> 0L then a.(i) else b.(i)) mask in
  E.make_value (E.shape0 dst) ty (Array.to_list result)

let bitcast source dst =
  let shape = E.shape0 source in
  let ty = E.element_type dst in
  if shape <> E.shape0 dst then E.Error E.InvalidShape
  else
    let* cells = E.elements1 source in
    E.make_value shape ty (List.map (Numeric.bitcast (E.element_type source) ty) cells)
