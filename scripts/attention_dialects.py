from typing import ClassVar
from xdsl.context import Context
from xdsl.dialects import get_all_dialects
from xdsl.dialects import bufferization, memref
from xdsl.dialects.builtin import DenseArrayBase, MemRefType, NoneAttr, TensorType, UnitAttr, i64
from xdsl.dialects.linalg import Linalg
from xdsl.dialects.utils import EnumAttribute
from xdsl.ir import Dialect
from xdsl.irdl import (
    IRDLOperation,
    irdl_attr_definition,
    irdl_op_definition,
    operand_def,
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
    ctx.load_dialect(Dialect("hfusion", [CastOp]))
    ctx.load_dialect(Dialect("hivm", [
        VAddOp, VSubOp, VMulOp, VDivOp, VExpOp, VLnOp,
        VCastOp, VBrcOp, VReduceOp, MmadOp,
    ], [ReductionKindAttr]))
    return ctx
