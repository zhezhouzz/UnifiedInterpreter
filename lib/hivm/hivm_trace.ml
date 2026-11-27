include Hivm_event
include Catalog_trace
module Mlir = Mlir_lowering
module Mlir_device = Mlir_device
module Execution = Source_execution
module Execution_value = Execution_value
module Source = Mlir_trace
include Mlir_trace
let to_json = Trace_projection.to_json
