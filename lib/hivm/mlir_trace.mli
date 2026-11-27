type lowered_mlir = Core_mlir of Mlir_lowering.t | Device_mlir of Mlir_device.t
val lower_mlir : ?entry:string -> ?configuration:Yojson.Safe.t -> ?allow_prefix:bool ->
  Hivm_module.t -> lowered_mlir
val analyze_mlir : ?timeout_ms:int -> backend:Unified_interpreter.Bug_traces.backend ->
  ?hivm:bool -> lowered_mlir -> Yojson.Safe.t
val project_mlir : lowered_mlir -> Yojson.Safe.t -> Yojson.Safe.t
val replay_mlir : lowered_mlir -> Yojson.Safe.t -> int
val source_event_order : Mlir_lowering.t -> (Yojson.Safe.t * int list) array * (int * int) list
