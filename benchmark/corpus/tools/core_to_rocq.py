"""Read the checked-in straight-line concrete syntax and emit the upstream Rocq AST."""
import argparse
import re
from pathlib import Path

HEADER = '''From Stdlib Require Import List String ZArith.
From UnifiedInterpreter.CoreLanguage.Axiomatic Require Import Syntax.
Import ListNotations.
Open Scope string_scope.
Local Notation Cmd := (@command unit nat string string unit).
'''
TOKEN = re.compile(r':=|[A-Za-z_][A-Za-z_0-9]*|[0-9]+|[][(){},;@]')

def as_rocq(text, name="fixture"):
    tokens = TOKEN.findall(text)
    if "".join(tokens) != re.sub(r"\s+", "", text):
        raise ValueError("Unexpected character in core source")
    it = iter(tokens)
    def take(expected=None):
        token = next(it, None)
        if token is None or (expected is not None and token != expected):
            raise ValueError(f"Expected {expected}, got {token}")
        return token
    def ident():
        value = take()
        if not re.fullmatch(r"[A-Za-z_]\w*", value, re.ASCII):
            raise ValueError(f"Invalid identifier {value}")
        return value
    def dispatch():
        take("["); unit = ident(); separator = take()
        if separator == "]":
            return f'(Dispatch "{unit}" None)'
        if separator != "@":
            raise ValueError("Expected @ or ] in dispatch")
        pipe = ident(); take("]")
        return f'(Dispatch "{unit}" (Some (Literal (VPipe "{pipe}"))))'
    def addr():
        token = take()
        if not re.fullmatch(r"(?:UB_BYTE_|CELL_)\d+", token):
            raise ValueError("Expected UB byte address")
        return f'(Literal (VMemory (ExternalMemory {int(token.rsplit("_",1)[1])}%nat)))'
    take("run"); take("{")
    commands, bound = [], {}
    while True:
        op = take()
        if op == "return":
            take("("); take(")"); take("}")
            break
        if op in ("setflag", "waitflag"):
            take("["); p = ident(); take(","); q = ident(); take("]"); take("(")
            e = take(); take(")")
            if not re.fullmatch(r"EVENT_ID\d+", e):
                raise ValueError(f"Unknown event literal {e}")
            ctor = {"setflag":"SetFlag", "waitflag":"WaitFlag"}[op]
            cmd = f'{ctor} tt (Literal (VPipe "{p}")) (Literal (VPipe "{q}")) (Literal (VEvent {int(e[8:])}%nat))'
        elif op == "write":
            d = dispatch(); take("("); a = addr(); take(","); value = take(); take(")")
            if value in bound:
                value = f"(OVar {bound[value]}%nat)"
            elif value.isdecimal():
                value = f"(Literal (VInt {int(value)}%Z))"
            else:
                raise ValueError("Unbound write value " + value)
            cmd = f"Write tt {d} {a} {value}"
        else:
            if op in bound or not re.fullmatch(r"[a-zA-Z_]\w*", op):
                raise ValueError(f"Invalid SSA binder {op}")
            x = len(bound); bound[op] = x; take(":="); kind = take()
            d = dispatch(); take("(")
            if kind == "compute":
                cmd = f"CCompute tt {x}%nat {d} []"
            elif kind == "read":
                cmd = f"Read tt {x}%nat {d} {addr()}"
            else:
                raise ValueError(f"Unknown command {kind}")
            take(")")
        commands.append(cmd); take(";")
    if next(it, None) is not None:
        raise ValueError("Trailing core input")
    body = "\n    (".join(commands + ["Return tt []"]) + ")" * len(commands)
    return f"Definition {name} : @shared_program unit nat string string :=\n  Run [({body} : Cmd)].\n"

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("program", type=Path)
    args = parser.parse_args()
    print(HEADER + as_rocq(args.program.read_text()), end="")
