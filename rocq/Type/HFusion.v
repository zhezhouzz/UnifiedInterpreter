From Stdlib Require Import String.
From UnifiedInterpreter.Type Require Import MLIR.

Open Scope string_scope.

(* Ascend/HIVM address spaces are dialect-specific type attributes, not MLIR
   builtin types. Keeping the semantic enumeration here lets memory semantics
   use a checked representation while Type/MLIR represents the corresponding
   source attribute generically. *)
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

Definition address_space_payload (space : address_space) : string :=
  match space with
  | ASDefault => "default"
  | ASGM => "gm"
  | ASL1 => "l1"
  | ASL0A => "l0a"
  | ASL0B => "l0b"
  | ASL0C => "l0c"
  | ASUB => "ub"
  | ASSSBUF => "ssbuf"
  | ASFixBUF => "fixbuf"
  | ASBiasBUF => "biasbuf"
  end.

Definition address_space_attribute (space : address_space) : mlir_attribute :=
  DialectAttr "hivm" "address_space" (address_space_payload space).
