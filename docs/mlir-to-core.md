# HFusion 和 HIVM 到 Core Language

`race mlir` 通过标准输入把 MLIR 文本一次性交给 Python/xDSL。Python 返回带版本号的模块 AST，OCaml 绑定实参并按操作转换到 `Core_lang.program` 或 `Core_lang.Device.program`。转换同时保留源函数、指令路径和位置。可以用 `Hivm_trace.Module_ast.parse` 和 `Hivm_trace.lower_mlir` 从 OCaml 调用同一流程。

## 从 MLIR 生成和回放报告

通过 `scripts/bootstrap_attention.sh` 配置 xDSL 环境后，使用项目的 OCaml switch 在仓库根目录运行以下命令。

```sh
dune exec unified-interpreter -- race mlir examples/kernels/vector_add_hfusion.mlir

mkdir -p _build
cat > _build/issue316-launch.json <<'JSON'
{"arguments":[{"shape":[3072]},null,3]}
JSON

dune exec unified-interpreter -- race mlir examples/kernels/issue316_missing_ready_hivm.mlir \
  --launch _build/issue316-launch.json --backend smt --save _build/issue316-races.json
dune exec unified-interpreter -- race mlir examples/kernels/issue316_missing_ready_hivm.mlir \
  --launch _build/issue316-launch.json --replay _build/issue316-races.json
dune exec unified-interpreter -- race mlir examples/kernels/issue316_missing_ready_hivm.mlir \
  --launch _build/issue316-launch.json --hivm
```

缺等待版在这个启动配置下有五对竞争，`--replay` 验证十条执行前缀。有等待版 `issue316_vexp_hivm.mlir` 使用相同配置时有零对。默认输出 `core-race-1`，`--hivm` 导出按原 AST 路径定位的 `hivm-race-1`。

`--generic` 读取 MLIR generic assembly。对需要 BiShengIR 方言注册的自定义汇编，可以通过 `--bishengir-opt /path/to/bishengir-opt` 先用该工具输出 generic assembly。源码包含多个函数时，用 `--entry` 或 launch JSON 选择入口。

## 启动参数

- `arguments` 按入口形参顺序排列。标量使用 JSON 数字或布尔值。静态形状的 buffer 可以用 `null`，动态维度通过 `{"shape":[...]}` 给定。
- Buffer 可以声明 `storage`、`bytes`、`offset`、`strides` 和 `initial`。同名 `storage` 共享底层存储，`offset` 和 `strides` 按元素计。`initial` 从存储起点按元素初始化具体设备执行的内容。
- 用 `streams` 给出多个入口及各自的 `arguments`、`block`、`core`、`subblock` 或 `pipes`。跨流 flag 使用 `edges` 中的 `[发送流编号,接收流编号]`。流按数组顺序从零编号。

## 语义覆盖

- Core 转换保留张量的 SSA 依赖，以及 memref 的存储身份、动态视图、读写范围和显式管线同步。它覆盖 `scf.if`、`scf.for` 的循环携带值、计算样例中的 HFusion/Linalg 和 HIVM 张量算子，以及 HIVM 的 flag 和 barrier。完整 tile 的 `mmadL1` 将输入搬运、内部交接和矩阵计算映射到同一个源操作的不同 `part`。
- 有掩码的向量存储和间接访存走设备执行器，以实际内存中的掩码和偏移决定访问。HFusion 的张量 gather/scatter 可以在这个路径上使用张量初始化、算术、取出和插入元素。设备路径要求发射控制和视图描述在不同调度中保持固定。超出语义覆盖的操作会报告诊断。
- 两条路径都可以对具体启动用 `bfs` 或 `smt`。Core 报告的地址单位是字节，设备报告的地址单位是位。数值解释器继续作为 HFusion/HIVM 计算样例的参考。
