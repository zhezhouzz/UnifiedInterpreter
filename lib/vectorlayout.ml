open Device_ast

type variant = Ok | Fail
let variant_name = function Ok -> "ok" | Fail -> "fail"
let i n = Int (I32,Int64.of_int n)
let v x = Var x
let z = i 0
let one = i 1
let ( +: ) x y = Binary (Add,x,y)
let ( -: ) x y = Binary (Sub,x,y)
let ( *: ) x y = Binary (Mul,x,y)
let div x y = Binary (Div,x,y)
let rem x y = Binary (Rem,x,y)
let min_ x y = Binary (Min,x,y)
let max_ x y = Binary (Max,x,y)
let lt x y = Compare (Lt,x,y)
let both x y = Binary (And,x,y)
let loop index hi step body =
  For {index;index_type=I32;lo=z;hi;step=i step;carried=[];body;yield=[]}
let row = v "row" and col = v "col" and t = v "t"
let rows body = loop "row" (i 32) 1 body
let chunks body = loop "col" (i 128) 64 body
let tile_shape = [32;128]
let ptr space ty byte shape =
  Buffer (space,ty,byte,List.map i shape,[])
let ub ty offset shape = ptr UB ty (i offset) shape
let load a ix = Read (a,ix,1)
let vector a n = Read (a,[z],n)
let all_lanes grain n = Layout_cast ({element=I1;lane_bits=grain},Pge n)
let set src dst e = Set (Local,src,dst,e)
let wait src dst e = Wait (Local,src,dst,e)
let send src dst e = Set (Cross,src,dst,e)
let receive src dst e = Wait (Cross,src,dst,e)
let work pipe name body = Issue (pipe,name,body)
type query_buffers = {
  column : int; offsets : int; mask : int; other : int; gathered : int; scale : int;
}
let query_buffers = function
  | Ok -> {column=17440;offsets=21568;mask=17472;other=1056;gathered=54336;scale=62528}
  | Fail -> {column=1056;offsets=1088;mask=33856;other=37952;gathered=46144;scale=54336}
let column_idx = ub I32 0 [128]
let head_local = ub I32 512 [32]
let token = ub I32 640 [32]
let qhead = ub I32 768 [32]
let row_valid = ub I1 896 [32]
let clipped = ub I32 928 [32]
let predicate = ub I1 512 [32]
let qoffset32 = ub I32 1056 tile_shape
let row_output = ub I32 768 [32]
let gm arg = v ("arg" ^ string_of_int arg)
let arg = gm
let span = v "count"
let start = v "first"
let rotate addresses counter =
  let n = List.length addresses in
  let rec choose k = function
    | [] -> invalid_arg "empty buffer rotation"
    | [a] -> i a
    | a::rest -> Select (Compare (Eq,rem counter (i n),i k),i a,choose (k+1) rest) in
  choose 0 addresses

(* GraphSyncSolver：vf_2、fused_4、vf_3、fused_6 和 fused_5。 *)
let query variant =
  let {column;offsets;mask;other;gathered=dst;scale} = query_buffers variant in
  let mask = ub I8 mask tile_shape and other = ub F16 other tile_shape in
  let offsets = ub I64 offsets tile_shape and column = ub I1 column [128] in
  let row_head = Range (Subblock *: i 32,32) in
  let base = load clipped [row] *: arg 17 +: load qhead [row] *: arg 18 in
  let offsets_body out convert =
    rows [Let ("base",base);chunks [
      Store (out,[row;col],convert (v "base" +: Read (column_idx,[col],64)))]] in
  let cast_offset x = Cast (I64,x) in
  let setup =
    [work V "outlined_vf_2" [chunks [Store (column_idx,[col],Range (col,64))]];
     work V "fused_4.vf_0" [
       Let ("lane",row_head);
       Store (head_local,[z],rem (v "lane") (i 2));
       Store (token,[z],div (v "lane") (i 2) +: v "qstart" +: v "qblock" *: i 32)];
     work V "fused_4.vf_1" [
       Store (qhead,[z],vector head_local 32 +: v "kvhead" *: arg 12);
       Store (row_valid,[z],lt (vector token 32) (v "qend"));
       Store (clipped,[z],max_ (v "qstart") (min_ (vector token 32) (v "qend" -: one)))]] in
  let debug src prefix = [set V S z; wait V S z;work S "device_print" [Debug (prefix,src)]] in
  let offsets_and_predicate =
    let validity = Store (predicate,[z],both (vector row_valid 32) (lt (vector head_local 32) (arg 12))) in
    let cols = work V "outlined_vf_3" [chunks [
      Store (column,[col],lt (Read (column_idx,[col],64)) (arg 13))]] in
    match variant with
    | Ok -> [work V "fused_6.vf_0" [offsets_body qoffset32 Fun.id]]
      @ debug qoffset32 "q_offsets" @ [set S V z;cols;work V "fused_5.vf_0" [validity];wait S V z]
    | Fail -> debug clipped "q_token_flat" @
      [cols;work V "fused_6.merged_vf_0" [offsets_body offsets cast_offset;validity]] in
  let mask_mode,mask_bits,other_mode,other_bits = match variant with
    | Ok -> Pk,16,Norm,16 | Fail -> Pk4,32,Pk,32 in
  let byte x = Int (I8,Int64.of_int x) in
  let half x = Float (F16,x) in
  let nonzero x = Compare (Ne,x,half 0.) in
  let fold_predicate = List.concat (List.init 8 (fun _ ->
    [Interleave ("low","high",v "selected",v "zeros");
     Let ("selected",Binary (Xor,v "low",v "high"))])) in
  let mask_row = rows ([
    (* PLDS 从压缩的 UB 谓词区读取 256 位，PLT 选择当前行。 *)
    Let ("bits",vector (ub I1 512 [256]) 256);
    Let ("zeros",Broadcast (byte 0,256));
    Let_plt ("through","after",256,row +: one);Let_plt ("before","remaining",256,row);
    Let ("at_row",Binary (Xor,v "through",v "before"));
    Let ("selected",Select (v "at_row",Select (v "bits",byte 1,byte 0),v "zeros"))]
    @ fold_predicate @ [
    Let ("row_pred",Layout_cast ({element=I1;lane_bits=mask_bits},
        Compare (Ne,Splat_lane (v "selected",0,128),byte 0)));
    Let ("enabled",both (nonzero (Select (v "row_pred",half (-1.),half 0.))) (v "columns"));
    Let ("bytes",Select (v "enabled",Int (I8,1L),Int (I8,0L)));
    Masked_store (mask,[row;z],all_lanes mask_bits 128,
      Layout_cast ({element=I8;lane_bits=mask_bits},v "bytes"),mask_mode)]) in
  let zeroes n = Layout_cast ({element=F16;lane_bits=other_bits},Broadcast (Float (F16,0.),n)) in
  let fill_other = match variant with
    | Fail -> rows [Masked_store (other,[row;z],all_lanes other_bits 128,zeroes 128,other_mode)]
    | Ok -> rows [chunks [
        Masked_store (offsets,[row;col],all_lanes 32 64,
          Register_group (2,cast_offset (Read (qoffset32,[row;col],64))),Norm);
        Masked_store (other,[row;col],all_lanes other_bits 64,zeroes 64,other_mode)]] in
  let scalar = ub F32 scale [1] in
  setup @ offsets_and_predicate @
    [work V "fused_5.merged_vf_0" [
       Let ("columns",nonzero (Select (vector column 128,half (-1.),half 0.)));mask_row;fill_other];
     work V "indirect_load" [Indirect_load (gm 2,offsets,mask,other,ub F16 dst tile_shape)];
     work S "memref.store.scale" [Store (scalar,[z],arg 16)];
     set S V z; wait S V z;
     work V "fused_7.vf_0" [Store (scalar,[z], load scalar [z] *: Float (F32,1.44269502))];
     set V S z;wait V S z;Let ("scale",load scalar [z]);
     work V "fused_8.vf_0" [Store (row_output,[z],
       vector token 32 *: arg 24 +: vector qhead 32 *: arg 23)]]

let accumulator = ptr L0C F32 z [8;4;16;16]
let key = ptr L1 F16 (i 16384) [8;8;16;16]
let matrix_a = ptr L0A F16 z [8;4;16;16]
let matrix_b = ptr L0B F16 z [8;8;16;16]
let pingpong_q bases = ptr L1 F16 (rotate bases (v "counter")) [8;4;16;16]
let scores variant space incoming =
  let lo,hi = match variant with Ok -> 62560,105728 | Fail -> 54368,97536 in
  ptr space F32 (rotate (if incoming then [lo;hi] else [hi;lo]) (v "counter")) tile_shape
let slot3 variant consumed ty shape strides fail_addrs ok_addrs =
  let slots = match variant with Fail -> fail_addrs | Ok -> ok_addrs in
  let slots = match slots,consumed with [a;b;c],true -> [b;c;a] | _ -> slots in
  Buffer (UB,ty,rotate slots (v "counter"),List.map i shape,List.map i strides)
let meta variant consumed =
  let slot ty shape strides a b = slot3 variant consumed ty shape strides a b in
  (slot I1 tile_shape [256;1] [70752;113920;114944] [78944;122112;123136],
   slot I32 tile_shape [] [71776;115968;132352] [79968;124160;140544],
   slot I64 [32] [] [88160;148736;148992] [96352;156928;157184],
   slot F32 [32] [] [88416;149248;149376] [96608;157440;157568],
   slot I8 [32] [] [88544;149504;149536] [96736;157696;157728])

let negative_inf = Float (F32,neg_infinity)
let valid_stage phase = both (Compare (Ge,phase,z)) (lt phase span)
let cube_iteration variant =
  let delta = t -: one in
  let h = v "key_rows" and w = v "key_cols" in
  let src = Strided_view (gm 3,v "key_base",[i 128;i 128],[arg 20;one]) in
  let key_src = Slice (src,[z;z],[h;w],[one;one]) in
  [Let ("counter",Cast (I32,Counter "preload"));
   If (valid_stage delta,[
     Let ("page",start +: delta);
     Let ("page_id",load (gm 4) [v "batch" *: arg 22 +: v "page"]);
     Let ("key_base",Cast (I64,v "page_id") *: Cast (I64,arg 19)
          +: Cast (I64,v "kvhead" *: arg 21));
     Let ("key_rows",max_ z (min_ (i 128) (v "kvlen" -: v "page" *: i 128)));
     Let ("key_cols",max_ z (min_ (i 128) (arg 13)));
     If (Binary (Or,lt h (i 128),lt w (i 128)),[
       set MTE1 MTE2 z;wait MTE1 MTE2 z;work MTE2 "vbrc.key" [Fill (key,Float (F16,0.))];
       Barrier [MTE2]],[]);
     wait MTE1 MTE2 one;
     work MTE2 "nd2nz" [Nd2nz (key_src,key)];set MTE2 MTE1 z;
     receive MTE3 MTE1 z;wait FIX M z;
     (* MMAD 的 sync_related_args 包含 MTE2 -> MTE1 等待和归还事件。 *)
     wait MTE2 MTE1 z;wait M MTE1 z;
     work MTE1 "mmadL1.load" [Copy (pingpong_q [0;49152],matrix_a);Copy (key,matrix_b)];
     set MTE1 MTE2 one;set MTE1 M z;wait MTE1 M z;
     work M "mmadL1" [Mmad (matrix_a,matrix_b,accumulator,Int (I1,1L),64,128,128,true)];
     set M MTE1 z;
     set M FIX z; send MTE1 MTE3 (one +: rem (v "counter" +: one) (i 2));
     receive V FIX (one +: rem (v "counter" +: one) (i 2));wait M FIX z;
     work FIX "fixpipe" [Fixpipe_row_split (accumulator,
       scores variant (Vector_ub 0) true,scores variant (Vector_ub 1) true)];
     set FIX M z; send FIX V z],[])]

let vector_iteration variant =
  let dst = (query_buffers variant).gathered in
  let temp,columns = match variant with Fail -> 88576,97024 | Ok -> 96768,105216 in
  let temp_view = Buffer (UB,F16,i temp,[i 8;i 32;i 16],[i 528;i 16;one]) in
  let key_positions = ub I32 columns [128] in
  let prepare =
    let valid,int_mask,offset,result,out_mask = meta variant false in
    let qnz = pingpong_q [49152;0] in
    [wait MTE3 V z;
     work V "fused_1.merged_vf_0" [
       rows [loop "fragment" (i 8) 1 [
         Store (temp_view,[v "fragment";row;z],Read (ub F16 dst tile_shape,[row;v "fragment" *: i 16],16))]];
       Store (key_positions,[z],vector column_idx 128 +: (start +: t) *: i 128)];
     set V MTE3 z;receive MTE1 MTE3 (one +: rem (v "counter") (i 2));wait V MTE3 z;
     work MTE3 "copy.ub_to_l1" [loop "fragment" (i 8) 1 [
       loop "row_block" (i 2) 1 [
         Let ("src",Slice (temp_view,[v "fragment";v "row_block" *: i 16;z],
           [one;i 16;i 16],[one;one;one]));
         Let ("dst",Slice (qnz,[v "fragment";Subblock *: i 2 +: v "row_block";z;z],
           [one;one;i 16;i 16],[one;one;one;one]));
         Copy (Reshape (v "src",[i 256]),Reshape (v "dst",[i 256]))]]];
     set MTE3 V z;send MTE3 MTE1 z;
     work V "fused_0.merged_merged_vf_0" [
       rows [chunks [Let ("positions",Read (key_positions,[col],64));
         Store (valid,[row;col],both (Compare (Ge,load token [row],v "positions"))
           (lt (v "positions") (v "kvlen")))]];
       Fill (int_mask,Int (I32,2147483647L));
       Store (offset,[z],Cast (I64,vector row_output 32 +: start +: t));
       Fill (result,negative_inf);Store (out_mask,[z],Cast (I8,vector predicate 32))]] in
  let consume =
    let valid,int_mask,offset,result,out_mask = meta variant true in
    let inner = For {index="col";index_type=I32;lo=z;hi=i 128;step=i 64;
      carried=["maxima",Broadcast (negative_inf,64)];
      body=[
        Let ("score",Read (scores variant UB false,[row;col],64) *: v "scale");
        Let ("masked",Select (Read (valid,[row;col],64),v "score",negative_inf));
        Let ("magnitude",Binary (And,Bitcast (I32,v "masked"),Read (int_mask,[row;col],64)));
        Let ("nan",Compare (Gt,v "magnitude",i 0x7f800000));
        Let ("filtered",Select (v "nan",negative_inf,v "masked"))];
      yield=[max_ (v "maxima") (v "filtered")]} in
    [receive FIX V z;
     work V "fused_3.vf_0" [rows [inner;
       Store (result,[row],max_ (Reduce_max (v "maxima")) (load result [row]))]];
     send V FIX (one +: rem (v "counter") (i 2));
     work V "indirect_store" [Indirect_store (result,offset,out_mask,gm 9)]] in
  [Let ("counter",Cast (I32,Counter "preload"));If (valid_stage t,prepare,[]);
   If (valid_stage (t -: i 2),consume,[])]

let make variant blocks =
  if blocks < 1 || blocks > 28 then invalid_arg "A5 launch expects 1 to 28 block groups";
  let stream block core =
    let cube = core = Cube in
    let src,dst = if cube then MTE1,MTE3 else V,FIX in
    let pre = if cube then [set M MTE1 z;set M MTE1 one] else [] in
    let active = if cube then [set MTE1 MTE2 one;set FIX M z] else
      [Let ("qstart",load (gm 5) [v "batch"]);Let ("qblock",load (gm 6) [v "batch"]);
       Let ("qend",load (gm 8) [v "batch"])] @ query variant @ [set MTE3 V z] in
    let iterations = if cube then cube_iteration variant else vector_iteration variant in
    let run = loop "t" (span +: i 3) 1 (iterations @ [Advance_counter "preload"]) in
    let drain = if cube then [wait FIX M z;wait MTE1 MTE2 one] else [wait MTE3 V z] in
    let block_loop = For {index="pid";index_type=I32;lo=Block;hi=arg 25 *: arg 26 *: arg 27;step=i 28;
      carried=[];yield=[];body=[
        Control (60,false);Control (48,true);
        Let ("axis0",rem (v "pid") (arg 25));
        Let ("batch",rem (v "axis0") (arg 14));
        Let ("kvhead",rem (div (v "pid") (arg 25)) (arg 26));
        Let ("kvlen",load (gm 7) [v "batch"]);
        Let ("pages",div (v "kvlen" +: i 127) (i 128));
        Let ("part",max_ one (div (v "pages" +: arg 15 -: one) (arg 15)));
        Let ("first",div (v "axis0") (arg 14) *: v "part");
        Let ("count",min_ (v "first" +: v "part") (v "pages") -: v "first");
        If (lt z span,active @ [run] @ drain,[]);Control (60,true)]} in
    let close = if cube then [wait M MTE1 z;wait M MTE1 one] else [] in
    let peer_src,peer_dst = if cube then V,FIX else MTE1,MTE3 in
    {location={block;core};body=[send src dst one;send src dst (i 2)] @ pre @ [block_loop]
       @ close @ [receive peer_src peer_dst one;receive peer_src peer_dst (i 2);Barrier [S;V;M;MTE1;MTE2;MTE3;FIX]]} in
  {name="_prefill_bnsd_score_kernel." ^ variant_name variant;register_bytes=256;
   streams=List.concat (List.init blocks (fun b -> List.map (stream b) [Cube;Vector 0;Vector 1]))}
