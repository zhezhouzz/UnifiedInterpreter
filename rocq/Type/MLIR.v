From Stdlib Require Import Bool List ZArith.
From UnifiedInterpreter.Type Require Import HFusion Shape.

(* MLIR IntegerType::SignednessSemantics. [Signless] is the spelling used by
   ordinary [iN] types; signed and unsigned spellings are [siN] and [uiN]. *)
Inductive signedness_semantics := Signless | Signed | Unsigned.

Record strided_layout := {
  layout_offset : option Z;
  layout_strides : list (option Z)
}.

(* Layouts supported by the typed semantic IR. The captured HFusion program
   uses only identity and canonical strided layouts. Real MLIR accepts any
   attribute implementing MemRefLayoutAttrInterface, including affine and
   dialect-defined layouts; the raw parser must reject such a layout during
   elaboration until we add a typed semantic case for it. *)
Inductive memref_layout :=
| IdentityLayout
| StridedLayout (layout : strided_layout).

(* Relationship to real MLIR types
   --------------------------------
   This is the type language accepted by our typed semantic IR, not a
   lossless syntax tree for every MLIR type and attribute. Each constructor
   has semantic content that later interpreters can inspect without comparing
   strings.

   It agrees with real MLIR on the following points:
   - integers are signless, signed, or unsigned;
   - ranked tensors and memrefs contain static or dynamic dimensions;
   - ranked and unranked tensor/memref types are distinct;
   - container element types are recursively MLIR types;
   - vectors distinguish fixed and scalable dimensions;
   - memrefs carry layout and memory-space information.

   Deliberate restrictions relative to real MLIR:
   - ranked tensor encoding attributes are not represented because the current
     HFusion artifact has none;
   - memref layouts are identity or strided, exactly the forms currently used;
   - memref memory spaces are the typed Ascend/HIVM cases from Type/HFusion,
     rather than arbitrary MLIR attributes;
   - arbitrary dialect types, opaque types, and arbitrary attributes are not
     admitted into the typed IR. A future raw parser may preserve their text,
     but elaboration must either translate them to a typed constructor or
     report UnsupportedType/UnsupportedAttribute;
   - attributes seen in the current HFusion artifact but attached to arguments,
     operations, or functions (hacc.arg_type, tt.tensor_kind,
     linalg.binary_fn, hfusion.type_fn/round_mode, and function execution
     modes) are not type attributes; HFusion/Instr gives each a separate typed
     constructor;
   - legality constraints (positive integer width, valid complex element,
     matching vector/scalable ranks, and legal container element types) belong
     to a separate verifier rather than to these constructors.

   Scalar backends consume the same [mlir_type] values. Their implementation
   domain is restricted by elaboration to MLIR scalar element types; there is
   no second interpreter-specific type language. *)
Inductive mlir_type :=
| IndexType
| IntegerType (width : nat) (signedness : signedness_semantics)
| Float16Type
| BFloat16Type
| Float32Type
| Float64Type
| ComplexType (element_type : mlir_type)
| RankedTensorType (dimensions : shape) (element_type : mlir_type)
| UnrankedTensorType (element_type : mlir_type)
| VectorType (dimensions : list nat) (scalable : list bool)
    (element_type : mlir_type)
| RankedMemRefType (dimensions : shape) (element_type : mlir_type)
    (layout : memref_layout) (memory_space : address_space)
| UnrankedMemRefType (element_type : mlir_type)
    (memory_space : address_space)
| FunctionType (inputs results : list mlir_type)
| TupleType (elements : list mlir_type)
| NoneType.

Definition signedness_eqb (left right : signedness_semantics) : bool :=
  match left, right with
  | Signless, Signless | Signed, Signed | Unsigned, Unsigned => true
  | _, _ => false
  end.

(* Executable equality for legal scalar element types. Containers are rejected:
   callers comparing shaped types must compare their shape separately. *)
Fixpoint mlir_element_type_eqb (left right : mlir_type) : bool :=
  match left, right with
  | IndexType, IndexType => true
  | IntegerType left_width left_sign, IntegerType right_width right_sign =>
      Nat.eqb left_width right_width && signedness_eqb left_sign right_sign
  | Float16Type, Float16Type | BFloat16Type, BFloat16Type
  | Float32Type, Float32Type | Float64Type, Float64Type => true
  | ComplexType left_element, ComplexType right_element =>
      mlir_element_type_eqb left_element right_element
  | _, _ => false
  end.
