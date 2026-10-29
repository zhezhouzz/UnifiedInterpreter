type t = { name : string; stem : string; bindings : (string * Kernel.binding) list;
           expected : float array }

let get = function
  | "vector-add" ->
      let a = [|-3.;-1.;0.;0.5;2.;4.;8.;16.|] in
      let b = [|1.;2.;3.;4.;-2.;-4.;0.25;-0.5|] in
      {name="vector-add";stem="vector_add";
       bindings=["%a",Kernel.Input a;"%b",Kernel.Input b;"%out",Kernel.Output];
       expected=Array.map2 ( +. ) a b}
  | "row-sum" ->
      let input = [|1.;2.;3.;4.; -1.;0.;1.;2.; 0.5;0.25;-0.5;-0.25|] in
      {name="row-sum";stem="row_sum";
       bindings=["%input",Kernel.Input input;"%out",Kernel.Output];
       expected=Array.init 3 (fun row ->
         let total = ref 0. in
         for col = 0 to 3 do total := !total +. input.(row*4+col) done;
         !total)}
  | _ -> invalid_arg "kernel must be vector-add or row-sum"

let file example stage = "examples/kernels/" ^ example.stem ^ "_" ^ stage ^ ".mlir"
