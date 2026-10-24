import json
import math
from pathlib import Path


def check():
    result = json.loads(Path("reports/attention-mixed.json").read_text())
    assert result["profile"] == "host-float64" and result["passed"]
    assert result["cross_stage"] is None
    assert len(result["stages"]) == 1
    stage = result["stages"][0]
    assert stage["stage"] == "mixed" and stage["reference_passed"]
    assert len(stage["O"]) == 128 and all(len(row) == 128 for row in stage["O"])
    assert len(stage["log_sum_exp"]) == 128
    assert all(math.isfinite(x) for row in stage["O"] for x in row)
    assert all(math.isfinite(x) for x in stage["log_sum_exp"])
    seen = set()
    programs = set()
    copies = set()
    count = 0
    with Path("reports/attention-mixed.jsonl").open() as stream:
        for line in stream:
            event = json.loads(line)
            assert event["stage"] == "mixed"
            count += 1
            programs.add(event["program_id"])
            if event["ir_stage"] is None:
                assert "opcode" not in event and "file" not in event
            else:
                assert event["ir_stage"] in {"common", "hfusion", "hivm"}
                assert event["line"] > 0 and event["column"] > 0
                seen.add((event["result"], event["ir_stage"], event["entry"]))
            if event["entry"] == "sem_memref_copy":
                copies.add(event["program_id"])
    assert count == stage["primitive_calls"]
    assert programs == set(range(20)) and copies == set(range(4))
    assert {
        ("%17", "hfusion", "sem_linalg_matmul"),
        ("%18", "hivm", "HIVM.evaluate"),
        ("%reduced", "hfusion", "sem_linalg_reduce"),
        ("%38", "common", "eval_scalar_operation"),
        ("%20", "hivm", "HIVM.evaluate"),
        ("%22", "hfusion", "sem_hfusion_cast"),
        ("%37", "hivm", "HIVM.evaluate"),
    } <= seen
    print("Mixed CLI: result shapes, reference, stage routing and program traces passed")


if __name__ == "__main__":
    check()
