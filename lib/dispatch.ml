type phase = Submit | Complete | Execute
type event = {stream:int; site:string; pipe:string; occurrence:int; phase:phase}
type choose = event list -> event
type status = Finished | Blocked of string list | Invalid_memory of string | Step_limit of string

let site entry path opcode =
  Printf.sprintf "%s/%s %s" entry (String.concat "." (List.map string_of_int path)) opcode

let encode e : Yojson.Safe.t =
  let phase = match e.phase with Submit -> "submit" | Complete -> "complete" | Execute -> "execute" in
  `List [`Int e.stream; `String e.site; `String e.pipe; `Int e.occurrence; `String phase]

let decode = function
  | `List [`Int stream;`String site;`String pipe;`Int occurrence;`String s] ->
      let phase=match s with "submit"->Submit | "complete"->Complete | "execute"->Execute
        | _->invalid_arg "unknown dispatch phase" in
      {stream;site;pipe;occurrence;phase}
  | _ -> invalid_arg "invalid dispatch event"
