open Unified_interpreter
type pipe = Core_lang.Device.pipe = S | V | M | MTE1 | MTE2 | MTE3 | FIX
type origin = { path : int list; opcode : string; part : string option }
type location = { stream : int; entry : string; origin : origin; iterations : int list }
type task = { id : int; pipe : pipe }
type signal = { receiver : int; source : pipe; target : pipe; flag : int; cross : bool }
type action = Compute | Allocate | Set of signal list | Wait of signal
            | Wait_all of int list * signal | Barrier
type phase = Submit of task list | Complete of task | Execute of pipe option
type event = { location : location; action : action; phase : phase }
type race = { first : event; second : event; forward : event list; reverse : event list }
type status = Complete_search | Race_found | No_race | Unknown of string
type report = {
  benchmark : string; streams : (int * string) list; n : Z.t option;
  inputs : Yojson.Safe.t; status : status; races : race list;
}
