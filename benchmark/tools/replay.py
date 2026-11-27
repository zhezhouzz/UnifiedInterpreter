"""Capture a complete module at a named pass boundary, including outlined functions."""
import os
from pathlib import Path
import subprocess
import tempfile

def compile_ir(build, argv, source, boundary=None):
    binary=build/"bin"/argv[0]
    if not boundary:
        return subprocess.check_output([binary,*argv[1:]],input=source.read_bytes())
    with tempfile.TemporaryDirectory() as tmp:
        result=subprocess.run([binary,source.resolve(),*argv[1:]],cwd=tmp,
                              env={**os.environ,"PATH":str(build/"bin")+":"+os.environ["PATH"]},
                              stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    matches=[]
    for section in result.stdout.split(b"// -----// IR Dump After ")[1:]:
        header,_,body=section.partition(b"\n")
        if ("("+boundary+")").encode() in header:
            lines=body.splitlines()
            # Only the outer module closes at column zero.
            try:
                end=lines.index(b"}")
            except ValueError:
                continue
            matches.append(b"\n".join(lines[:end+1])+b"\n")
    if not matches:
        raise ValueError("missing whole-module pass dump: "+boundary)
    return matches[-1]
