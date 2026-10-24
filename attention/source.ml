type position = { offset : int; line : int; column : int }
type span = { file : string; start : position; stop : position }
exception Error of span * string
let describe s = Printf.sprintf "%s:%d:%d" s.file s.start.line s.start.column
let fail span message = raise (Error (span, message))
