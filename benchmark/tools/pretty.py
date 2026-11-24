"""Pretty-print JSON Core AST (*.program.core) into opsem.tex-style concrete syntax."""
import argparse
import json
from pathlib import Path

CMPI_PRED = {
    "0": "eq", "1": "ne", "2": "slt", "3": "sle", "4": "sgt",
    "5": "sge", "6": "ult", "7": "ule", "8": "ugt", "9": "uge",
}


def var(vid):
    return f"v{vid}" if isinstance(vid, int) else str(vid)


def short_type(ty):
    return ty.replace("#hivm.address_space<", "#").replace(">>", ">")


def scalar_label(cmd):
    fn = cmd["fn"]
    attrs = cmd.get("attrs", {})
    if fn == "arith.constant" and "value" in attrs:
        return f"const({attrs['value']})"
    if fn == "arith.cmpi" and "predicate" in attrs:
        code = attrs["predicate"].split()[0]
        return f"arith.cmpi.{CMPI_PRED.get(code, code)}"
    if fn.startswith("affine.") and "map" in attrs:
        return f"{fn}[{attrs['map']}]"
    return fn


def format_block(commands, indent=2):
    pad = " " * indent
    lines = []
    for c in commands:
        op = c["cmd"]
        args = [var(a) for a in c.get("args", [])]
        res = [var(r) for r in c.get("results", [])]
        types = c.get("types", [])

        if op == "scalar":
            lbl = scalar_label(c)
            call = f"scalar[{lbl}]({', '.join(args)})"
            if res:
                ty_note = f"  // : {', '.join(short_type(t) for t in types)}" if types and any("memref<" in t for t in types) else ""
                lines.append(f"{pad}let {', '.join(res)} = {call} in{ty_note}")
            else:
                lines.append(f"{pad}{call};")
        elif op == "alloc":
            space = c.get("space", "?").upper()
            dims = args if args else [str(d) for d in c.get("dimensions", [])]
            ty_note = f"  // : {short_type(types[0])}" if types else ""
            lines.append(f"{pad}let {', '.join(res)} = alloc[{space}]({', '.join(dims)}) in{ty_note}")
        elif op == "issue":
            p = c["p"]
            fn = c["fn"]
            lines.append(f"{pad}issue[{p}]({fn}, {', '.join(args)});")
        elif op in ("setflag", "waitflag", "syncblockset", "syncblockwait"):
            ev = var(c["event_operand"]) if "event_operand" in c else str(c.get("event", "?"))
            lines.append(f"{pad}{op}[{c['p']}, {c['q']}]({ev});")
        elif op == "pipebarrier":
            lines.append(f"{pad}pipebarrier[{c['p']}];")
        elif op == "scalarstore":
            lines.append(f"{pad}scalarstore({', '.join(args)});")
        elif op == "for":
            iv = var(c["bindings"][0][0][0]["id"])
            lo, hi, step = args[0], args[1], args[2]
            lines.append(f"{pad}for {iv} = {lo} to {hi} step {step} do {{")
            lines.extend(format_block(c["bodies"][0], indent + 2))
            lines.append(f"{pad}}};")
        elif op == "if":
            cond = args[0]
            lines.append(f"{pad}if {cond} then {{")
            lines.extend(format_block(c["bodies"][0], indent + 2))
            lines.append(f"{pad}}} else {{")
            lines.extend(format_block(c["bodies"][1], indent + 2))
            lines.append(f"{pad}}};")
        elif op == "return":
            lines.append(f"{pad}return({', '.join(args)})")
        elif op == "end":
            lines.append(f"{pad}end")
        else:
            lines.append(f"{pad}{op}({', '.join(args)});  // raw")
    return lines


def format_program(program):
    blocks = []
    for name, stream in program.items():
        params = ", ".join(f"{var(p['id'])}: {short_type(p['type'])}" for p in stream.get("params", []))
        kind = stream.get("core_kind")
        header = []
        if kind:
            header.append(f"// core_kind: {kind}")
        header.append(f"{name}({params}) {{")
        body = format_block(stream["body"], indent=2)
        blocks.append("\n".join(header + body + ["}"]))
    return "\n\n||\n\n".join(blocks) + "\n"


def pretty_path(core_file):
    name = core_file.name
    if name.endswith(".program.core"):
        out_name = name[: -len(".program.core")] + ".pretty.core"
    elif name == "program.core":
        out_name = "program.pretty.core"
    else:
        out_name = core_file.stem + ".pretty.core"
    return core_file.with_name(out_name)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("files", nargs="*", type=Path, help="specific *.program.core files to print to stdout")
    parser.add_argument("--all", action="store_true", help="write *.pretty.core next to every L1/L2/L3 *.program.core")
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1], help="benchmark root directory")
    args = parser.parse_args()

    if args.files:
        for path in args.files:
            if len(args.files) > 1:
                print(f"=== {path} ===")
            print(format_program(json.loads(path.read_text())), end="")
        return

    count = 0
    for core in sorted(args.root.glob("L[123]/**/*program.core")):
        out = pretty_path(core)
        out.write_text(format_program(json.loads(core.read_text())))
        count += 1
    print(f"Pretty-printed {count} Core AST files to *.pretty.core under {args.root}")


if __name__ == "__main__":
    main()
