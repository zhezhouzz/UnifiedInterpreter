module Ast = Hivm_trace.Module_ast
type stage = Hivm_trace.Source.stage = HFusion | HIVM
let stage_name = Hivm_trace.Source.stage_name
let generate = Hivm_trace.Source.report_for_launch
