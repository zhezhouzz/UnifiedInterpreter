open Stdlib
open Unified_interpreter
open Execution_value
module L = Mlir_lowering
module Q = Execution_queue
module Launch = Mlir_launch
module J = Yojson.Safe.Util
module T = Execution_tensor
module H = Execution_handlers

type status = Finished | Blocked of string list | Invalid_memory of string | Step_limit of string
type result = {status:status; memory:(string * bytes) list; returned:t list array; steps:int; tasks:int}
exception Budget of string
let pipe op key = C.Device.pipe_name (Launch.pipe (L.enum (L.attribute op key)))
let memory f = Effect.perform (Effects.Access_memory f)
let dims xs=Array.of_list (List.map Z.to_int xs)
let env_bind env ids vs=List.iter2 (fun (id,_) v->env.(id)<-v) ids vs
let integer = function M.Integer n->n | _->invalid_arg "expected integer type"

let run_module ?trace ?on_read ?(max_steps=10_000_000) ~stage ~launch ast =
  if max_steps<=0 then invalid_arg "step budget must be positive";
  let configuration=match launch with
    | `Assoc fields -> (match List.assoc_opt "stage" fields with Some (`String x) when x<>stage ->
          invalid_arg "launch stage mismatch" | _->()); `Assoc (("stage",`String stage)::List.remove_assoc "stage" fields)
    | _->invalid_arg "expected launch object" in
  let launch=Launch.bind ~configuration ast in
  let state=Interpreter.make_state [] "out" [0] and steps=ref 0 and current=ref "" in
  let locations=Array.of_list (List.map (fun (s:Launch.stream)->s.location) launch.streams) in
  state.location<-Array.get locations;
  state.source_step<-(fun site->
    if !steps>=max_steps then raise (Budget site);
    incr steps; current:=site; Option.iter (fun f->f state.current_pid site) trace);
  let mapped f=Interpreter.H4.run ~extension:H.h4 state (fun ()->Interpreter.H3.run ~extension:H.h3 state (fun ()->
    Interpreter.H2.run state (fun ()->Interpreter.H1.run state f))) in
  let schedule f=Interpreter.H5.run state (fun ()->Effect.perform (Effects.Schedule f)) in
  if Mlir_device.indexed_kernel launch then (
    let device=Mlir_device.lower_with_launch ast launch and status=ref Finished and tasks=ref 0 in
    let origins=Hashtbl.create (List.length device.sources) in
    List.iter (fun ((id,path),(source:L.source))->
      let entry=List.fold_left (fun _ (_,_,_,callee)->callee) (List.nth launch.streams id).entry source.frames in
      let site=Printf.sprintf "%s/%s %s" entry (String.concat "." (List.map string_of_int source.origin.path)) source.origin.opcode in
      Hashtbl.add origins (id,path) site) device.sources;
    let source_step id site path=state.current_pid<-id;
      Effect.perform (Effects.Source_step (Option.value (Hashtbl.find_opt origins (id,path)) ~default:site)) in
    let memory=try
      (schedule (fun ()->mapped (fun ()->Device_run.run ~source_step ~source_effects:true ~record_events:false
          ~record_choices:false ~observe_accesses:false ~on_finish:(fun ()->incr tasks) ~copy_bank:(fun _->false)
          ~on_blocked:(fun reason->status:=Blocked [reason]) device.program device.memory device.bindings))).memory
      with Budget site->status:=Step_limit site;device.memory
         | Device_eval.Invalid_indirect_address i->status:=Invalid_memory (Printf.sprintf "%s: indirect index %d" !current i);device.memory in
    {status= !status;steps= !steps;tasks= !tasks;returned=Array.make (List.length launch.streams) [];
     memory=List.map (fun (s:Launch.storage)->s.name,Hashtbl.find memory (Device_value.Allocation s.name)) launch.storages})
  else
  let banks=Array.of_list (List.map (fun (s:Launch.storage)->
    let b=storage s.name s.bytes in
    let initial=L.initial_bytes ast s in Bytes.blit initial 0 b.data 0 (Bytes.length initial); b) launch.storages) in
  let local=Hashtbl.create 16 in
  let local_storage block core bank need =
    let key=block,core,bank in
    let s=match Hashtbl.find_opt local key with Some s->s | None->let s=storage bank 0 in Hashtbl.add local key s;s in
    let length=Bytes.length s.data in
    if need>length then (
      let data=Bytes.extend s.data 0 (need-length) in
      Bytes.fill data length (need-length) '\000';
      s.data<-data);
    s in
  (match J.member "local_initial" configuration with
   | `Null->()
   | rows -> List.iter (fun row->
       let stream=List.nth launch.streams (J.to_int (J.member "stream" row)) in
       let bank=J.to_string (J.member "space" row) and base=J.to_int (J.member "base_bytes" row) in
       let name=Printf.sprintf "#hivm.address_space<%s>" bank in
       let count=J.to_int (J.member "count" row) and element=element ast (J.to_string (J.member "element" row)) in
       let s=local_storage stream.location.block (if bank="ub" then Some stream.location.core else None)
           name (base+count*width element) in
       let view={storage=s;shape=[|count|];strides=[|1|];origin=base;base;element} in
       let data=J.member "value" row in
       let v=match element with Integer _->Scalar (C.VInt (Launch.z_of_json data)) | _->T.float (J.to_number data) in
       for i=0 to count-1 do write view i v done) (J.to_list rows));
  let streams=Array.of_list launch.streams in
  let controls=Array.map (fun _->Hashtbl.create 4) streams in
  let peers=Array.map (fun (s:Launch.stream)->
    let neighbors sending=match launch.edges with
      | Some edges->List.filter_map (fun (a,b)->if sending && a=s.id then Some b
          else if not sending && b=s.id then Some a else None) edges
      | None->Array.to_list streams |> List.filter_map (fun (p:Launch.stream)->
          if p.location.block=s.location.block && (s.location.core=Cube)<>(p.location.core=Cube)
          then Some p.id else None) in neighbors true,neighbors false) streams in
  let returned=Array.make (Array.length streams) [] in
  let functions =
    let functions=Hashtbl.create (List.length ast.M.functions) in
    let site_count=ref 0 in
    let prepare entry =
      let body=M.entry ast entry in
      let types,total=L.function_types body in
      let ty id=Mlir_memory.type_of ast (Hashtbl.find types id) in
      let shaped id=Mlir_memory.shaped ast (Hashtbl.find types id) in
      let rec block path (b:M.block) =
        let body=List.mapi (fun i op->operation (path@[i]) op) b.body |> Array.of_list in
        fun frame nested ordinal args ->
          env_bind frame b.arguments args;
          let rec walk i=if i=Array.length body then [] else
            match body.(i) frame nested ordinal with Some values->values | None->walk (i+1) in walk 0
      and operation path (op:M.operation) =
        incr site_count; let internal_event= - !site_count in
        let code=op.opcode and attr=L.attribute op in
        let site=Printf.sprintf "%s/%s %s" entry (String.concat "." (List.map string_of_int path)) code in
        let regions=List.mapi (fun i blocks->Array.of_list (List.mapi (fun j child->block (path@[i;j]) child) blocks)) op.regions
          |> Array.of_list in
        let result_id ()=fst (List.hd op.results) in
        let shape ()=shaped (result_id ()) in
        let elem ()=element ast (shape ()).element in
        let static_slice=lazy (L.slice_attributes op) in
        let slice (src:view) dynamic target =
          let offsets,sizes,steps=L.mixed (Lazy.force static_slice) (List.map scalar dynamic) in
          let template=C.{storage=None;bytes=Bytes.length src.storage.data;base_bytes=src.origin;
            offset=Z.of_int ((src.base-src.origin)/width src.element);
            element_bytes=width src.element;shape=Array.to_list src.shape;
            strides=Array.to_list (Array.map Z.of_int src.strides)} in
          let view=Mlir_memory.subview template ~offsets ~sizes ~steps target in
          {src with base=src.origin+Z.to_int view.offset*width src.element;
                    shape=Array.of_list view.shape;strides=dims view.strides} in
        let f frame nested ordinal args =
          let stream=streams.(state.current_pid) in
          let core=stream.location in
          let reg i args=regions.(i).(0) frame nested ordinal args in
          let work pipe f=if nested || pipe="S" then f () else
            Q.submit pipe site (Q.Work (fun ()->mapped (fun ()->current:=site;f ()))) in
          let target=if launch.hfusion then "HFUSION_ASYNC" else "S" in
          let transfer pipe f=work pipe (fun ()->memory f); [] in
          let observe b=Option.iter (fun report->report stream.id code b) on_read in
          let num=numeric_args in
          match code,args with
          | "func.call",vs ->
              let name=J.to_string (attr "callee") in
              let call nested=let fn=Hashtbl.find functions name in fn nested vs in
              if attr "hivm.pipe"<>`Null || attr "hivm.vector_function"<>`Null || attr "vector_function"<>`Null then
                (work (if attr "hivm.pipe"=`Null then "V" else pipe op "hivm.pipe") (fun ()->ignore (call true)); [])
              else call nested
          | "scf.if",[test] -> let i=if Mlir_scalar.boolean (scalar test) then 0 else 1 in
              if i>=Array.length regions || Array.length regions.(i)=0 then [] else reg i []
          | "scf.for",lo::hi::stride::initial ->
              let step=z stride in if Z.sign step<=0 then invalid_arg "nonpositive scf.for step";
              let rec loop iv ord values=if Z.geq iv (z hi) then values else
                loop (Z.add iv step) (ord+1) (regions.(0).(0) frame nested ord (Scalar (C.VInt iv)::values)) in
              loop (z lo) 0 initial
          | "scf.while",vs ->
              let rec loop ord vs=match regions.(0).(0) frame nested ord vs with
                | test::xs when Mlir_scalar.boolean (scalar test)->loop (ord+1) (regions.(1).(0) frame nested ord xs)
                | _::xs->xs | []->invalid_arg "missing while condition" in loop 0 vs
          | ("arith.constant"),[] ->
              let v=match ty (result_id ()),attr "value" with
                | M.Integer _,`Bool b->C.VBool b | M.Integer w,n->Mlir_scalar.int w (Launch.z_of_json n)
                | M.Float _,`String s->C.VFloat (float_of_string s)
                | _->invalid_arg "unsupported constant" in [Scalar v]
          | "arith.cmpi",[a;b] -> [Scalar (Mlir_scalar.compare (J.to_int (attr "predicate"))
              (integer (ty (List.hd op.operands))) (scalar a) (scalar b))]
          | "arith.select",[p;a;b]->[if Mlir_scalar.boolean (scalar p) then a else b]
          | code,[a;b] when List.mem code Mlir_scalar.binary_opcodes ->
              [Scalar (Mlir_scalar.integer_binary code (integer (ty (result_id ()))) (scalar a) (scalar b))]
          | code,[a] when List.mem code Mlir_scalar.casts ->
              let extend=if List.mem code ["arith.extui";"arith.index_castui"] then Mlir_scalar.unsigned else Mlir_scalar.signed in
              [Scalar (Mlir_scalar.int (integer (ty (result_id ()))) (extend (integer (ty (List.hd op.operands))) (z a)))]
          | ("arith.addf"|"arith.maximumf"|"arith.maxnumf"),[a;b]->
              let x=real (scalar a) and y=real (scalar b) in
              [T.float (match code with "arith.addf"->x+.y | "arith.maximumf"->Float.max x y | _->Float.max_num x y)]
          | ("affine.min"|"affine.max"|"affine.apply"),vs->[Scalar (L.affine op (List.map scalar vs))]
          | ("memref.alloc"|"memref.alloca"|"tensor.empty"),vs ->
              [Buffer (Effect.perform (H.Allocate (elem (),Mlir_memory.dimensions (shape ()).shape (List.map scalar vs))))]
          | ("memref.cast"|"bufferization.to_tensor"|"bufferization.to_memref"|"bufferization.to_buffer"),[v]->[v]
          | ("memref.dim"|"tensor.dim"),[Buffer b;axis]->[int b.shape.(number axis)]
          | ("memref.subview"|"tensor.extract_slice"),Buffer b::dynamic -> [Buffer (slice b dynamic (shape ()).shape)]
          | "tensor.insert_slice",Buffer src::Buffer dst::dynamic ->
              let out=clone dst in copy src (slice out dynamic (shaped (List.hd op.operands)).shape); [Buffer out]
          | ("memref.reinterpret_cast"),Buffer b::vs ->
              let offsets,sizes,strides=L.mixed (Lazy.force static_slice) (List.map scalar vs) in
              [Buffer {b with base=b.origin+Z.to_int (List.hd offsets)*width b.element;shape=Array.of_list sizes;strides=dims strides}]
          | ("tensor.expand_shape"|"tensor.collapse_shape"|"memref.expand_shape"|"memref.collapse_shape"),Buffer b::vs ->
              let groups=List.map (fun g->List.map J.to_int (J.to_list g)) (J.to_list (attr "reassociation")) in
              let expand=String.ends_with ~suffix:"expand_shape" code in
              let sizes=if expand then Mlir_memory.dimensions (shape ()).shape (List.map scalar vs)
                else List.map (List.fold_left (fun n axis->n*b.shape.(axis)) 1) groups in
              let strides=if expand then List.concat (List.mapi (fun axis group->
                List.map (fun x->b.strides.(axis)*Z.to_int x) (Mlir_memory.strides (List.map (List.nth sizes) group))) groups)
                else List.map (fun group->let active=List.filter (fun i->b.shape.(i)>1) group in
                  b.strides.(List.hd (List.rev (if active=[] then group else active)))) groups in
              [Buffer {b with shape=Array.of_list sizes;strides=Array.of_list strides}]
          | "memref.extract_strided_metadata",[Buffer b] ->
              Buffer {b with shape=[||];strides=[||];base=b.origin}::int ((b.base-b.origin)/width b.element)::
              List.map int (Array.to_list b.shape@Array.to_list b.strides)
          | ("memref.load"|"tensor.extract"),Buffer b::ix->[Effect.perform (H.Load (b,num ix))]
          | "memref.store",v::Buffer b::ix->Effect.perform (H.Store (b,num ix,v));[]
          | "tensor.insert",v::Buffer b::ix -> let out=clone b in write out (position out (num ix)) v;[Buffer out]
          | "memref.atomic_rmw",v::Buffer b::ix->
              let off=position b (num ix) in let old=read b off in
              if not (List.mem (attr "kind") [`Int 0;`String "addf"]) then invalid_arg "unsupported atomic kind";
              write b off (T.binary "add" old v);[old]
          | "hivm.hir.pointer_cast",vs ->
              let t=shape () in let dyn=List.length (List.filter Option.is_none t.shape) in
              let n=List.length vs-dyn in let offsets=List.take n vs and rest=List.drop n vs in
              let shape=Array.of_list (Mlir_memory.dimensions t.shape (List.map scalar rest)) in
              let bank=Option.get t.space in
              let base=number (List.nth offsets (ordinal mod n)) and element=elem () in
              let descriptor=Mlir_memory.descriptor ast t (Array.to_list shape) () in
              let need=Mlir_memory.size {descriptor with base_bytes=base} in
              let s=local_storage core.block (if L.space t.space=6 then Some core.core else None) bank need in
              [Buffer {storage=s;shape;element;origin=base;base=base+Z.to_int descriptor.offset*width element;
                       strides=dims descriptor.strides}]
          | "hivm.hir.multi_buffer_counter",[] -> [int ordinal]
          | "hivm.hir.get_block_idx",[] -> [int (Effect.perform Effects.Core_location).block]
          | "hivm.hir.get_sub_block_idx",[] -> [int (match (Effect.perform Effects.Core_location).core with Cube->0 | Vector n->n)]
          | "hivm.hir.set_ctrl",[] -> Hashtbl.replace controls.(stream.id) (attr "idx") (attr "enable");[]
          | "annotation.mark",_ | "hivm.hir.set_mask_norm",[] -> []
          | ("hivm.hir.set_flag"|"hivm.hir.wait_flag"|"hivm.hir.sync_block_set"|"hivm.hir.sync_block_wait"),vs ->
              let cross=String.starts_with ~prefix:"hivm.hir.sync_block" code in
              let send=List.mem code ["hivm.hir.set_flag";"hivm.hir.sync_block_set"] in
              let src=pipe op (if cross then "tpipe" else "set_pipe") and dst=pipe op (if cross then "pipe" else "wait_pipe") in
              let event=match vs with [x]->number x | []->(match attr (if cross then "static_flag_id" else "static_event_id") with
                | `Int n->n | x->let s=L.enum x in int_of_string (String.sub s 8 (String.length s-8)))
                | _->invalid_arg "invalid synchronization operands" in
              let peers=if cross then (if send then fst else snd) peers.(stream.id) else [stream.id] in
              let paired=peers<>[] && List.for_all (fun i->let other=locations.(i) in
                other.block=core.block && (other.core=Cube)<>(core.core=Cube)) peers in
              let keys=if cross && not paired then
                (if send then peers else [stream.id]) |> List.map (fun b-> -1,b,src,dst,event)
                else List.map (fun peer->let a,b=if send then stream.id,peer else peer,stream.id in a,b,src,dst,event) peers in
              let pipe=if send then src else dst in
              Q.submit ~blocking:(pipe="S") pipe site (if send then Q.Set keys else Q.Wait keys);[]
          | "hivm.hir.pipe_barrier",[] | "hfusion.barrier",[] ->
              let pipes=if code="hfusion.barrier" then ["HFUSION_ASYNC"] else
                match L.enum (attr "pipe") with "PIPE_ALL"->["M";"V";"FIX";"MTE1";"MTE2";"MTE3"]
                | _->[pipe op "pipe"] in List.iter (fun p->Q.submit ~blocking:(code="hfusion.barrier") p site Q.Barrier) pipes;[]
          | "hivm.hir.nd2nz",[Buffer src;Buffer dst] -> transfer "MTE2" (fun ()->
              for r=0 to src.shape.(0)-1 do for c=0 to src.shape.(1)-1 do
                write dst (position dst [c/16;r/16;r mod 16;c mod 16]) (T.read_at src [r;c]) done done)
          | "hivm.hir.fixpipe",[Buffer src;Buffer dst] when attr "dual_dst_mode"<>`Null && L.enum (attr "dual_dst_mode")="ROW_SPLIT" ->
              transfer "FIX" (fun ()->for sub=0 to 1 do
                let b={dst with storage=local_storage core.block (Some (Vector sub)) "#hivm.address_space<ub>"
                    (dst.base+size dst.shape*width dst.element)} in
                for i=0 to b.shape.(0)-1 do for j=0 to b.shape.(1)-1 do
                  let r=sub*b.shape.(0)+i in
                  write b (position b [i;j]) (T.read_at src [j/16;r/16;r mod 16;j mod 16]) done done done)
          | "hivm.hir.mmadL1",Buffer a::Buffer b::init::m::k::n::Buffer dst::events when op.results=[] ->
              let m=number m and k=number k and n=number n in
              let nz buf i j=T.read_at buf [j/16;i/16;i mod 16;j mod 16] in
              let buf shape=create F32 shape in
              let left=buf [m;k] and right=buf [k;n] and output=buf [m;n] in
              let flag send src dst event=if event>=0 then Q.submit (if send then src else dst) site
                ((if send then (fun k->Q.Set k) else (fun k->Q.Wait k)) [stream.id,stream.id,src,dst,event]) in
              let sync send src dst n=flag send src dst (number n) in
              (match events with []->() | [wa;wb;_;_;_;_;_]->sync false "MTE2" "MTE1" wa;sync false "MTE2" "MTE1" wb;
                flag false "M" "MTE1" 0 | _->invalid_arg "unsupported matrix flags");
              work "MTE1" (fun ()->for i=0 to m-1 do for j=0 to k-1 do put left (i*k+j) (nz a i j) done done;
                for i=0 to k-1 do for j=0 to n-1 do put right (i*n+j)
                  (if attr "b_transpose"<>`Null then nz b j i else nz b i j) done done);
              (match events with [_;_;sa;sb;db;b0;b1]->sync true "MTE1" "MTE2" sa;sync true "MTE1" "MTE2" sb;
                if List.exists (fun v->number v <> -1) [db;b0;b1] then invalid_arg "unsupported matrix double buffering"
                | _->());
              let key=[stream.id,stream.id,"MTE1","M",internal_event] in
              Q.submit "MTE1" site (Q.Set key);Q.submit "M" site (Q.Wait key);
              work "M" (fun ()->let clear=Mlir_scalar.boolean (scalar init) in
                if not clear then (for i=0 to m-1 do for j=0 to n-1 do put output (i*n+j) (nz dst i j) done done);
                T.matmul left right output ~transpose:false ~initialize:clear;
                for i=0 to m-1 do for j=0 to n-1 do write dst (position dst [j/16;i/16;i mod 16;j mod 16]) (get output (i*n+j)) done done);
              if events<>[] then flag true "M" "MTE1" 0;[]
          | ("memref.copy"|"linalg.copy"|"bufferization.materialize_in_destination"|"hivm.hir.load"|"hivm.hir.store"|"hivm.hir.copy"|"hivm.hir.fixpipe"),[Buffer a;Buffer b] ->
              let p=match code with "hivm.hir.load"->"MTE2"|"hivm.hir.store"|"hivm.hir.copy"->"MTE3"
                |"hivm.hir.fixpipe"->"FIX"|"bufferization.materialize_in_destination"->"S"|_->target in
              if op.results=[] then (work p (fun ()->observe a;Effect.perform (H.Copy (a,b)));[])
              else [Buffer (clone a)]
          | "hivm.hir.load",Buffer a::Buffer b::pad::rest ->
              transfer "MTE2" (fun ()->observe a;let left=match rest with []->0 | [n]->number n | _->invalid_arg "load padding" in
                for i=0 to size b.shape-1 do put b i (if i>=left && i-left<size a.shape then get a (i-left) else pad) done)
          | "hivm.hir.custom",[Buffer data;Buffer ix;Buffer values;Buffer mask;Buffer out]
            when attr "symbol"=`String "__builtin_indirect_atomic" && attr "extra_attr"=`String "operate=add" ->
              transfer (pipe op "hivm.pipe") (fun ()->for i=0 to size mask.shape-1 do
                if number (get mask i)<>0 then (let j=number (get ix i) in
                  let old=read data (position data [j]) in let v=get values i in
                  write data (position data [j]) (T.binary "add" old v);put out i old) done)
          | ("hfusion.print"|"hivm.hir.debug"),[Buffer b] ->
              let label=match attr "prefix" with `String s->s | _->code in
              let values=List.init (size b.shape) (fun i->Printf.sprintf "%g" (real (scalar (get b i)))) in
              Printf.eprintf "%s %s\n" label (String.concat "," values);[]
          | "hfusion.indirect_load",[Buffer base;Buffer offsets;Buffer third;Buffer fourth;Buffer fifth] ->
              let mask,other,dst=if op.generic then fourth,fifth,third else third,fourth,fifth in
              let out=create dst.element (Array.to_list dst.shape) in
              for i=0 to size out.shape-1 do put out i (if number (get mask i)<>0 then
                T.read_at base [number (get offsets i)] else get other i) done;[Buffer out]
          | "hfusion.indirect_store",[Buffer first;Buffer offsets;Buffer third;Buffer fourth] ->
              let base,mask,src=if op.generic then first,fourth,third else fourth,third,first in
              transfer target (fun ()->for i=0 to size src.shape-1 do if number (get mask i)<>0 then
                write base (position base [number (get offsets i)]) (get src i) done)
          | ("ave.hir.vload"|"ave.hir.masked_store"|"ave.hir.store_with_stride"),_ ->
              let widths=List.map (fun (id,_)->List.fold_left (fun n d->n*Option.get d) 1 (shaped id).shape) op.results in
              Effect.perform (H.Register_transfer (op,args,widths))
          | _ when String.starts_with ~prefix:"ave.hir." code ||
              List.mem code ["vector.bitcast";"llvm.bitcast";"builtin.unrealized_conversion_cast"] ->
              let element_of id=match ty id with M.Shaped t->element ast t.element | _->element ast (Hashtbl.find types id) in
              let input_type=match op.operands with []->elem () | id::_->element_of id in
              let count=List.fold_left (fun n d->n*Option.get d) 1 (shape ()).shape in
              Effect.perform (H.Register_operation (op,args,{element=elem ();input_type;count}))
          | _ when List.mem code (L.linalg_ops@L.hfusion_ops@L.vector_ops@["hivm.hir.matmul";"hivm.hir.mmadL1"]) ->
              (* A suspended reduction retains the scalar SSA values of its iteration.
                 Buffer values in the frame continue to share their physical storage. *)
              let scope=if op.results=[] && Array.length regions>0 && not nested then Array.copy frame else frame in
              let run ()=
                (match args with Buffer b::_->observe b | _->());
                let combine a b=mapped (fun ()->List.hd (regions.(0).(0) scope nested ordinal [a;b])) in
                Effect.perform (H.Tensor_operation (op,args,combine)) in
              if op.results<>[] then run () else (
                let p=if launch.hfusion then target else if code="hivm.hir.vbrc" &&
                  L.space (shaped (List.hd (List.rev op.operands))).space=2 then "MTE2" else "V" in
                work p (fun ()->ignore (run ()));[])
          | _->invalid_arg ("unsupported source operation "^code) in
        fun frame nested ordinal ->
          Effect.perform (Effects.Source_step site);
          let args=List.map (Array.get frame) op.operands in
          if List.mem code ["func.return";"scf.yield";"scf.condition";"linalg.yield"] then Some args else
          (env_bind frame op.results (f frame nested ordinal args);None)
      and numeric_args args=List.map number args in
      let execute=block [] body in
      fun nested args->execute (Array.make total (int 0)) nested 0 args in
    List.iter (fun (entry,fn)->if fn.M.regions<>[[]] then Hashtbl.add functions entry (prepare entry)) ast.functions;
    functions in
  let make_stream (stream:Launch.stream) =
    let bind (arg_id,v)=match v with C.VBuffer ({storage=Some (Input id);_} as b)->
        let elem=element ast (Mlir_memory.shaped ast (List.assoc arg_id stream.ast.arguments)).element in
        Buffer {storage=banks.(id);element=elem;origin=b.base_bytes;base=b.base_bytes+Z.to_int b.offset*b.element_bytes;
          shape=Array.of_list b.shape;strides=dims b.strides}
      | _->Scalar v in
    fun ()->mapped (fun ()->let id=Effect.perform Effects.Instance_id in
      returned.(id)<-(Hashtbl.find functions stream.entry) false (List.map bind stream.arguments)) in
  let entries=Array.map make_stream streams in
  let tasks=ref 0 in
  let status=try match schedule (fun ()->Q.drive state launch.capacity tasks entries) with
    | Q.Returned->Finished | Deadlock sites->Blocked sites
    with Memory_fault reason->Invalid_memory (!current^": "^reason) | Budget site->Step_limit site
       | Invalid_argument reason->invalid_arg (!current^": "^reason) in
  {status;steps= !steps;tasks= !tasks;returned;memory=Array.to_list (Array.map (fun b->b.name,b.data) banks)}
