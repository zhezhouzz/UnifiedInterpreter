open Unified_interpreter
open Core_lang.Device
module D = Device_run
module R = Device_races
module J = Yojson.Safe.Util

let litmus () =
  let i n = Int (I32,Int64.of_int n) in
  let buf space ty at = Buffer (space,ty,i at,[i 1],[]) in
  let mask = buf UB I8 0 and offset = buf UB I64 8 and src = buf UB F32 16 in
  let dst = buf (GM 9) F32 0 in
  let stream = {location={block=0;core=Vector 0};body=[
    Issue (V,"predicate",[Store (mask,[i 0],Int (I8,1L))]);
    Issue (V,"scatter",[Indirect_store (src,offset,mask,dst)]);
    Issue (MTE3,"output",[Store (dst,[i 0],Float (F32,0.))]);
    Let ("output",Read (dst,[i 0],1))]} in
  let memory = Hashtbl.create 2 in
  Hashtbl.add memory (Device_value.Unified stream.location) (Bytes.make 24 '\000');
  Hashtbl.add memory (Device_value.Global 9) (Bytes.make 4 '\000');
  let input = Vectorlayout_input.{config=default;blocks=1;bindings=[];memory} in
  {name="predicate-and-scalar-read";register_bytes=256;streams=[stream]},input

let oracle program (input : Vectorlayout_input.input) =
  let shortest = Hashtbl.create 16 in
  let rec visit choices =
    let previous = ref [] and enabled = ref [] and steps = ref 0 in
    let on_step (t : D.transition) =
      incr steps;
      let sites = R.sites 0 t in
      List.iter (fun (s : R.access_site) ->
        List.iter (fun (p : R.access_site) -> if R.conflict p.observed s.observed<>[] then (
          let key = p.id,s.id and length = !steps in
          Hashtbl.replace shortest key (min length (Option.value ~default:length (Hashtbl.find_opt shortest key)))
        )) !previous) sites;
      previous := List.rev_append sites !previous in
    ignore (D.run ~prefix:choices ~on_step ~on_stop:(fun xs -> enabled := xs)
      ~record_events:false program input.memory input.bindings);
    List.iter (fun choice -> visit (choices@[choice])) !enabled in
  visit [];
  Hashtbl.filter_map_inplace (fun (a,b) len -> if Hashtbl.mem shortest (b,a) then Some len else None) shortest;
  shortest

let () =
  let p,input = litmus () in
  let expected = oracle p input in
  assert (Hashtbl.length expected=8);
  List.iter (fun backend ->
    let model = R.compile_program ~backend p input in
    let races = R.generate model in
    assert (2*List.length races=Hashtbl.length expected);
    List.iter (fun j ->
      R.replay_witness model j;
      let id field = (List.find (fun site -> R.identity_json site=J.member field j) model.sites).id in
      let a=id "first" and b=id "second" in
      assert (Hashtbl.find expected (a,b)=List.length (J.to_list (J.member "forward" j)));
      assert (Hashtbl.find expected (b,a)=List.length (J.to_list (J.member "reverse" j)))) races;
    let original=List.hd races in
    let changed=`Assoc (("conflicts",`List [])::List.remove_assoc "conflicts" (J.to_assoc original)) in
    match R.replay_witness model changed with
    | () -> failwith "accepted a witness with different addresses" | exception Invalid_argument _ -> ()
  ) [Bug_traces.Search;Solve]
