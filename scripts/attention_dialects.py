from typing import ClassVar
from xdsl.context import Context
from xdsl.dialects import get_all_dialects
from xdsl.dialects import bufferization, memref
from xdsl.dialects.builtin import (
    DenseArrayBase, IndexType, IntegerAttr, MemRefType, NoneAttr, StringAttr,
    TensorType, UnitAttr, i64,
)
from xdsl.dialects.linalg import Linalg
from xdsl.dialects.utils import EnumAttribute
from xdsl.ir import Dialect
from xdsl.irdl import (
    AttrSizedOperandSegments,
    AnyAttr,
    EqAttrConstraint,
    IRDLOperation,
    irdl_attr_definition,
    irdl_op_definition,
    operand_def,
    opt_operand_def,
    opt_prop_def,
    opt_result_def,
    ParamAttrConstraint,
    prop_def,
    result_def,
    var_operand_def,
    VarConstraint,
)
from xdsl.utils.str_enum import StrEnum


class StructuredOp(IRDLOperation):
    inputs = var_operand_def()
    output = operand_def(TensorType | MemRefType)
    result = opt_result_def(TensorType)
    assembly_format = (
        "attr-dict `ins` `(` $inputs `:` type($inputs) `)` "
        "`outs` `(` $output `:` type($output) `)` (`->` type($result)^)?"
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
class ArangeOp(IRDLOperation):
    name = "hfusion.arange"
    offset = opt_operand_def(IndexType)
    strides = var_operand_def(IndexType)
    output = operand_def(TensorType | MemRefType)
    result = opt_result_def(TensorType)
    irdl_options = (AttrSizedOperandSegments(as_property=True),)
    assembly_format = (
        "attr-dict (`offset` `[` $offset^ `]`)? `strides` `[` $strides `]` "
        "`outs` `(` $output `:` type($output) `)` (`->` type($result)^)?"
    )


@irdl_op_definition
class CompareOp(StructuredOp):
    name = "hfusion.compare"


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
class VBrcOp(StructuredOp):
    name = "hivm.hir.vbrc"
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
        "`reduce_dims` `=` $reduce_dims (`->` type($result)^)?"
    )


@irdl_op_definition
class LoadOp(StructuredOp):
    name = "hivm.hir.load"


@irdl_op_definition
class StoreOp(StructuredOp):
    name = "hivm.hir.store"


class IndirectOp(StructuredOp):
    assembly_format = None

    @classmethod
    def parse(cls, parser):
        def typed_operand():
            operand = parser.parse_unresolved_operand()
            parser.parse_punctuation(":")
            return parser.resolve_operand(operand, parser.parse_type())

        parser.parse_keyword("ins")
        inputs = parser.parse_comma_separated_list(parser.Delimiter.PAREN, typed_operand)
        parser.parse_keyword("outs")
        parser.parse_punctuation("(")
        output = typed_operand()
        parser.parse_punctuation(")")
        attributes = parser.parse_optional_attr_dict()
        result = parser.parse_type() if parser.parse_optional_punctuation("->") else None
        return cls.build(operands=[inputs, output], result_types=[result], attributes=attributes)


@irdl_op_definition
class IndirectLoadOp(IndirectOp):
    name = "hivm.hir.indirect_load"


@irdl_op_definition
class IndirectStoreOp(IndirectOp):
    name = "hivm.hir.indirect_store"


@irdl_op_definition
class HFusionIndirectLoadOp(IndirectOp):
    name = "hfusion.indirect_load"


@irdl_op_definition
class HFusionIndirectStoreOp(IndirectOp):
    name = "hfusion.indirect_store"


def pipe(parser):
    parser.parse_punctuation("<")
    name = parser.parse_identifier()
    parser.parse_punctuation(">")
    return StringAttr(name)


class FlagOp(IRDLOperation):
    source_pipe = prop_def(StringAttr, prop_name="set_pipe")
    target_pipe = prop_def(StringAttr, prop_name="wait_pipe")
    static_event_id = opt_prop_def(StringAttr)
    dynamic_event_id = opt_operand_def(i64)

    @classmethod
    def parse(cls, parser):
        parser.parse_punctuation("[")
        source = pipe(parser)
        parser.parse_punctuation(",")
        target = pipe(parser)
        parser.parse_punctuation(",")
        event = parser.parse_optional_operand(i64)
        properties = {"set_pipe": source, "wait_pipe": target}
        if event is None:
            properties["static_event_id"] = pipe(parser)
        parser.parse_punctuation("]")
        return cls.build(operands=[event], properties=properties, attributes=parser.parse_optional_attr_dict())


@irdl_op_definition
class SetFlagOp(FlagOp):
    name = "hivm.hir.set_flag"


@irdl_op_definition
class WaitFlagOp(FlagOp):
    name = "hivm.hir.wait_flag"


class BlockFlagOp(IRDLOperation):
    tcore_type = prop_def(StringAttr)
    tpipe = prop_def(StringAttr)
    receive_pipe = prop_def(StringAttr, prop_name="pipe")
    static_flag_id = opt_prop_def(IntegerAttr)
    dynamic_flag_id = opt_operand_def(i64)

    @classmethod
    def parse(cls, parser):
        attributes = parser.parse_optional_attr_dict()
        parser.parse_punctuation("[")
        core = pipe(parser)
        parser.parse_punctuation(",")
        source = pipe(parser)
        parser.parse_punctuation(",")
        target = pipe(parser)
        parser.parse_punctuation("]")
        parser.parse_keyword("flag")
        parser.parse_punctuation("=")
        flag = parser.parse_optional_operand(i64)
        properties = {"tcore_type": core, "tpipe": source, "pipe": target}
        if flag is None:
            properties["static_flag_id"] = IntegerAttr(parser.parse_integer(), i64)
        return cls.build(operands=[flag], properties=properties, attributes=attributes)


@irdl_op_definition
class SyncBlockSetOp(BlockFlagOp):
    name = "hivm.hir.sync_block_set"


@irdl_op_definition
class SyncBlockWaitOp(BlockFlagOp):
    name = "hivm.hir.sync_block_wait"


@irdl_op_definition
class PipeBarrierOp(IRDLOperation):
    pipe_name = prop_def(StringAttr, prop_name="pipe")
    name = "hivm.hir.pipe_barrier"

    @classmethod
    def parse(cls, parser):
        parser.parse_punctuation("[")
        name = pipe(parser)
        parser.parse_punctuation("]")
        return cls.build(properties={"pipe": name}, attributes=parser.parse_optional_attr_dict())


@irdl_op_definition
class ToTensorOp(IRDLOperation):
    name = "bufferization.to_tensor"
    ELEMENT: ClassVar = VarConstraint("Element", AnyAttr())
    SHAPE: ClassVar = VarConstraint("Shape", AnyAttr())
    memref = operand_def(MemRefType.constr(ELEMENT, shape=SHAPE))
    tensor = result_def(ParamAttrConstraint.get(TensorType, SHAPE, ELEMENT, EqAttrConstraint(NoneAttr())))
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
    ctx.load_dialect(Dialect("hfusion", [CastOp, ArangeOp, CompareOp, HFusionIndirectLoadOp, HFusionIndirectStoreOp]))
    ctx.load_dialect(Dialect("hivm", [
        VAddOp, VSubOp, VMulOp, VDivOp, VExpOp, VLnOp,
        VCastOp, VBrcOp, VReduceOp, MmadOp, LoadOp, StoreOp, IndirectLoadOp,
        IndirectStoreOp, SetFlagOp, WaitFlagOp, SyncBlockSetOp, SyncBlockWaitOp, PipeBarrierOp,
    ], [ReductionKindAttr]))
    return ctx
