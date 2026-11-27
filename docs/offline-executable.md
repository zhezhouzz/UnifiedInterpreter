# 离线执行 HIVM 和 HFusion

从 CI 下载 `offline-interpreter-linux-x86_64`，解包并校验可执行文件。

```sh
tar -xzf unified-interpreter-linux-x86_64.tar.gz
sha256sum -c unified-interpreter.sha256
```

将 `unified-interpreter` 复制到目标机器即可离线运行。发行文件面向 Ubuntu 24.04 x86_64，需要兼容的 glibc、`/proc`、`/bin/tar` 和 PATH 中的 `gzip`。首次运行会解包到 `$XDG_CACHE_HOME/unified-interpreter`，默认使用 `~/.cache/unified-interpreter`。该目录需要允许写入和执行。

## 运行程序

按源文件所属的 IR 层选择 `--stage`。离线可执行文件会自动选择解析器，使用 Ascend 厂商汇编语法的文件也使用相同的命令。

```sh
./unified-interpreter run kernel.mlir --stage hivm > result.json
./unified-interpreter run kernel.mlir --stage hfusion > result.json
```

省略 `--launch` 时会自动生成输入。发行版收录的 benchmark 可以直接运行。对其他程序，解释器启动一个入口实例，自动选择的动态维度和普通整数参数在 11 至 20 之间。程序要求特定输入、多个执行实例或共享缓冲区时，请提供 `--launch launch.json`。

要复用输入，可以指定 `--seed 17`，也可以从一次自动运行的结果中保存实际配置，按需编辑后再次执行。

```sh
jq '.launch' result.json > launch.json
./unified-interpreter run kernel.mlir --stage hivm --launch launch.json
```

## 查看结果

标准输出为 JSON，诊断信息写入标准错误。先查看 `status` 和 `detail`。

| `status` | 含义 |
|---|---|
| `returned` | 程序正常返回。 |
| `deadlock` | 程序发生死锁，`detail` 列出阻塞位置。 |
| `invalid-memory` | 内存访问无效，`detail` 给出访问错误。 |
| `step-limit` | 执行达到步数上限，可通过 `--max-steps N` 调整。 |

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

实例需要指定块编号时填写 `block` 和 `subblock`，两者默认都是 0。需要限定管线时，在实例的 `pipes` 数组中填写管线名称，可选 `S`、`V`、`M`、`MTE1`、`MTE2`、`MTE3`、`FIX`。

在配置顶层可以用 `capacity` 指定每个同步信号最多保留多少次尚未消费的通知，默认 1。需要预置 HIVM 局部内存时，填写顶层数组 `local_initial`。例如其中一项 `{"stream":0,"space":"ub","base_bytes":256,"element":"f32","count":32,"value":3}` 表示从流 0 的 UB 字节位置 256 起，连续写入 32 个值为 3 的 f32 元素。
