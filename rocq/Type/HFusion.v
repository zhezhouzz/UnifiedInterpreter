(* Ascend/HIVM address spaces are dialect-specific type attributes, not MLIR
   builtin types. The raw parser may encounter their textual spelling, but the
   typed semantic IR uses this closed representation and rejects unknown cases
   during elaboration. *)
Inductive address_space :=
| ASDefault
| ASGM
| ASL1
| ASL0A
| ASL0B
| ASL0C
| ASUB
| ASSSBUF
| ASFixBUF
| ASBiasBUF.
