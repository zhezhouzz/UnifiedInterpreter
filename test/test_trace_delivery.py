import json
import os
import struct
import subprocess
import sys
import tempfile
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path


def main():
    exe, source, scratch, issue316 = (Path(arg).resolve() for arg in sys.argv[1:])
    with tempfile.TemporaryDirectory(dir=scratch) as folder:
        directory = Path(folder)
        env = dict(os.environ, XDG_STATE_HOME=folder, TMPDIR=folder)
        launch = directory / "launch.json"
        arg = {"storage": "x", "shape": [3], "initial": [7]}
        launch.write_text(json.dumps({"entry": "stream_0", "arguments": [arg]}))
        args = [exe, "run", source, "--stage", "hivm", "--launch", launch]

        def request(*options):
            result = json.loads(subprocess.check_output([*args, *options], env=env))
            assert result["status"] == "returned"
            return result["schedule"], struct.unpack("<iii", bytes.fromhex(result["memory_hex"]["x"]))

        first, memory = request()
        assert first["extent"] == "race_prefix" and not first["reused"]
        assert memory == (7, 7, 7)
        path_alias = directory / "fifo.mlir"
        path_alias.symlink_to(source)
        args[2] = path_alias
        launch.write_text(json.dumps({"streams": [{"entry": "@stream_0", "arguments": [arg]}], "capacity": 1}))
        limited = subprocess.run([*args, "--max-steps", "1"], env=env, capture_output=True)
        assert limited.returncode == 2 and b"unknown option" in limited.stderr
        second, memory = request()
        assert second["extent"] == "race_prefix" and not second["reused"]
        assert memory == (7, 7, 0)
        assert second["targets"] == first["targets"][::-1]
        assert [target["event"] for target in first["targets"]] == first["events"][-2:]
        third, memory = request()
        assert third["extent"] == "terminal" and not third["reused"]
        assert memory == (7, 7, 7)
        schedules = {trace["hash"] for trace in (first, second, third)}
        assert len(schedules) == 3
        repeated, _ = request()
        assert repeated["reused"] and repeated["hash"] in schedules

        concurrent = ["--trace-db", directory / "concurrent.sqlite"]
        with ThreadPoolExecutor(6) as pool:
            results = list(pool.map(lambda _: request(*concurrent)[0], range(6)))
        new = [trace["hash"] for trace in results if not trace["reused"]]
        assert len(new) == 3 and set(new) == schedules
        assert all(trace["hash"] in schedules for trace in results)
        arg["initial"] = [19]
        launch.write_text(json.dumps({"entry": "stream_0", "arguments": [arg]}))
        changed, memory = request()
        assert not changed["reused"] and memory == (19, 19, 19)

        launch.write_text(json.dumps({"arguments": [{"shape": [1024]}, None, 2]}))
        command = [exe, "run", issue316, "--stage", "hivm", "--launch", launch]
        for options in (["--trace-db", ":memory:"], ["--builtin"]):
            result = json.loads(subprocess.check_output([*command, *options], env=env))
            assert result["status"] == "invalid-memory"
            assert "memref.subview" in result["detail"] and issue316.name in result["detail"]
            assert "1024 through 2047" in result["detail"]
            if result["schedule"] is not None:
                assert result["schedule"]["terminal"] == "invalid-memory"


if __name__ == "__main__":
    main()
