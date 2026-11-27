import argparse
import json
from pathlib import Path


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("launches", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    catalog = json.loads(Path("benchmarks/ir-pairs/catalog.json").read_bytes())["benchmarks"]
    profiles = {}
    for name, pair in catalog.items():
        for stage in ("hivm", "hfusion"):
            key = stage + "/" + pair[stage]["sha256"]
            if key in profiles:
                continue
            launch = json.loads((args.launches / stage / name / "launch.json").read_bytes())
            for stream in launch["streams"]:
                for arg in stream["arguments"]:
                    if isinstance(arg, dict) and len(arg.get("initial", [])) > 32:
                        # 大型数值输入由运行时生成；保留决定地址的索引和长度。
                        del arg["initial"]
            profiles[key] = launch
    args.output.write_text(json.dumps(profiles, separators=(",", ":")) + "\n")


if __name__ == "__main__":
    main()
