type backend = Search | Solve

type race_witness = Race_schedule.Result.race_witness = {
  first : Core_lang.occurrence;
  second : Core_lang.occurrence;
  conflicts : Core_lang.address list;
  first_then_second : Core_lang.event list;
  second_then_first : Core_lang.event list;
}

type bug_trace_set = { races : race_witness list; truncated : bool }

(** 每对完成顺序可以交换的冲突访问，各返回能够延伸到原程序结束的一条最短前缀。
    Search 为默认后端。两种后端省略 loop_bound 时，
    根据具体入口实参展开每个 For，直到循环结束或遇到 Return。
    显式传入的 loop_bound 限制前缀可以包含的循环轮数，后续仍使用原始入口实参。
    capacity 是每个令牌键的计数容量，默认值为 1。
    truncated 表示实际可达的控制前缀在仍有下一轮时达到上界。 *)
val generate_bug_traces : ?backend:backend -> ?loop_bound:int -> ?capacity:int -> Core_lang.program -> bug_trace_set

(** 按具体入口参数重放前缀，可指定循环展开上界。遇到非法事件抛出 Invalid_argument。 *)
val replay : ?loop_bound:int -> ?capacity:int -> Core_lang.program -> Core_lang.event list -> unit

module Symbolic : sig
  type expr = Historical_lang.expr =
    | Arg of int | Const of Core_lang.value
    | Add of expr * expr | Sub of expr * expr | Mul of expr * expr
    | Mod of expr * int | Eq of expr * expr | Lt of expr * expr
    | Select of expr * expr * expr | Event of expr
    | Input_slice of int * expr * expr
    | Subview of expr * expr * expr
    | Remainder of expr * expr
  type family = Historical_lang.family = {
    streams : Core_lang.stream list;
    parameter : (int * int) list;
    scalar : int -> int -> expr;
    access : int -> int -> int -> expr list * expr list;
    block_edge : int -> int -> int -> Core_lang.endpoint -> bool;
  }

  (** 将同一个非负 N 绑定到 parameter 中各个 (stream, variable) 入口。 *)
  val instantiate : family -> Z.t -> Core_lang.program
end

type symbolic_result =
  | Race of { n : Z.t; witness : race_witness }
  | No_race
  | Unknown of string

(** 省略 launch_n 时查询是否存在有竞争的非负入口参数 N。
    指定 launch_n 时只查询该输入，返回的 n 表示两个方向的前缀所需的循环轮数。
    No_race 表示在查询范围内均无竞争。timeout_ms 是单次查询的毫秒预算，
    默认值为 5000，0 表示无限制。无法判定时返回 Unknown。 *)
val find_symbolic_race : ?launch_n:Z.t -> ?timeout_ms:int -> Symbolic.family -> symbolic_result
