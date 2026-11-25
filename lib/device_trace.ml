open Device_ast
open Device_value
open Device_run
open Vectorlayout_input

let int n = `Int n
let string x = `String x
let list f xs = `List (List.map f xs)
let array f xs = list f (Array.to_list xs)
let range (a : Device_eval.access) = `List [string (bank_name a.bank);int a.first;int a.limit]
let buffer (v : view) = `Assoc ["bank",string (bank_name v.bank);"base_bit",int v.bit;
  "type",string (dtype_name v.ty);"shape",array int v.shape;"strides",array int v.strides]
let evidence = function
  | Device_eval.Packed s ->
      ["destination",buffer s.destination;"origin",array int s.origin;"pack",string (pack_name s.packing);
       "logical_lanes", int (Array.length s.predicate.lanes);"source_element",string (dtype_name s.source_layout.element);
       "source_lane_bits",int s.source_layout.lane_bits;"registers",int s.registers;"capacity",int s.capacity;
       "predicate_lane_bits",int s.predicate.layout.lane_bits;
       "predicate",string (String.init (Array.length s.predicate.lanes)
         (fun i -> if s.predicate.lanes.(i) <> 0L then '1' else '0'))]
  | Device_eval.Gather (dst,lanes) ->
      ["destination",buffer dst;"source_lanes",array (fun (g : Device_eval.gathered) ->
        `List [string (bank_name g.source);int g.source_bit;string (Int64.to_string g.raw)]) lanes]
let event e =
  let fields = ["stream", int e.stream; "pipe", string (pipe_name e.pipe); "site", string e.site;
    "path",list int e.path;"iterations",list int e.iterations; "phase",string e.phase] in
  let details = match e.observation with None -> [] | Some o ->
    ["operation",string o.operation; "detail",string o.detail;
     "read_bits",list range o.reads; "write_bits",list range o.writes] @
     Option.fold ~none:[] ~some:evidence o.evidence in
  `Assoc (fields @ details)
let choice = function Host id -> `List [int id] | Finish (id,n) -> `List [int id; int n]
let parse_choice = function
  | `List [`Int id] -> Host id | `List [`Int id;`Int n] -> Finish (id,n)
  | _ -> invalid_arg "invalid trace schedule"
let config c = `Assoc ["length",int c.length;"dimension",int c.dimension;"group",int c.group;
  "kv_heads",int c.kv_heads;"splits",int c.splits]
let parse_config json =
  let open Yojson.Safe.Util in
  let get name = json |> member name |> to_int in
  {length=get "length";dimension=get "dimension";group=get "group";kv_heads=get "kv_heads";splits=get "splits"}
let fingerprint memory =
  Hashtbl.to_seq memory |> List.of_seq |> List.sort (fun (a,_) (b,_) -> compare a b)
  |> List.map (fun (b,data) -> bank_name b,string (Digest.to_hex (Digest.bytes data)))
  |> fun fields -> `Assoc fields
let bindings input =
  `Assoc (List.map (fun (name,value) ->
    name,(match value with View v -> buffer v | Reg r ->
      `Assoc ["type",string (dtype_name r.layout.element);"lane_bits",int r.layout.lane_bits;"registers",int r.registers;
              "lanes",array (fun x -> string (Int64.to_string x)) r.lanes])) input.bindings)

let document variant input result : Yojson.Safe.t =
  `Assoc ["format",string "vectorlayout-1";"variant",string (Vectorlayout.variant_name variant);
    "fixture",config input.config;"bindings",bindings input;"initial_memory",fingerprint input.memory;
    "streams",list (fun s -> `Assoc ["block",int s.location.block;"core",string (core_name s.location.core)])
      (Vectorlayout.make variant input.blocks).streams;
    "schedule",list choice result.choices;"events",list event result.events;
    "final_memory",fingerprint result.memory]
let save path variant input result =
  Out_channel.with_open_bin path (fun ch -> Yojson.Safe.to_channel ch (document variant input result))
let replay ?input path =
  let json = Yojson.Safe.from_file path in
  let open Yojson.Safe.Util in
  let field name = member name json in
  if to_string (field "format") <> "vectorlayout-1" then invalid_arg "unknown trace format";
  let variant = match to_string (field "variant") with "ok" -> Vectorlayout.Ok | "fail" -> Vectorlayout.Fail
    | _ -> invalid_arg "invalid trace variant" in
  let fixture = parse_config (field "fixture") in
  let input = match input with Some x -> x | None -> make fixture in
  if input.config <> fixture || not (Yojson.Safe.equal (bindings input) (field "bindings"))
    || not (Yojson.Safe.equal (fingerprint input.memory) (field "initial_memory")) then invalid_arg "replay input differs";
  let schedule = List.map parse_choice (to_list (field "schedule")) in
  let result = run ~schedule variant input in
  if not (Yojson.Safe.equal json (document variant input result)) then invalid_arg "trace replay differs";
  variant,input,result
