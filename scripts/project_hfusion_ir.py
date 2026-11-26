from io import StringIO
from pathlib import Path
import subprocess

from xdsl.context import Context
from xdsl.dialects import func
from xdsl.dialects.builtin import (
    Builtin, FunctionType, MemRefType, NoneAttr, UnregisteredAttr, UnregisteredOp,
)
from xdsl.parser import Parser
from xdsl.pattern_rewriter import PatternRewriteWalker, TypeConversionPattern
from xdsl.printer import Printer
from xdsl.rewriter import Rewriter


SYNC = {"hivm.hir.set_flag", "hivm.hir.wait_flag", "hivm.hir.pipe_barrier",
        "hivm.hir.sync_block_set", "hivm.hir.sync_block_wait"}
ROOT = Path(__file__).resolve().parents[1]


def compile_ir(opt, source, *passes):
    return subprocess.run([opt, "--verify-each", "--mlir-disable-threading", *passes],
                          input=source, stdout=subprocess.PIPE, check=True).stdout


def parse_generic(opt, source):
    ctx = Context(allow_unregistered=True)
    ctx.load_dialect(Builtin)
    generic = compile_ir(opt, source, "--mlir-print-op-generic", "--mlir-print-local-scope")
    return Parser(ctx, generic.decode()).parse_module()


def opname(op):
    return op.op_name.data if isinstance(op, UnregisteredOp) else op.name


def assembly(module):
    out = StringIO()
    Printer(stream=out, print_generic_format=True).print_op(module)
    return out.getvalue().encode()


class LogicalMemRefs(TypeConversionPattern):
    def convert_type(self, typ):
        if isinstance(typ, MemRefType) and str(typ.memory_space).startswith("#hivm.address_space<"):
            return MemRefType(typ.element_type, typ.shape, typ.layout, NoneAttr())
        return None


def project(opt, source, benchmark):
    module = parse_generic(opt, source)
    bindings = {}
    helper = None
    for function in list(module.body.block.ops):
        if opname(function) != "func.func":
            raise ValueError(f"{benchmark}: unexpected top-level operation")
        if not function.regions[0].blocks:
            continue
        entry = function.properties["sym_name"].data
        block = function.regions[0].block
        extras = {}
        for op in list(function.walk()):
            name = opname(op)
            if name in SYNC:
                if op.results or op.regions:
                    raise ValueError(f"unexpected synchronization signature: {name}")
                Rewriter.erase_op(op)
            elif name in ("hivm.hir.pointer_cast", "hivm.hir.get_sub_block_idx"):
                result, = op.results
                if name == "hivm.hir.pointer_cast":
                    address, = op.operands
                    if opname(address.owner) != "arith.constant":
                        raise ValueError(f"{benchmark}: dynamic physical pointer")
                    offset = address.owner.properties["value"].value.data
                    key = ("local-memory", str(result.type.memory_space), offset, str(result.type))
                else:
                    key = ("sub-block-id",)
                if key not in extras:
                    extras[key] = block.insert_arg(result.type, len(block.args))
                result.replace_all_uses_with(extras[key])
                Rewriter.erase_op(op)
            elif name == "hivm.hir.fixpipe":
                # mix-handoff 的算例将 L0C 定义为 256 个逻辑 f32 元素。
                if (not benchmark.startswith("litao/mix-handoff/") or
                        str(op.properties.get("dma_mode")) != "#hivm.dma_mode<nz2nd>" or
                        [v.type.get_shape() for v in op.operands] != [(256,), (256,)]):
                    raise ValueError(f"{benchmark}: unsupported fixpipe descriptor")
                copy = UnregisteredOp.with_name("memref.copy").create(operands=op.operands)
                Rewriter.replace_op(op, copy)
            elif name == "hivm.hir.custom":
                if (not benchmark.startswith("litao/indirect-atomic/") or
                        op.properties["name"].data != "__builtin_indirect_atomic" or
                        op.attributes["extra_attr"].data != "operate=add" or len(op.operands) != 5):
                    raise ValueError(f"{benchmark}: unsupported custom instruction")
                if helper is None:
                    definition = ROOT / "benchmarks/ir-pairs/support/indirect_atomic_add.mlir"
                    helper = parse_generic(opt, definition.read_bytes()).body.block.first_op
                    helper.detach()
                Rewriter.replace_op(op, func.CallOp("indirect_atomic_add", list(op.operands), []))
            else:
                for attr in ("hivm.func_core_type", "hivm.pipe"):
                    op.attributes.pop(attr, None)
        if extras:
            if "arg_attrs" in function.properties:
                raise ValueError(f"{benchmark}: parameter attributes require explicit extension")
            old = function.properties["function_type"]
            function.properties["function_type"] = FunctionType.from_lists(block.arg_types, old.outputs)
            bindings[entry] = [{"index": value.index, "source": list(key)} for key, value in extras.items()]
    if helper is not None:
        module.body.block.add_op(helper)
    # 递归转换 memref 的元素类型，覆盖保存共享描述符的 memref<1xmemref<...>>。
    PatternRewriteWalker(LogicalMemRefs(recursive=True), apply_recursively=False).rewrite_module(module)
    output = compile_ir(opt, assembly(module), "--convert-hivm-to-hfusion",
                        "--execution-engine-convert-hivm-to-upstream",
                        "--convert-linalg-to-hfusion", "--convert-math-to-hfusion")
    high = parse_generic(opt, output)
    for op in list(high.walk()):
        name = opname(op)
        if name.startswith("hivm."):
            raise ValueError(f"{benchmark}: unconverted HIVM operation {name}")
        if name in ("linalg.abs", "linalg.exp"):
            # 正向转换使用 elemwise_unary；沿用 BiShengIR 生成的标量运算区域。
            attr = UnregisteredAttr.with_name_and_type("linalg.unary_fn", False)
            kind = attr("linalg.unary_fn", False, False, name.split(".")[1])
            unary = UnregisteredOp.with_name("linalg.elemwise_unary").create(
                operands=op.operands, result_types=op.result_types,
                properties={**op.properties, "fun": kind}, regions=[op.detach_region(0)])
            Rewriter.replace_op(op, unary)
    return compile_ir(opt, assembly(high)), bindings
