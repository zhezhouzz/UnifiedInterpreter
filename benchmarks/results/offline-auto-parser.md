# 离线可执行文件自动选择解析器

使用重新打包的 Linux x86_64 可执行文件执行 84 个 benchmark，每个 benchmark 的 HIVM 和 HFusion 版本各一次，共 168 次。全部通过启动和执行状态检查。

```sh
.venv-attention/bin/python scripts/check_random_launch.py _build/offline/unified-interpreter
```

每次执行均使用种子 `17` 自动生成输入，使用默认 BFS 调度和独立的内存 trace 数据库。命令行省略了两个解析器选项。检查项包括返回 JSON 中的种子、IR 层，以及执行状态是否为 `returned`、`deadlock` 或 `invalid-memory`。此项测试未逐例核对数值结果。
