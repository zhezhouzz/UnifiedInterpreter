"""Replay the archive, verify whole and slice diagnostics, and typecheck all included Rocq fixtures."""
import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path
import subprocess
import tempfile
from core_to_rocq import as_rocq, HEADER
from elaborate import translate

ROOT = Path(__file__).resolve().parents[1]
SYNTAX_PIN = "d3317199a98a81e235af54d2fa30a6cfbf81bf62"

def require(condition, message):
    if not condition:
        raise RuntimeError(message)

def rocq_check(checkout, fixtures):
    with tempfile.TemporaryDirectory() as temp:
        tmp = Path(temp)
        path = "rocq/CoreLanguage/Axiomatic/Syntax.v"
        src = subprocess.check_output(["git","-C",checkout,"show",SYNTAX_PIN+":"+path])
        syntax = tmp/path
        syntax.parent.mkdir(parents=True)
        syntax.write_bytes(src)
        rocq = ["rocq","compile","-Q",tmp/"rocq","UnifiedInterpreter"]
        subprocess.run([*rocq,syntax],cwd=tmp,check=True)
        sections = []
        for i,file in enumerate(fixtures):
            s = file.read_text()
            require(s.startswith(HEADER), file)
            sections.append(f"Module Case{i}.\n{s[len(HEADER):]}\nEnd Case{i}.\n")
        combined = tmp/"Corpus.v"
        combined.write_text(HEADER+"".join(sections))
        subprocess.run([*rocq,combined],cwd=tmp,check=True)
    print(f"Rocq {len(fixtures)} fixture modules typechecked against {SYNTAX_PIN}")

def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--bin",required=True,type=Path)
    p.add_argument("--reader",required=True,type=Path)
    p.add_argument("--upstream",required=True,type=Path,help="UnifiedInterpreter checkout containing the pinned upstream commit")
    args=p.parse_args()
    counts = Counter()
    source_hashes=set()
    for file in sorted(ROOT.glob("*/*/case.json")):
        case=json.loads(file.read_text()); folder=file.parent
        source=folder/"source.mlir"
        digest=hashlib.sha256(source.read_bytes()).digest()
        require(digest not in source_hashes, f"Duplicate primary source: {folder}")
        source_hashes.add(digest)
        ir=folder/"hivm.mlir"
        compiled=subprocess.check_output([args.bin/"bishengir-opt",*case["argv"]],input=source.read_bytes())
        require(compiled==ir.read_bytes(), f"Compiler output changed: {folder}")
        for entry,filename in [("translation","actual.core"),("slice_translation","slice.actual.core")]:
            ref=case[entry]; lines=ref.get("lines")
            code,errors=translate(ir,args.reader.resolve(),case["translation"]["function"],lines=lines)
            require(errors==ref["diagnostics"], f"Changed diagnostics in {folder} {entry}: {errors}")
            actual=folder/filename
            require(bool(code)==actual.exists(), f"Output presence differs: {folder}/{filename}")
            if code:
                require(code==actual.read_text(), f"Changed {folder}/{filename}")
                matches=(as_rocq(code)==as_rocq((folder/"expected.core").read_text()))
                baseline=ref.get("matches_expected",case["expectation"]["matches_full_output"])
                require(matches==baseline, f"Expected AST comparison changed: {folder}")
            counts[entry, bool(code)]+=1
        files=[("expected.core","expected"),("actual.core","actual"),("slice.actual.core","slice_actual"),("watch-ub0.core","observe_ub_zero"),("expected.kernel.core","kernel_reference")]
        typed=HEADER+"\n".join(as_rocq((folder/f).read_text(),symbol) for f,symbol in files if (folder/f).exists())
        require(typed==(folder/"Fixture.v").read_text(), f"Stale Rocq fixture: {folder}")
        if (folder/"watch-ub0.core").exists():
            observed,errors=translate(ir,args.reader.resolve(),case["translation"]["function"],watch=0)
            require(not errors and observed==(folder/"watch-ub0.core").read_text(),folder)
    print(f"{len(source_hashes)} distinct MLIR inputs rebuilt byte-for-byte")
    for mode in ("translation","slice_translation"):
        print(f"{mode}: {counts[mode,True]} accepted, {counts[mode,False]} diagnosed")
    fixtures=sorted(ROOT.glob("*/*/Fixture.v"))+sorted((ROOT/"evidence/issues").glob("*/Fixture.v"))
    rocq_check(args.upstream,fixtures)

if __name__=="__main__":
    main()
