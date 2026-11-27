module Source = Source_scheduler
module Catalog = Catalog_scheduler
module Ast = Source.Ast
type stage = Source.stage = HFusion | HIVM
let generate_mlir = Source.generate

type program = Catalog.program =
  | Tensor of Hfusion_trace.t
  | Device of Hivm_trace.pairing
  | Module of stage * Ast.t * Yojson.Safe.t
let explicit = Catalog.explicit
let generate = Catalog.generate
let replay_module = Catalog.replay_module
