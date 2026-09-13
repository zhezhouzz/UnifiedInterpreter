(* Tiny tensor store used by examples, handlers, and reports. *)

type t = { dims : int list; data : float array }

  let product = List.fold_left ( * ) 1

  let create dims fill = { dims; data = Array.make (product dims) fill }

  let zeros dims = create dims 0.0

  let of_array1 xs = { dims = [ Array.length xs ]; data = Array.copy xs }

  let of_array2 rows =
    let m = Array.length rows in
    let n = if m = 0 then 0 else Array.length rows.(0) in
    let data = Array.make (m * n) 0.0 in
    Array.iteri
      (fun i row ->
        if Array.length row <> n then invalid_arg "ragged matrix";
        Array.iteri (fun j x -> data.((i * n) + j) <- x) row)
      rows;
    { dims = [ m; n ]; data }

  let copy t = { dims = t.dims; data = Array.copy t.data }

  let rec offset dims idxs =
    match (dims, idxs) with
    | [], [] -> 0
    | d :: ds, i :: is ->
        if i < 0 || i >= d then invalid_arg "index out of bounds";
        (i * product ds) + offset ds is
    | _ -> invalid_arg "rank mismatch"

let get t idxs = t.data.(offset t.dims idxs)

let set t idxs value = t.data.(offset t.dims idxs) <- value

let get_linear t offset =
  if offset < 0 || offset >= Array.length t.data then
    invalid_arg "linear tensor offset out of bounds";
  t.data.(offset)

let set_linear t offset value =
  if offset < 0 || offset >= Array.length t.data then
    invalid_arg "linear tensor offset out of bounds";
  t.data.(offset) <- value

  let max_abs_diff a b =
    if a.dims <> b.dims then infinity
    else
      let acc = ref 0.0 in
      Array.iteri
        (fun i x -> acc := Float.max !acc (Float.abs (x -. b.data.(i))))
        a.data;
      !acc

  let equal ?(tol = 1e-5) a b = max_abs_diff a b <= tol

  let pp_dims dims = "[" ^ String.concat "," (List.map string_of_int dims) ^ "]"

  let pp_index idx = "[" ^ String.concat "," (List.map string_of_int idx) ^ "]"

  let pp t =
    match t.dims with
    | [ n ] ->
        "  ["
        ^ String.concat " "
            (List.init n (fun i -> Printf.sprintf "%8.4f" (get t [ i ])))
        ^ " ]"
    | [ m; n ] ->
        List.init m (fun i ->
            "  ["
            ^ String.concat " "
                (List.init n (fun j -> Printf.sprintf "%8.4f" (get t [ i; j ])))
            ^ " ]")
        |> String.concat "\n"
    | _ -> "<tensor " ^ pp_dims t.dims ^ ">"
