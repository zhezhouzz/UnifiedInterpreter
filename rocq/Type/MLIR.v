From Stdlib Require Import Bool List String ZArith.
From UnifiedInterpreter.Type Require Import DType Shape.

(* This is a structural representation of MLIR attributes needed inside types.
   MLIR's attribute system is open: dialects may define arbitrary attributes.
   We therefore preserve unknown/dialect attributes by namespace and payload
   instead of pretending that this inductive enumerates every attribute. *)
Inductive mlir_attribute :=
| IntegerAttr (value : Z)
| StringAttr (value : string)
| DialectAttr (dialect name payload : string).

Record strided_layout := {
  layout_offset : option Z;
  layout_strides : list (option Z)
}.

(* MLIR permits any attribute implementing MemRefLayoutAttrInterface here.
   We execute canonical strided layouts directly and retain affine/dialect
   layouts structurally for later verification or elaboration. *)
Inductive memref_layout :=
| IdentityLayout
| StridedLayout (layout : strided_layout)
| AffineMapLayout (assembly : string)
| DialectLayout (attribute : mlir_attribute).

(* Relationship to real MLIR types
   --------------------------------
   This datatype formalizes the builtin type forms needed by the captured
   HFusion program and its planned SIMD lowering. It follows real MLIR in the
   following important ways:

   - integers may be signless, signed, or unsigned;
   - ranked tensors and memrefs contain static or dynamic dimensions;
   - tensors may carry an encoding attribute;
   - memrefs carry both a layout and a target-specific memory-space attribute;
   - ranked and unranked tensor/memref types are distinct;
   - element types are recursively MLIR types rather than interpreter dtypes;
   - dialect-defined types remain representable because MLIR's type system is
     open.

   It is still not a byte-for-byte model of MLIR's C++ Type storage. Generic
   attributes, affine maps, dialect types, and opaque types retain textual
   payloads; legality is established by a separate verifier. Vector scalable
   flags are represented explicitly but their length constraints are likewise
   verifier obligations. Builtin forms not required by HFusion can be added
   without changing tensor execution semantics.

   [dtype] in Type/DType is different: it selects a scalar interpreter backend
   representation. [mlir_type] describes source IR syntax. Elaboration maps a
   supported scalar [mlir_type] to [dtype], and may reject unsupported types. *)
Inductive mlir_type :=
| IndexType
| IntegerType (bits : nat) (sign : signedness)
| FloatType (format : float_format)
| ComplexType (element_type : mlir_type)
| RankedTensorType (dimensions : shape) (element_type : mlir_type)
    (encoding : option mlir_attribute)
| UnrankedTensorType (element_type : mlir_type)
| VectorType (dimensions : list nat) (scalable : list bool)
    (element_type : mlir_type)
| RankedMemRefType (dimensions : shape) (element_type : mlir_type)
    (layout : memref_layout) (memory_space : option mlir_attribute)
| UnrankedMemRefType (element_type : mlir_type)
    (memory_space : option mlir_attribute)
| FunctionType (inputs results : list mlir_type)
| TupleType (elements : list mlir_type)
| NoneType
| DialectType (dialect name payload : string)
| OpaqueType (dialect payload : string).

Definition dtype_to_mlir_type (element_type : dtype) : mlir_type :=
  match element_type with
  | DIndex => IndexType
  | DInt bits sign => IntegerType bits sign
  | DFloat format => FloatType format
  end.

