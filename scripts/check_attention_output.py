import json
import math
from pathlib import Path


def check(result_path, trace_path):
    result = json.loads(Path(result_path).read_text())
    assert result["profile"] == "host-float64"
    assert result["passed"] and result["cross_stage"]["passed"]
    assert result["configuration"]["program_count"] == 20
    assert {stage["stage"] for stage in result["stages"]} == {"hfusion", "hivm"}
    for stage in result["stages"]:
        assert stage["reference_passed"]
        assert len(stage["O"]) == 128
        assert all(len(row) == 128 for row in stage["O"])
        assert len(stage["log_sum_exp"]) == 128
        assert all(math.isfinite(x) for row in stage["O"] for x in row)
        assert all(math.isfinite(x) for x in stage["log_sum_exp"])
        print(stage["stage"], "O[0,:3]", stage["O"][0][:3],
              "LSE[0]", stage["log_sum_exp"][0])
    programs = {"hfusion": set(), "hivm": set()}
    copies = {"hfusion": set(), "hivm": set()}
    counts = {"hfusion": 0, "hivm": 0}
    with Path(trace_path).open() as stream:
        for line in stream:
            event = json.loads(line)
            stage = event["stage"]
            pid = event["program_id"]
            programs[stage].add(pid)
            counts[stage] += 1
            if event["entry"] == "sem_memref_copy":
                copies[stage].add(pid)
                assert event["loops"] == {"%arg16": pid}
                assert event["line"] > 0 and event["column"] > 0
    for stage in result["stages"]:
        name = stage["stage"]
        assert programs[name] == set(range(20))
        assert copies[name] == set(range(4))
        assert counts[name] == stage["primitive_calls"]
    print("Result shapes, finite values, reference comparisons and program traces passed")


if __name__ == "__main__":
    check("reports/attention.json", "reports/attention.jsonl")
