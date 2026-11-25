open Unified_interpreter
open Core_lang.Device
open Device_value
module Input = Vectorlayout_input

let i n = Int (I32,Int64.of_int n)
let z = i 0
let ub0 = Unified {block=0;core=Vector 0}
let execute_one memory body =
  Execution.run {name="device";register_bytes=256;streams=[{location={block=0;core=Vector 0};body}]}
    memory []
let observation (e : Execution.event) = Option.bind e.observation (fun o -> o.evidence)

let test_store ty mode grain =
  let memory = Hashtbl.create 1 and stride = 149 in
  let width = bits ty / 8 and old = '\063' in
  let initial = Bytes.make (2*stride*width) old in
  Hashtbl.add memory ub0 initial;
  let buf = Buffer (UB,ty,z,[i 2;i 128],[i stride;i 1]) in
  let zero = if is_float ty then Float (ty,0.) else Int (ty,0L) in
  let data = Layout_cast ({element=ty;lane_bits=grain},Broadcast (zero,128)) in
  let pred = Layout_cast ({element=I1;lane_bits=grain},
    Binary (And,Plt (128,i 119),Compare (Ne,Range (z,128),i 5))) in
  let result = execute_one memory [Issue (V,"strided",[
    Masked_store (buf,[z;z],pred,data,mode);Masked_store (buf,[i 1;z],pred,data,mode)])] in
  let stored = Hashtbl.find result.memory ub0 and capacity = 2048/grain in
  for row = 0 to 1 do for col = 0 to stride-1 do for byte = 0 to width-1 do
    let pos = (row*stride+col)*width+byte in
    let expected = if col < min 119 capacity && col <> 5 then '\000' else old in
    assert (Bytes.get stored pos = expected);
    assert (Bytes.get initial pos = old)
  done done done;
  let stores = List.filter_map (fun e -> match observation e with
    | Some (Device_eval.Packed s) -> Some s | _ -> None) result.events in
  assert (List.length stores = 2);
  List.iteri (fun row (s : Device_eval.packed) ->
    assert (s.origin = [|row;0|] && s.capacity = capacity && s.predicate.lanes.(5) = 0L)) stores

let check_layout variant input result =
  let mask,other,columns = match variant with
    | Vectorlayout.Ok -> 17472,1056,128 | Fail -> 33856,37952,64 in
  let covered = Array.init 2 (fun _ -> Array.init 2 (fun _ -> Array.make_matrix 32 128 false)) in
  let gathers = ref 0 in
  List.iter (fun (e : Execution.event) -> match observation e with
    | Some (Device_eval.Packed s) when s.destination.ty = I64 ->
        assert (variant = Vectorlayout.Ok && s.registers=2 && s.capacity=64 &&
          s.predicate.layout.lane_bits=32 && s.destination.bit=21568*8);
        let at = index s.destination s.origin in
        assert ((Option.get e.observation).writes =
          [Device_eval.{bank=s.destination.bank;first=at;limit=at+64*64}])
    | Some (Device_eval.Packed s) ->
        let which,base,width = if s.destination.ty = I8 then 0,mask,8 else 1,other,16 in
        let sub = e.stream-1 in
        assert (s.destination.bank = Unified {block=0;core=Vector sub} && s.destination.bit = 8*base);
        let row = s.origin.(0) in
        let writes = (Option.get e.observation).writes in
        for col = 0 to 127 do
          let bit = base*8+(128*row+col)*width in
          if List.exists (fun (r : Device_eval.access) ->
            r.bank = s.destination.bank && r.first <= bit && bit+width <= r.limit) writes then
            covered.(sub).(which).(row).(col) <- true
        done
    | Some (Device_eval.Gather (dst,lanes)) ->
        incr gathers;
        let qstart = 128 + 16*(e.stream-1) in
        for row = 0 to 31 do
          let q = qstart + row/2 and head = row mod 2 in
          List.iter (fun col ->
            let g = lanes.(128*row+col) in
            let bank,byte = if col < columns then Global 2,2*((q*2+head)*128+col)
              else dst.bank,other+2*(128*row+col) in
            assert (g.source = bank && g.source_bit = 8*byte);
            assert (g.raw = Int64.of_int (Bytes.get_uint16_le (Hashtbl.find input.Input.memory bank) byte))
          ) [0;63;64;127]
        done
    | None -> ()) result.Execution.events;
  assert (!gathers = 2);
  Array.iter (Array.iter (Array.iter (Array.iteri (fun col b -> assert (b = (col < columns)))))) covered

let full variant =
  let input = Input.make Input.default in
  let result = Input.run variant input in
  check_layout variant input result;
  let expected = Input.reference input and actual = Input.gm result.memory 9 in
  let count,first = Input.differences input.config expected actual in
  (match variant,first,Input.first_missed_lane result with
   | Ok,None,None -> assert (count = 0)
   | Fail,Some d,Some (_,_,0,64,_,read) ->
       assert (d.token=128 && d.head=0 && d.page=0 && d.actual < d.expected && count=128);
       assert (read.source_bit = 8*(37952+2*64) && read.raw=0L)
   | _ -> assert false);
  let tensor = Input.output input result in
  assert (tensor.dims=[160;2;2] && Tensor.get tensor [127;1;1]=12345.);
  let path = "vectorlayout-" ^ Vectorlayout.variant_name variant ^ ".json" in
  Device_trace.save path variant input result;
  let v,_,replayed = Device_trace.replay path in
  assert (v = variant && result.events = replayed.events && Input.gm replayed.memory 9 = actual);
  let bad = Yojson.Safe.Util.to_assoc (Yojson.Safe.from_file path) in
  let corrupt = `Assoc (("events",`List [])::List.remove_assoc "events" bad) in
  Out_channel.with_open_bin path (fun ch -> Yojson.Safe.to_channel ch corrupt);
  (match Device_trace.replay path with
   | exception Invalid_argument _ -> () | _ -> failwith "accepted modified trace");
  Sys.remove path

let tail_and_reuse () =
  let c = {Input.default with length=407;dimension=97;group=1;kv_heads=2} in
  let input = Input.make c in
  let result = Input.run Ok input in
  assert (Input.gm result.memory 9 = Input.reference input);
  let count site = List.length (List.filter (fun (e : Execution.event) ->
    e.phase = "done" && e.site = site) result.events) in
  assert (count "mmadL1"=8 && count "fixpipe"=8 && count "indirect_store"=16);
  let input = Input.make {c with length=33;dimension=31;splits=2} in
  let result = Input.run Ok input in
  assert (Input.gm result.memory 9 = Input.reference input)

let retained_other () =
  let input = Input.make Input.default in
  for sub = 0 to 1 do
    let ub = Hashtbl.find input.memory (Unified {block=0;core=Vector sub}) in
    for i = 0 to 4095 do Bytes.set_uint16_le ub (37952+2*i) 0x4700 done
  done;
  let ok = Input.run Ok input and fail = Input.run Fail input in
  check_layout Ok input ok; check_layout Fail input fail;
  assert (Input.gm ok.memory 9 = Input.reference input);
  let path = "vectorlayout-custom.json" in
  Device_trace.save path Fail input fail;
  (match Device_trace.replay path with exception Invalid_argument _ -> () | _ -> assert false);
  let _,_,replayed = Device_trace.replay ~input path in
  assert (fail.events = replayed.events);
  Sys.remove path;
  match Input.first_missed_lane fail with
  | Some (_,_,0,64,_,g) -> assert (decode F16 g.raw = 7.)
  | _ -> assert false

let test_numbers () =
  List.iter (fun (value,raw) -> assert (half_bits value = raw && half_float (Int64.to_int raw) = value))
    [0x1p-24,1L;0x1p-14,0x0400L;1.,0x3c00L;-2.,0xc000L;65504.,0x7bffL;infinity,0x7c00L];
  assert (half_bits (1. +. 0x1p-11) = 0x3c00L);
  let input = Input.make {Input.default with length=2;dimension=1} in
  Bytes.set_uint16_le (Input.gm input.memory 2) 0 0x7e00;
  let result = Input.run Ok input in
  let expected = Input.reference input in
  assert (Int32.float_of_bits (Bytes.get_int32_le expected 0) = neg_infinity);
  assert (Input.gm result.memory 9 = expected);
  let empty = Input.make {Input.default with length=0} in
  assert (Bytes.length (Input.gm (Input.run Ok empty).memory 9) = 0)

let () =
  test_store I8 Pk4 32; test_store I8 Pk 16; test_store F16 Pk 32; test_store F16 Norm 16;
  full Ok; full Fail; retained_other (); tail_and_reuse (); test_numbers ()
