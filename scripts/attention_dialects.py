from typing import ClassVar
from xdsl.context import Context
from xdsl.dialects import get_all_dialects
from xdsl.dialects import bufferization, memref
from xdsl.dialects.builtin import (
    DenseArrayBase, IndexType, MemRefType, NoneAttr, StringAttr, TensorType, UnitAttr, i64,
)
from xdsl.dialects.linalg import Linalg
from xdsl.dialects.utils import EnumAttribute
from xdsl.ir import Dialect
from xdsl.irdl import (
    AttrSizedOperandSegments,
    IRDLOperation,
    irdl_attr_definition,
    irdl_op_definition,
    operand_def,
    opt_operand_def,
    opt_prop_def,
    opt_result_def,
    prop_def,
    result_def,
    var_operand_def,
    VarConstraint,
    AnyAttr,
    EqAttrConstraint,
    ParamAttrConstraint,
)
from xdsl.utils.exceptions import VerifyException
from xdsl.utils.str_enum import StrEnum


class StructuredOp(IRDLOperation):
    inputs = var_operand_def()
    output = operand_def(TensorType)
    result = result_def(TensorType)
    assembly_format = (
        "attr-dict `ins` `(` $inputs `:` type($inputs) `)` "
        "`outs` `(` $output `:` type($output) `)` `->` type($result)"
    )


@irdl_op_definition
class ElementwiseBinaryOp(StructuredOp):
    name = "linalg.elemwise_binary"


@irdl_op_definition
class ElementwiseUnaryOp(StructuredOp):
    name = "linalg.elemwise_unary"


@irdl_op_definition
class MatmulOp(StructuredOp):
    name = "linalg.matmul"


@irdl_op_definition
class CastOp(StructuredOp):
    name = "hfusion.cast"


class RangeOp(IRDLOperation):
    offset = opt_operand_def(IndexType)
    strides = var_operand_def(IndexType)
    output = operand_def(TensorType | MemRefType)
    result = opt_result_def(TensorType)
    irdl_options = (AttrSizedOperandSegments(as_property=True),)
    assembly_format = (
        "attr-dict (`offset` `[` $offset^ `]`)? `strides` `[` $strides `]` "
        "`outs` `(` $output `:` type($output) `)` (`->` type($result)^)?"
    )

    def verify_(self) -> None:
        rank = len(self.output.type.get_shape())
        if rank == 0 or len(self.strides) != rank:
            raise VerifyException("arange requires one stride per destination axis")


@irdl_op_definition
class ArangeOp(RangeOp):
    name = "hfusion.arange"


@irdl_op_definition
class HFusionBinaryOp(StructuredOp):
    name = "hfusion.elemwise_binary"


@irdl_op_definition
class CompareOp(StructuredOp):
    name = "hfusion.compare"


@irdl_op_definition
class SelectOp(StructuredOp):
    name = "hfusion.select"


@irdl_op_definition
class BitcastOp(StructuredOp):
    name = "hfusion.bitcast"


@irdl_op_definition
class PrintOp(IRDLOperation):
    name = "hfusion.print"
    prefix = prop_def(StringAttr)
    argument = operand_def()
    assembly_format = "$prefix attr-dict $argument `:` type($argument)"


class IndirectLoad(IRDLOperation):
    source = operand_def(MemRefType)
    offsets = operand_def(TensorType)
    mask = operand_def(TensorType)
    other = operand_def(TensorType)
    output = operand_def(TensorType | MemRefType)
    result = opt_result_def(TensorType)
    assembly_format = (
        "`ins` `(` $source `:` type($source) `,` $offsets `:` type($offsets) "
        "`,` $mask `:` type($mask) `,` $other `:` type($other) `)` "
        "`outs` `(` $output `:` type($output) `)` attr-dict (`->` type($result)^)?"
    )


class IndirectStore(IRDLOperation):
    source = operand_def(TensorType)
    offsets = operand_def(TensorType)
    mask = opt_operand_def(TensorType)
    output = operand_def(MemRefType)
    assembly_format = (
        "`ins` `(` $source `:` type($source) `,` $offsets `:` type($offsets) "
        "(`,` $mask^ `:` type($mask))? `)` "
        "`outs` `(` $output `:` type($output) `)` attr-dict"
    )


@irdl_op_definition
class IndirectLoadOp(IndirectLoad):
    name = "hfusion.indirect_load"


@irdl_op_definition
class IndirectStoreOp(IndirectStore):
    name = "hfusion.indirect_store"


@irdl_op_definition
class VArangeOp(RangeOp):
    name = "hivm.hir.varange"


@irdl_op_definition
class VAndOp(StructuredOp):
    name = "hivm.hir.vand"


@irdl_op_definition
class VShrOp(StructuredOp):
    name = "hivm.hir.vshr"


@irdl_op_definition
class VMinOp(StructuredOp):
    name = "hivm.hir.vmin"


@irdl_op_definition
class VMaxOp(StructuredOp):
    name = "hivm.hir.vmax"


class CompareMode(StrEnum):
    EQ = "eq"
    NE = "ne"
    LT = "lt"
    LE = "le"
    GT = "gt"
    GE = "ge"


@irdl_attr_definition
class CompareModeAttr(EnumAttribute[CompareMode]):
    name = "hivm.compare_mode"


@irdl_op_definition
class VCmpOp(StructuredOp):
    name = "hivm.hir.vcmp"
    compare_mode = prop_def(CompareModeAttr)
    assembly_format = (
        "attr-dict `ins` `(` $inputs `:` type($inputs) `)` "
        "`outs` `(` $output `:` type($output) `)` "
        "`compare_mode` `=` `<` $compare_mode `>` `->` type($result)"
    )


@irdl_op_definition
class VSelOp(StructuredOp):
    name = "hivm.hir.vsel"


@irdl_op_definition
class VTransposeOp(StructuredOp):
    name = "hivm.hir.vtranspose"
    permutation = prop_def(DenseArrayBase.constr(i64))
    assembly_format = (
        "attr-dict `ins` `(` $inputs `:` type($inputs) `)` "
        "`outs` `(` $output `:` type($output) `)` "
        "`permutation` `=` $permutation `->` type($result)"
    )


@irdl_op_definition
class HIVMBitcastOp(IRDLOperation):
    name = "hivm.hir.bitcast"
    source = operand_def(TensorType)
    result = result_def(TensorType)
    assembly_format = "$source `:` type($source) `->` type($result) attr-dict"


@irdl_op_definition
class DebugOp(IRDLOperation):
    name = "hivm.hir.debug"
    argument = operand_def()
    assembly_format = "attr-dict $argument `:` type($argument)"


@irdl_op_definition
class VIndirectLoadOp(IndirectLoad):
    name = "hivm.hir.indirect_load"


@irdl_op_definition
class VIndirectStoreOp(IndirectStore):
    name = "hivm.hir.indirect_store"


@irdl_op_definition
class VAddOp(StructuredOp):
    name = "hivm.hir.vadd"


@irdl_op_definition
class VSubOp(StructuredOp):
    name = "hivm.hir.vsub"


@irdl_op_definition
class VMulOp(StructuredOp):
    name = "hivm.hir.vmul"


@irdl_op_definition
class VDivOp(StructuredOp):
    name = "hivm.hir.vdiv"


@irdl_op_definition
class VExpOp(StructuredOp):
    name = "hivm.hir.vexp"


@irdl_op_definition
class VLnOp(StructuredOp):
    name = "hivm.hir.vln"


@irdl_op_definition
class VCastOp(StructuredOp):
    name = "hivm.hir.vcast"


@irdl_op_definition
class MmadOp(StructuredOp):
    name = "hivm.hir.mmadL1"


@irdl_op_definition
class VBrcOp(IRDLOperation):
    name = "hivm.hir.vbrc"
    inputs = var_operand_def()
    output = operand_def(TensorType | MemRefType)
    result = opt_result_def(TensorType)
    broadcast_dims = opt_prop_def(DenseArrayBase.constr(i64))
    assembly_format = (
        "attr-dict `ins` `(` $inputs `:` type($inputs) `)` "
        "`outs` `(` $output `:` type($output) `)` "
        "(`broadcast_dims` `=` $broadcast_dims^)? (`->` type($result)^)?"
    )


class ReductionKind(StrEnum):
    MAX = "max"
    SUM = "sum"


@irdl_attr_definition
class ReductionKindAttr(EnumAttribute[ReductionKind]):
    name = "hivm.reduction_kind"


@irdl_op_definition
class VReduceOp(StructuredOp):
    name = "hivm.hir.vreduce"
    kind = prop_def(ReductionKindAttr)
    reduce_dims = prop_def(DenseArrayBase.constr(i64))
    assembly_format = (
        "`<` $kind `>` attr-dict `ins` `(` $inputs `:` type($inputs) `)` "
        "`outs` `(` $output `:` type($output) `)` "
        "`reduce_dims` `=` $reduce_dims `->` type($result)"
    )


@irdl_op_definition
class ToTensorOp(IRDLOperation):
    name = "bufferization.to_tensor"
    ELEMENT: ClassVar = VarConstraint("Element", AnyAttr())
    SHAPE: ClassVar = VarConstraint("Shape", AnyAttr())
    memref = operand_def(MemRefType.constr(ELEMENT, shape=SHAPE))
    tensor = result_def(ParamAttrConstraint.get(
        TensorType, SHAPE, ELEMENT, EqAttrConstraint(NoneAttr())
    ))
    writable = opt_prop_def(UnitAttr)
    restrict = opt_prop_def(UnitAttr)
    # 归档文件的语法由 memref 类型推导 tensor 类型。
    assembly_format = (
        "$memref (`restrict` $restrict^)? (`writable` $writable^)? "
        "attr-dict `:` type($memref)"
    )


@irdl_op_definition
class CopyOp(IRDLOperation):
    name = "memref.copy"
    source = operand_def(MemRefType)
    target = operand_def(MemRefType)
    assembly_format = "$source `,` $target attr-dict `:` type($source) `to` type($target)"


@irdl_op_definition
class MaterializeOp(IRDLOperation):
    name = "bufferization.materialize_in_destination"
    source = operand_def(TensorType)
    destination = operand_def(MemRefType)
    writable = opt_prop_def(UnitAttr)
    restrict = opt_prop_def(UnitAttr)
    assembly_format = (
        "$source `in` (`restrict` $restrict^)? (`writable` $writable^)? "
        "$destination attr-dict `:` `(` type($source) `,` type($destination) `)` `->` `(` `)`"
    )


def context():
    ctx = Context(allow_unregistered=True)
    for name, factory in get_all_dialects().items():
        if name not in {"linalg", "bufferization", "memref", "dlti"}:
            ctx.register_dialect(name, factory)
    ctx.load_dialect(Dialect("linalg", [
        *(op for op in Linalg.operations if op.name != "linalg.matmul"),
        ElementwiseBinaryOp, ElementwiseUnaryOp, MatmulOp,
    ], list(Linalg.attributes)))
    ctx.load_dialect(Dialect("bufferization", [
        op for op in bufferization.Bufferization.operations
        if op.name not in {"bufferization.to_tensor", "bufferization.materialize_in_destination"}
    ] + [ToTensorOp, MaterializeOp]))
    ctx.load_dialect(Dialect("memref", [
        op for op in memref.MemRef.operations if op.name != "memref.copy"
    ] + [CopyOp], list(memref.MemRef.attributes)))
    ctx.load_dialect(Dialect("hfusion", [
        CastOp, ArangeOp, HFusionBinaryOp, CompareOp, SelectOp, BitcastOp, PrintOp,
        IndirectLoadOp, IndirectStoreOp,
    ]))
    ctx.load_dialect(Dialect("hivm", [
        VAddOp, VSubOp, VMulOp, VDivOp, VExpOp, VLnOp,
        VCastOp, VBrcOp, VReduceOp, MmadOp,
        VArangeOp, VAndOp, VShrOp, VMinOp, VMaxOp, VCmpOp, VSelOp, VTransposeOp,
        HIVMBitcastOp, DebugOp, VIndirectLoadOp, VIndirectStoreOp,
    ], [ReductionKindAttr, CompareModeAttr]))
    return ctx
