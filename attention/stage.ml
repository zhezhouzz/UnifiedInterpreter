type t = Common | HFusion | HIVM

let name = function Common -> "common" | HFusion -> "hfusion" | HIVM -> "hivm"

let of_opcode opcode =
  if String.starts_with ~prefix:"hivm." opcode then HIVM
  else if String.starts_with ~prefix:"hfusion." opcode ||
          String.starts_with ~prefix:"linalg." opcode then HFusion
  else Common
