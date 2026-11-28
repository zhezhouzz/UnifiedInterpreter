# 离线执行 HIVM 和 HFusion

在 GitHub 仓库的 **Actions → Build binaries and Docker image** 中选择 `release_v0` 分支的一次成功构建，在 **Artifacts** 下载 `offline-interpreter-linux-x86_64`。解压下载的 ZIP 后，进入其中的 `_build/release/offline/`，执行：

```sh
tar -xzf unified-interpreter-linux-x86_64.tar.gz
sha256sum -c unified-interpreter.sha256
```

看到 `unified-interpreter: OK` 后，将这个可执行文件复制到目标机器即可。下文命令在可执行文件所在目录执行，也可以用其绝对路径从其他目录启动。发行文件面向 Ubuntu 24.04 x86_64，需要兼容的 glibc、`/proc`、`/bin/tar` 和 PATH 中的 `gzip`。Ubuntu 22.04 自带的 glibc 无法运行此发行文件。

首次运行会解包到 `$XDG_CACHE_HOME/unified-interpreter`，默认使用 `~/.cache/unified-interpreter`，需要允许写入和执行。调度历史默认保存在 `~/.local/state/unified-interpreter/traces.sqlite3`，设置了 `XDG_STATE_HOME` 时使用该目录下的 `unified-interpreter/traces.sqlite3`。运行用户需要能读写数据库，并能在其目录中创建文件。单次试运行可加 `--trace-db :memory:`。

## 运行程序

运行 `./unified-interpreter run --help` 查看执行命令的用法。

按源文件所属的 IR 层选择 `--stage`。离线可执行文件会自动选择解析器。首次试运行可从同一版本的仓库下载 [HIVM 向量加法源码](../examples/kernels/vector_add_hivm.mlir) 和 [HFusion 向量加法源码](../examples/kernels/vector_add_hfusion.mlir)，按原文件名保存在可执行文件旁。两个版本都应返回 `returned`。如果手里只有发行文件，可在构建对应的 GitHub 提交页面打开 `examples/kernels/`，分别下载两个 `.mlir` 原文件，再复制到离线机器。

```sh
./unified-interpreter run vector_add_hivm.mlir --stage hivm --seed 17 > result.json
./unified-interpreter run vector_add_hfusion.mlir --stage hfusion --seed 17 > hfusion-result.json
```

省略 `--launch` 时会自动生成输入。发行版收录的 benchmark 可以直接运行。对其他程序，解释器启动一个入口实例，自动选择的动态维度和普通整数参数在 11 至 20 之间。程序要求特定输入、多个执行实例或共享缓冲区时，请提供 `--launch launch.json`。

要复用输入，可以指定相同种子，也可以从自动运行的结果中保存实际配置。下面的命令需要 `jq`。显式传入配置后，请保留 `launch.json` 供下次使用，该次结果不会再次附上配置。

```sh
jq '.launch' result.json > launch.json
./unified-interpreter run vector_add_hivm.mlir --stage hivm --launch launch.json > replay.json
```

## 查看结果

命令正常结束时查看标准输出中的 JSON，例如 `jq '{status, detail, returns}' result.json`。即使退出码为 0，也请查看 `status` 判断 kernel 是否遇到死锁或无效内存访问。命令以非零退出码结束时，先查看终端的标准错误；此时重定向得到的结果文件可能为空。

| `status` | 含义 |
|---|---|
| `returned` | 程序正常返回。 |
| `deadlock` | 程序发生死锁，`detail` 列出阻塞位置。 |
| `invalid-memory` | 内存访问无效，`detail` 给出访问错误。 |
| `step-limit` | 使用 `--builtin` 直接执行时达到步数上限。 |

每次解释执行的步数上限为 10,000,000 步。默认调度模式下，如果生成 trace 时达到步数上限，程序会以退出码 3 结束，将 `scheduler incomplete: execution step limit` 和操作位置写入标准错误。纯标量程序正常返回时，`schedule.events` 为空。只需按解释器自身顺序执行时，可使用 `--builtin`，此时结果中的 `schedule` 为 `null`。

单次调度请求的默认超时为 120 秒。使用 `--scheduler-timeout-ms N` 可按毫秒调整。超时时退出码为 3，标准错误以 `scheduler incomplete:` 开头，随后给出超时原因，例如 `timeout`。

`returns` 按执行流列出函数返回值。通过缓冲区输出结果的程序，请查看 `memory_hex` 中对应存储名称的最终字节。`schedule` 记录本次执行的调度。相同输入可能因调度顺序不同而产生不同结果。

## 填写启动配置

在源文件中找到要执行的 `func.func`，将函数名写入 `entry`，按声明顺序为每个形参填写一个 `arguments` 元素，包括输出缓冲区。模块只有一个函数时可以省略 `entry`。

例如，`@issue316_vexp` 的三个形参依次是输入缓冲区、输出缓冲区和循环次数。每轮读取 1024 个 f16 元素。下面的配置执行两轮，因此输入有 2048 个元素。输出的 1024 个元素已在 IR 中声明，可以省略其形状。[示例源码](../examples/kernels/issue316_missing_ready_hivm.mlir)

```json
{
  "entry": "@issue316_vexp",
  "arguments": [
    {"storage": "input", "shape": [2048], "initial": [1.0, 2.0]},
    {"storage": "output"},
    2
  ]
}
```

将此 JSON 保存为 `tiles.json`，下载链接中的源文件后执行：

```sh
./unified-interpreter run issue316_missing_ready_hivm.mlir --stage hivm --launch tiles.json > tiles-result.json
jq '{status, detail, output_bytes: (.memory_hex.output | length / 2)}' tiles-result.json
```

这里的输出缓冲区为 2048 字节。函数通过缓冲区写回结果，因此即使正常返回，`returns` 也可以是 `[[]]`。若保持两轮并将输入缩为 1024 个元素，第二轮需要的子视图会超出输入范围。此例以退出码 2 结束，标准错误包含 `memref.subview: subview is out of range`，结果文件为空。

整数和 `index` 参数填写 JSON 整数，浮点参数填写 JSON 数字，`i1` 填写 `true`、`false`、`0` 或 `1`。缓冲区使用下表中的字段。静态形状和布局均已确定、使用独立存储和默认初值时，该参数可以直接填 `null`。

| 缓冲区字段 | 填写方法 |
|---|---|
| `shape` | 类型有动态维度时给出完整形状。例如 `memref<?x4xf32>` 可以填 `[3,4]`。固定维度须与 IR 一致。 |
| `storage` | 为存储命名，方便从 `memory_hex` 查找结果。多个参数或执行流需要共享内存时使用相同名称，地址空间须一致。省略时每个参数使用独立存储。 |
| `initial` | 从底层存储起点连续写入的元素数组。其余数值字节默认为零。共享存储只需初始化一次。 |
| `offset`、`strides` | 类型声明了动态布局时填写，以元素为单位。`strides` 包含每个维度的步长。 |
| `base_bytes` | 视图起点相对底层存储的字节偏移，默认 0。 |
| `bytes` | 需要指定底层存储大小时填写字节数，须容纳所有视图和初值。省略时自动计算。 |

### 启动多个执行实例

需要同时运行多个实例时，使用 `streams` 数组。每项填写该实例的入口和参数，数组下标就是流编号，从 0 开始。下面的程序启动一个 cube 生产者和一个 vector 消费者。两个入口的形参都是循环次数，因此流 0 调用 `@producer(2)` 发送两次通知，流 1 调用 `@consumer(2)` 等待两次通知。`edges: [[0, 1]]` 指定通知从流 0 发往流 1。[示例源码](../benchmark/L2/cross-loop-placement/fixed.hivm.mlir)

```json
{
  "streams": [
    {"entry": "@producer", "arguments": [2], "core": "cube"},
    {"entry": "@consumer", "arguments": [2], "core": "vector"}
  ],
  "edges": [[0, 1]]
}
```

将此 JSON 保存为 `streams.json`，下载该示例的 `fixed.hivm.mlir` 后执行：

```sh
./unified-interpreter run fixed.hivm.mlir --stage hivm --launch streams.json > streams-result.json
jq '{status, returns}' streams-result.json
```

预期 `status` 为 `returned`，`returns` 为 `[[],[]]`，表示两个实例都已返回且均无函数返回值。在 `schedule.events` 中核对通知次数时，按 `complete` 计数；同一次操作还会有一条 `submit` 记录。

实例需要指定块编号时填写 `block` 和 `subblock`，两者默认都是 0。需要限定管线时，在实例的 `pipes` 数组中填写管线名称，可选 `S`、`V`、`M`、`MTE1`、`MTE2`、`MTE3`、`FIX`。

在配置顶层可以用 `capacity` 指定每个同步信号最多保留多少次尚未消费的通知，默认 1。需要预置 HIVM 局部内存时，填写顶层数组 `local_initial`。例如其中一项 `{"stream":0,"space":"ub","base_bytes":256,"element":"f32","count":32,"value":3}` 表示从流 0 的 UB 字节位置 256 起，连续写入 32 个值为 3 的 f32 元素。
