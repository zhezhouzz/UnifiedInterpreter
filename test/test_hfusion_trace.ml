module H = Hfusion_trace
module A = Attention_runtime
module E = Extracted_semantics.Unified_semantics
let ast file=A.Parser.parse ~file (A.Attention.read_file file)
let buf ?(initialized=true) ?(offset=0) ?(stride=1) ?(elements=8) name =
  H.Buffer {allocation=name;elements;initialized;offset;shape=[8];strides=[stride]}
let launch a0 b0 out0 a1 b1 out1 =
  [["%a",a0;"%b",b0;"%out",out0];["%a",a1;"%b",b1;"%out",out1]]

let compare_backends ?n model =
  let bfs=H.generate ?n H.Bfs model and smt=H.generate ?n H.Smt model in
  assert (bfs.status=H.Complete && smt.status=H.Complete);
  let endpoints report=List.map (fun (r:H.race) ->
    H.verify_race ?n model r;r.first,r.second) report.H.races |> List.sort compare in
  assert (endpoints bfs=endpoints smt);
  bfs.races

(* 在现有 OCaml 指令执行函数上逐条消费前缀，两个实例共用实际输出分配。 *)
let execute_vector_add program model trace =
  let state=ref {A.Handlers.memory=E.empty_memory;marker=0} in
  let ctx={A.Runner.state;steps=0;max_steps=1000;current=None;pid=0;calls=0;loops=[];trace=ignore} in
  let allocate values =
    let storage,memory=E.allocate_buffer E.ASGM E.Float32Type values !state.memory in
    let desc={E.descriptor_allocation=storage;descriptor_offset=E.Z0;
              descriptor_sizes=[8];descriptor_strides=[A.Numeric.z_of_int 1]} in
    let id,memory=E.insert_descriptor desc memory in
    state:={!state with memory};id,A.Runner.Memref (id,[8],E.Float32Type) in
  let data x=List.init 8 (fun _ -> x) in
  let id,out=allocate (data 0.) in
  let envs=Array.init 2 (fun pid -> ["%a",snd (allocate (data (float (pid+1))));
    "%b",snd (allocate (data 10.));"%out",out]) in
  let pc=Array.make 2 0 in
  let step pid =
    ctx.pid<-pid;
    let op=List.nth program.A.Parser.body pc.(pid) in
    let env,_=A.Runner.execute_block ctx envs.(pid) [op] in
    envs.(pid)<-env;pc.(pid)<-pc.(pid)+1 in
  let scheduled pid=H.scheduling_point model ~stream:pid ~path:[pc.(pid)] in
  A.Runner.with_handlers ctx (fun () ->
    List.iter (fun (event:H.event) ->
      let pid=event.stream in
      while not (scheduled pid) do step pid done;
      assert (event.path=[pc.(pid)] && (H.resolve program event.path).opcode=event.opcode);
      step pid) trace;
    Array.iteri (fun pid _ -> while pc.(pid)<List.length program.body do step pid done) pc;
    let view=E.MemRefBackedTensor (id,[8],E.Float32Type,{E.access_restrict=false;access_writable=false}) in
    let value=Effect.perform (A.Handlers.Memory ("materialize_output",E.materialize view)) in
    let _,_,xs=A.Handlers.packed value in xs)

let () =
  let program=ast "../examples/kernels/vector_add_hfusion.mlir" in
  let a=buf "a" and b=buf "b" and c=buf "c" and d=buf "d" and out=buf "out" in
  let model=H.prepare program (launch a b out c d out) in
  assert (not (H.scheduling_point model ~stream:0 ~path:[2]));
  let race=List.hd (compare_backends model) in
  assert (race.first.path=[4] && race.second.path=[4]);
  assert (execute_vector_add program model race.forward=List.init 8 (fun _ -> 12.));
  assert (execute_vector_add program model race.reverse=List.init 8 (fun _ -> 11.));
  (match H.replay model [race.first] with () -> failwith "out-of-order event accepted"
   | exception Invalid_argument _ -> ());
  (match H.verify_race model {race with reverse=race.forward} with
   | () -> failwith "same order accepted twice" | exception Invalid_argument _ -> ());
  let check args=compare_backends (H.prepare program args) in
  let rw=check (launch a b out out c d) in
  (match rw with [r] -> assert (r.first.path=[4] && r.second.path=[3]) | _ -> assert false);
  let empty=buf ~initialized:false "out" in
  assert (check (launch a b empty empty c d)=[]);
  let shared=buf ~initialized:false "shared" in
  let third_writer=(launch empty a shared b c shared)@
    [["%a",d;"%b",buf "extra";"%out",empty]] in
  (match check third_writer with
   | [r] -> List.iter (fun trace -> assert (List.exists (fun (e:H.event) ->
       e.stream=2 && e.opcode="bufferization.materialize_in_destination") trace)) [r.forward;r.reverse]
   | _ -> assert false);
  assert (check (launch a b out a d out)=[]);
  let strided offset=buf ~elements:17 ~stride:2 ~offset "output" in
  assert (check (launch a b (strided 0) c d (strided 1))=[]);
  assert (List.length (check (launch a b (strided 0) c d (strided 2)))=1);
  let program=ast "../benchmarks/hfusion/strided-output.mlir" in
  let scalar size allocation=H.Buffer {allocation;elements=size;initialized=true;shape=[size];offset=0;strides=[1]} in
  let args ?(start=0) lane out=["%input",scalar 1 ("input"^string_of_int lane);"%out",scalar 7 out;
                     "%n",H.Parameter;"%lane",H.Integer lane;"%start",H.Integer start] in
  let model=H.prepare program [args 0 "out";args 3 "out"] in
  assert (compare_backends ~n:Z.zero model=[]);
  assert (compare_backends ~n:(Z.of_int 3) model=[]);
  let report=H.generate H.Symbolic model in
  assert (report.n=Some (Z.of_int 4) && report.status=H.Race);
  (match report.races with [r] ->
    assert (r.first.iterations=[3] && r.second.iterations=[0]);
    H.verify_race ?n:report.n model r;
    H.replay ~n:(Z.of_string "1000000000000") model r.forward;
    let invalid=H.prepare program [args 0 "out";args 3 "out";args 6 "other"] in
    H.replay ?n:report.n invalid r.forward;
    (match H.verify_race ?n:report.n invalid r with
     | exception Invalid_argument _ -> () | () -> failwith "accepted out-of-bounds continuation") | _ -> assert false);
  assert (H.replay_report program (H.to_json report)=1);
  assert ((H.generate H.Symbolic (H.prepare program [args 0 "one";args 3 "two"])).status=H.No_race);
  assert ((H.generate H.Symbolic (H.prepare program [args 0 "out";args 4 "out"])).status=H.No_race);
  let late=H.prepare program [args ~start:1000000 0 "out";args ~start:1000000 3 "out"] in
  let report=H.generate H.Symbolic late in
  assert (report.n=Some (Z.of_int 1000004) && H.replay_report program (H.to_json report)=1);
  let start=max_int-3 in
  let wide=H.prepare program [args ~start 0 "out";args ~start 3 "out"] in
  let report=H.generate H.Symbolic wide in
  assert (report.n=Some (Z.succ (Z.of_int max_int)) && H.replay_report program (H.to_json report)=1)
