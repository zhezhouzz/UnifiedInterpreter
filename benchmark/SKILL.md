# Benchmark 开发与复核

在仓库根目录运行 `python3 benchmark/bench.py`。Python、Ninja 和固定 BiShengIR build 是本机依赖；build 中需要 compile_commands.json 和已链接的工具。参数 `--build` 指向 build 根目录。复用 reader 可先执行以下命令。

```sh
scratch=$(mktemp -d)
python3 benchmark/tools/build_reader.py ~/GIT/Distributed/AscendNPU-IR/build "$scratch/reader"
python3 benchmark/bench.py --reader "$scratch/reader" --case double-buffer --demo
```

1. 新例放在 L1/L2/L3，填写元数据并保存原始 source 与固定编译产物。模型、人工变异、报告者快照和同源编译开关分别写明来源。L4 只作证据索引。
2. 用相同编译的全部入口建模 MIX，列出 AIC 与 AIV，按实际 launch 指定核比与参与者。硬件资源比例不能推出本次启动比例。
3. 在 tools/elaborate.py 添加完整节点映射并处理嵌套 region、DPS 读写参数、同步副作用及未知情况。程序的任何指定入口失败都返回带函数名和位置的诊断。
4. 需要执行时，在 case.json 填写共同输入和明确 oracle。对新运算先在具体解释中定义可支持的 view 和访存行为。增加硬件配置时把假设写入用例，单列其统计。
5. `python3 benchmark/bench.py --refresh` 可重新生成翻译、诊断、静态结果、执行记录和汇总。它仍要求编译输出逐字节一致。审阅变更后再用默认只读模式全量复核。
6. 演示和报告分别引用字节比较、所有入口整函数翻译、静态良构、执行成对结论。BFS 状态数包括初态；最短步数取 witness 数组的长度。协议观察器可在当前状态报告违例。
