(* 兼容已经使用 Loop_schedule 的 OCaml 调用方。 *)
include Concrete_schedule

let program ?timeout_ms ?family ~capacity backend program =
  match family with
  | None -> Concrete_schedule.program ?timeout_ms ~capacity backend program
  | Some (template,input) ->
      Historical_schedule.analyze_instance ?timeout_ms ~input ~capacity backend template program

let family = Historical_schedule.family
let symbolic_witness = Historical_schedule.symbolic_witness
