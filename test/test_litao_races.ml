open Unified_interpreter
module J = Yojson.Safe.Util
module B = Bug_traces

let () =
  let cases=Race_benchmarks.catalog "../benchmark" in
  let names=List.map fst cases in
  assert (List.length names=List.length (List.sort_uniq compare names));
  List.iter (fun name -> List.iter (fun variant ->
    assert (List.mem ("litao/"^name^"/"^variant) names)) ["buggy";"fixed"])
    ["missing-wait";"mix-handoff";"add-Ascend910B1";"wrong-event";"broadcast-guard";"counter-capacity";
     "cross-loop-placement";"double-buffer";"empty-preload";"event-collision";"indirect-atomic";
     "scalar-fallback";"slot-release";"zero-trip-alias"];
  let launch name=match (List.assoc ("litao/"^name) cases) () with
    | Core l -> l | Device _ -> assert false in
  let core name n backend =
    let l=launch name in
    Race_report.core backend (Race_report.schedule l (Z.of_int n)) in
  let checks = [
    "missing-wait/buggy",0,true;"missing-wait/fixed",0,false;
    "mix-handoff/buggy",0,true;"mix-handoff/fixed",0,false;
    "scalar-fallback/buggy",0,true;"scalar-fallback/fixed",0,false;
    "indirect-atomic/buggy",0,true;"indirect-atomic/fixed",0,false;
    "double-buffer/fixed",3,true;"zero-trip-alias/buggy",0,true] in
  List.iter (fun (name,n,present) ->
    List.iter (fun backend -> assert ((core name n backend<>[])=present)) [B.Search;Solve]) checks;
  List.iter (fun n ->
    let safe=core "add-Ascend910B1/fixed" n B.Search in
    assert (safe=core "add-Ascend910B1/fixed" n B.Solve && safe=[]);
    let buggy=core "add-Ascend910B1/buggy" n B.Search in
    let widths=List.concat_map (fun j -> J.to_list (J.member "conflicts" j) |> List.map (function
      | `List [_;`Int first;`Int limit] -> limit-first | _ -> assert false)) buggy in
    let expected=if n>0 && n<256 then [4*n;1024] else [1024] in
    assert (List.sort_uniq compare widths=expected);
    let signature j=J.member "nodes" j,J.member "conflicts" j in
    assert (List.map signature buggy=List.map signature (core "add-Ascend910B1/buggy" n B.Solve))
  ) [0;1;255;256;257]
