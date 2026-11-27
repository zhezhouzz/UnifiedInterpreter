module R = Hivm_trace.Execution
module A = Hivm_trace.Module_ast
module V = Hivm_trace.Execution_value
let usage = "unified-interpreter run FILE --stage {hfusion|hivm} --launch JSON [--trace-db FILE | --builtin] [--trace] [--max-steps N] [--scheduler-timeout-ms N]"

let hex bytes =
  let digits="0123456789abcdef" in
  String.init (2*Bytes.length bytes) (fun i->let n=Bytes.get_uint8 bytes (i/2) in
    digits.[if i mod 2=0 then n lsr 4 else n land 15])

let scalar = function
  | V.C.VInt z -> `Intlit (Z.to_string z)
  | VBool b -> `Bool b
  | VFloat f when Float.is_finite f -> `Float f
  | VFloat f -> `String (string_of_float f)
  | _ -> invalid_arg "expected a numeric source value"

let rec value = function
  | V.Scalar v -> scalar v
  | V.Lanes xs -> `List (Array.to_list (Array.map scalar xs))
  | V.Buffer b ->
      let ints xs = `List (Array.to_list (Array.map (fun n -> `Int n) xs)) in
      `Assoc ["storage",`String b.storage.name; "base_bytes",`Int b.base;
              "shape",ints b.shape; "strides",ints b.strides;
              "values",`List (List.init (V.size b.shape) (fun i -> value (V.get b i)))]

let run file args =
  let stage=ref "" and launch=ref "" and compiler=ref "" and limit=ref 10_000_000
  and trace=ref false and inspect=ref [] and builtin=ref false and db_path=ref None and timeout_ms=ref None in
  Arg.parse_argv ~current:(ref 0) (Array.of_list ("run"::args))
    ["--stage",Arg.Symbol (["hfusion";"hivm"],fun s->stage:=s),"IR stage";"--launch",Arg.Set_string launch,"launch JSON";
     "--bishengir-opt",Arg.Set_string compiler,"normalize assembly with BiShengIR";
     "--builtin",Arg.Set builtin,"use the built-in scheduling policy";
     "--trace-db",Arg.String (fun p->db_path:=Some p),"scheduler history database";
     "--scheduler-timeout-ms",Arg.Int (fun n->timeout_ms:=Some n),"scheduler request budget in milliseconds";
     "--max-steps",Arg.Set_int limit,"maximum interpreter steps";"--trace",Arg.Set trace,"emit execution sites on stderr";
     "--inspect-input",Arg.Symbol (["hivm.hir.load";"hivm.hir.vabs"],fun code->inspect:=code::!inspect),
         "sample the input tensor when a load or vabs completes"]
    (fun s->raise (Arg.Bad ("unexpected argument "^s))) usage;
  if !launch="" || !stage="" then raise (Arg.Bad usage);
  if !builtin && (!db_path<>None || !timeout_ms<>None) then raise (Arg.Bad "scheduler options require scheduled execution");
  let start=Unix.gettimeofday () in
  let syntax=if !compiler="" then A.Custom else A.BiSheng !compiler in
  let ast=A.parse ~syntax ~file (Attention_runtime.Attention.read_file file) in
  let launch=Yojson.Safe.from_file !launch in
  let parsed=Unix.gettimeofday () in
  let samples=ref [] in
  let on_read stream code b=if List.mem code !inspect then
    samples:=`Assoc ["stream",`Int stream;"opcode",`String code;
      "values",`List (List.init (V.size b.V.shape) (fun i->value (V.get b i)))]::!samples in
  let on_read=if !inspect=[] then None else Some on_read in
  let trace=if !trace then Some (Printf.eprintf "%d %s\n") else None in
  let schedule,r=if !builtin then
    None,R.run_builtin ~max_steps:!limit ?on_read ?trace ~stage:!stage ~launch ast
  else
    let schedule,r=Ir_scheduler.run_module ?db_path:!db_path ?timeout_ms:!timeout_ms ~max_steps:!limit
      ?on_read ?trace ~stage:(if !stage="hivm" then HIVM else HFusion) ~launch ast in
    Some schedule,r in
  let finished=Unix.gettimeofday () in
  let status,detail=match r.status with Finished->"returned",`Null | Blocked xs->"deadlock",`List (List.map (fun x->`String x) xs)
    | Invalid_memory msg->"invalid-memory",`String msg | Step_limit msg->"step-limit",`String msg in
  Yojson.Safe.to_channel stdout (`Assoc ["status",`String status;"detail",detail;"steps",`Int r.steps;
    "schedule",(match schedule with None->`Null | Some t->Ir_scheduler.Delivery.encode t);
    "tasks",`Int r.tasks;"parse_seconds",`Float (parsed-.start);"execute_seconds",`Float (finished-.parsed);
    "memory_hex",`Assoc (List.map (fun (k,b)->k,`String (hex b)) r.memory);
    "inspected_inputs",`List (List.rev !samples);
    "returns",`List (Array.to_list (Array.map (fun xs->`List (List.map value xs)) r.returned))]);print_newline ()
