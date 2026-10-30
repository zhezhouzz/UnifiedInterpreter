open Parser
module E = Extracted_semantics.Unified_semantics

type t = {
  ffts : string option;
  sync_lock : string; workspace : string;
  q : string; k : string; v : string; lse : string; o : string; scratch : string;
  lse_type : E.mlir_type; o_type : E.mlir_type;
  scale : string; grid_x : string; grid_y : string; grid_z : string;
  pid_x : string; pid_y : string; pid_z : string;
}

let parse p =
  let mem ty = ShapedType ("memref", [-1], ty) in
  let scalar ty = ScalarType ty in
  let i8 = scalar_type "i8" and i32 = scalar_type "i32" and i64 = scalar_type "i64" in
  let take role expected (name, ty) =
    if ty <> expected then invalid_arg ("unsupported attention type for " ^ role);
    name in
  let ffts, args = match p.arguments with
    | (name, ScalarType ty) :: rest when ty = i64 -> Some name, rest
    | args -> None, args in
  let names = List.map fst p.arguments in
  if List.length names <> List.length (List.sort_uniq String.compare names) then
    invalid_arg "duplicate attention entry argument";
  match args with
  | [lock; workspace; q; k; v; lse; o; scratch; scale;
     gx; gy; gz; px; py; pz] ->
      let lse_type, o_type = match snd lse, snd o with
        | ShapedType ("memref", [-1], lt), ShapedType ("memref", [-1], ot)
          when (lt = E.Float32Type && ot = E.Float16Type) ||
               (lt = E.Float16Type && ot = E.Float32Type) -> lt, ot
        | _ -> invalid_arg "unsupported attention LSE/O types" in
      let abi = {
        ffts; sync_lock=take "sync_lock" (mem i8) lock;
        workspace=take "workspace" (mem i8) workspace;
        q=take "Q" (mem E.Float16Type) q; k=take "K" (mem E.Float16Type) k;
        v=take "V" (mem E.Float16Type) v; lse=fst lse; o=fst o;
        scratch=take "scratch" (mem E.Float32Type) scratch; lse_type; o_type;
        scale=take "scale" (scalar E.Float32Type) scale;
        grid_x=take "grid_x" (scalar i32) gx; grid_y=take "grid_y" (scalar i32) gy;
        grid_z=take "grid_z" (scalar i32) gz; pid_x=take "pid_x" (scalar i32) px;
        pid_y=take "pid_y" (scalar i32) py; pid_z=take "pid_z" (scalar i32) pz;
      } in
      let unused = abi.sync_lock :: abi.workspace :: Option.to_list abi.ffts in
      let rec check ops = List.iter (fun (op : operation) ->
        List.iter (fun name -> if List.mem name op.operands then
          Source.fail op.span ("unsupported use of implicit attention argument " ^ name)) unused;
        check op.region; check op.else_region) ops in
      check p.body;
      abi
  | _ -> invalid_arg "unsupported attention entry argument count"
