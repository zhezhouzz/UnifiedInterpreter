(* Public facade preserving the original top-level module names. *)

module Tensor = Tensor
module Language = Language
module Effects = Effects
module Interpreter = Interpreter
module Examples = Examples
module Lowering = Lowering
module Routes = Routes
module Report = Report
module Demo = Demo

module Adapters = Examples
module Runtime = Interpreter
module Top = struct
  include Language
  let pp = Language.pp_top
  let eval = Interpreter.Eval.eval_top
end
module Core = struct
  include Language
  let pp = Language.pp_core
  let eval = Interpreter.Eval.eval_core
end
module Vector = struct
  include Language
  let pp = Language.pp_vector
  let eval = Interpreter.Eval.eval_vector
end
module Mem_async = struct
  include Language
  let pp = Language.pp_mem
  let eval = Interpreter.Eval.eval_mem_async
end
module Example = struct
  type t = unit
  let make () = ()
end
