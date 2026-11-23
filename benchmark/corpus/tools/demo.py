"""Small independent observations for the demo, including one real compiler regression."""
import argparse
from collections import deque
import re
import subprocess
from pathlib import Path
from elaborate import translate
from core_to_rocq import as_rocq, HEADER
from memref_lane import translate as lane_program

ROOT = Path(__file__).resolve().parents[1]
def early_consumer(text):
    # One branch, no values used, static flag IDs. Data operations have start/end phases.
    ops = []
    for line in text.splitlines():
        flag = re.fullmatch(r"\s*(set|wait)flag\[(\w+), (\w+)\]\((\w+)\);", line)
        if flag:
            kind, p, q, e = flag.groups()
            ops.append((kind, p if kind == "set" else q, (p,q,e)))
        elif match := re.search(r"\[(unit_\w+)@(PIPE_\w+)\]", line):
            ops.append((match[1], match[2], None))
    producer = next(i for i,o in enumerate(ops) if o[0]=="unit_load")
    consumer = next(i for i,o in enumerate(ops) if o[0]=="unit_vabs")
    initial = (0, frozenset(), frozenset())
    seen = {initial}
    queue = deque([(initial, [])])
    while queue:
        (issued, done, pending), path = queue.popleft()
        if issued > consumer and producer not in done:
            return path, len(seen)
        nexts = []
        if issued < len(ops) and (issued == 0 or ops[issued-1][0] != "wait" or issued-1 in done):
            nexts.append(((issued+1, done, pending), f"{ops[issued][0]}[{issued}].start"))
        for i in range(issued):
            kind, pipe, key = ops[i]
            if i in done:
                continue
            if kind=="set" and (key in pending or any(j not in done and ops[j][1]==pipe for j in range(i))):
                continue
            if kind=="wait" and key not in pending:
                continue
            changed = pending | {key} if kind=="set" else pending - {key} if kind=="wait" else pending
            nexts.append(((issued, done | {i}, changed), f"{kind}[{i}].end"))
        for state, label in nexts:
            if state not in seen:
                seen.add(state)
                queue.append((state, path+[label]))
    return None, len(seen)

def sequential_lane(text):
    cells = {0:7, 1:-1}
    variables = {}
    for line in text.splitlines()[1:-2]:
        if m := re.fullmatch(r"  (\w+) := read\[mem\]\(CELL_(\d+)\);", line):
            variables[m[1]] = cells[int(m[2])]
        elif m := re.fullmatch(r"  write\[mem\]\(CELL_(\d+), (\w+)\);", line):
            cells[int(m[1])] = int(m[2]) if m[2].isdecimal() else variables[m[2]]
        else:
            raise ValueError(line)
    return cells[1]

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument("--reader",required=True,type=Path)
    p.add_argument("--bin",required=True,type=Path)
    args=p.parse_args()
    for name, bad in [("ready-and-drain",False),("ready-without-wait",True),("wrong-consumer-pipe",False)]:
        folder=ROOT/"handwritten"/name
        text, errors=translate(folder/"hivm.mlir",args.reader.resolve(),watch=0)
        assert not errors and text==(folder/"watch-ub0.core").read_text()
        path, count=early_consumer(text)
        assert (path is not None)==bad
        print(name,count,"states discovered;", " -> ".join(path) if path else "no early read in exhausted state graph")
    for name, expected in [("two-rounds", None), ("overlapping-sets", 2),
                           ("independent-directions", None), ("wrong-event", 2)]:
        data = (ROOT/"handwritten"/name/"actual.core").read_text()
        pending, violation = set(), None
        flags = re.findall(r"(set|wait)flag\[(\w+), (\w+)\]\((\w+)\)", data)
        for index,(kind,source,destination,event) in enumerate(flags,1):
            key=(source,destination,event)
            if (kind=="set") == (key in pending):
                violation=index
                break
            if kind=="set":
                pending.add(key)
            else:
                pending.remove(key)
        assert violation==expected
        print(name, "A4 on source-order completion candidate:", "accepted" if violation is None else f"first violation at completion {violation}")
    issue=ROOT/"evidence/issues/981"
    src=issue/"quoted/fragment-1.mlir"
    result=subprocess.check_output([args.bin/"bishengir-opt",src,"--canonicalize-ext"])
    assert result==(issue/"local-canonicalize.mlir").read_bytes()
    for lane,expected in [(0,(0,7)),(63,(0,7)),(64,(7,7)),(127,(7,7))]:
        got=[]
        for stage,source in [("before",src),("after",issue/"local-canonicalize.mlir")]:
            text=lane_program(source,args.reader.resolve(),lane)
            reference=(issue/f"{stage}-{lane}.core").read_text()
            assert as_rocq(text)==as_rocq(reference)
            got.append(sequential_lane(text))
        assert tuple(got)==expected
        print(f"#981 lane {lane}, source={got[0]}, optimized={got[1]} (input=7, sequential completion)")
    test=ROOT.parent/"issue920/920.mlir"
    result=subprocess.check_output([args.bin/"bishengir-opt",test,"-cv-pipelining=pipeline-mode=skew enable-preload=true set-depth-in-unroll-mode=2 bypass-shape-registry=true"])
    fc=subprocess.run([args.bin/"FileCheck",test],input=result,capture_output=True)
    assert result==(test.parent/"920-exact.mlir").read_bytes() and fc.returncode==1 and fc.stderr.count(b"CHECK-NOT: excluded string found")==2
    print("#920 old compiler output matched snapshot; two upstream CHECK-NOT failures")
if __name__=="__main__":
    main()
