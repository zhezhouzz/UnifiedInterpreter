open Unified_interpreter

let vectorlayout argv =
  let module Input = Vectorlayout_input in
  let config = ref Input.default and variant = ref None and save = ref None and replay = ref None in
  let configured = ref false in
  let input_option update n = configured := true; config := update !config n in
  let set_variant = function "ok" -> variant := Some Vectorlayout.Ok | "fail" -> variant := Some Fail
    | _ -> invalid_arg "variant must be ok or fail" in
  let options = [
    "--variant",Arg.Symbol (["ok";"fail"],set_variant)," compiled kernel";
    "--length",Arg.Int (input_option (fun c n -> {c with length=n})),"N sequence length";
    "--dimension",Arg.Int (input_option (fun c n -> {c with dimension=n})),"N head dimension";
    "--group",Arg.Int (input_option (fun c n -> {c with group=n})),"N query heads per KV head";
    "--kv-heads",Arg.Int (input_option (fun c n -> {c with kv_heads=n})),"N KV heads";
    "--splits",Arg.Int (input_option (fun c n -> {c with splits=n})),"N page partitions";
    "--save-trace",Arg.String (fun path -> save := Some path),"FILE save execution trace";
    "--replay",Arg.String (fun path -> replay := Some path),"FILE replay and verify a saved trace"] in
  Arg.parse_argv ~current:(ref 0) argv options (fun x -> raise (Arg.Bad x)) "vectorlayout [options]";
  let variant,input,result = match !replay with
    | Some path ->
        if !configured then invalid_arg "replay uses the input dimensions stored in the trace";
        let v,input,result = Device_trace.replay path in
        if Option.fold ~none:false ~some:((<>) v) !variant then invalid_arg "replay variant differs";
        v,input,result
    | None -> let v = Option.value ~default:Vectorlayout.Ok !variant and input = Input.make !config in
        v,input,Input.run v input in
  Option.iter (fun path -> Device_trace.save path variant input result) !save;
  let output = Input.gm result.memory 9 in
  let count,first = Input.differences input.config (Input.reference input) output in
  Printf.printf "variant=%s events=%d output_f32=%d differences=%d\n"
    (Vectorlayout.variant_name variant) (List.length result.events) (Bytes.length output / 4) count;
  Option.iter (fun (stream,(mask : Device_value.view),row,col,(dst : Device_value.view),(g : Device_eval.gathered)) ->
    Printf.printf "first_missed_store stream=%d row=%d col=%d bank=%s byte=%d\n"
      stream row col (Device_value.bank_name mask.bank) (Device_value.index mask [|row;col|] / 8);
    Printf.printf "indirect_load row=%d col=%d source=%s byte=%d value=%.9g\n"
      row col (Device_value.bank_name g.source) (g.source_bit / 8) (Device_value.decode dst.ty g.raw))
    (Input.first_missed_lane result);
  Option.iter (fun (d : Input.difference) ->
    Printf.printf "first_difference token=%d head=%d page=%d actual=%.9g expected=%.9g\n"
      d.token d.head d.page d.actual d.expected) first

let () = match Array.to_list Sys.argv with
  | [_] -> Demo.run_all ()
  | _::"race"::"pairs"::args ->
      (try Ir_pairs.run (Array.of_list ("race pairs"::args)) with
       | Arg.Help message -> print_string message | Arg.Bad message -> prerr_endline message; exit 2)
  | _::"race"::args ->
      let run=if List.exists (fun a -> List.mem a ["--hfusion";"--hfusion-ast";"--hfusion-ir"]) args
        then Hfusion_race.run else Race.run in
      (try if not (Module_race.dispatch args) then run (Array.of_list ("race"::args)) with
       | Arg.Help message -> print_string message
       | Attention_runtime.Source.Error (span,message) ->
           Printf.eprintf "%s: %s\n" (Attention_runtime.Source.describe span) message; exit 2
       | Yojson.Json_error message | Yojson.Safe.Util.Type_error (message,_) ->
           Printf.eprintf "invalid JSON input: %s\n" message; exit 2
       | Arg.Bad message | Invalid_argument message | Failure message | Sys_error message ->
           prerr_endline message; exit 2)
  | _::"vectorlayout"::args ->
      (try vectorlayout (Array.of_list ("vectorlayout"::args)) with
       | Arg.Help message -> print_string message
       | Arg.Bad message -> prerr_string message; exit 2)
  | _ -> invalid_arg "usage: unified-interpreter [vectorlayout [options]]"
