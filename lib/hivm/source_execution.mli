type status = Unified_interpreter.Dispatch.status =
  | Finished
  | Blocked of string list
  | Invalid_memory of string
  | Step_limit of string

type result = {
  status : status;
  memory : (string * bytes) list;
  returned : Execution_value.t list array;
  steps : int;
  tasks : int;
}

(** 以 launch 配置初始化独立的内存和执行流，执行解析得到的 HFusion 或 HIVM 模块。
    memory 保存各个具名输入存储的最终字节，returned 按执行流编号保存函数返回值。
    tasks 统计已经完成的管线操作，包括同步操作。trace 接收执行流编号和当前指令位置。
    on_read 用于观察批量复制和结构化计算的输入视图，视图内容应在回调期间读取。 *)
val run_module :
  ?choose:Unified_interpreter.Dispatch.choose ->
  ?quiet:bool ->
  ?trace:(int -> string -> unit) ->
  ?on_read:(int -> string -> Execution_value.view -> unit) ->
  ?max_steps:int ->
  stage:string -> launch:Yojson.Safe.t -> Hivm_module.t -> result
