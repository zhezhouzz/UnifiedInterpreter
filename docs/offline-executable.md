# 离线执行 HIVM 和 HFusion

在 GitHub 仓库的 **Actions → Build binaries and Docker image** 中选择 `release_v0` 分支的一次成功构建，在 **Artifacts** 下载 `offline-interpreter-linux-x86_64`。解压下载的 ZIP 后，进入其中的 `_build/release/offline/`，执行：

```sh
tar -xzf unified-interpreter-linux-x86_64.tar.gz
sha256sum -c unified-interpreter.sha256
```

看到 `unified-interpreter: OK` 后，将这个可执行文件复制到目标机器即可。下文命令在可执行文件所在目录执行，也可以用其绝对路径从其他目录启动。发行文件面向 Ubuntu 24.04 x86_64，需要兼容的 glibc、`/proc`、`/bin/tar` 和 PATH 中的 `gzip`。Ubuntu 22.04 自带的 glibc 无法运行此发行文件。

首次运行会解包到 `$XDG_CACHE_HOME/unified-interpreter`，默认使用 `~/.cache/unified-interpreter`，需要允许写入和执行。调度历史默认保存在 `~/.local/state/unified-interpreter/traces.sqlite3`，设置了 `XDG_STATE_HOME` 时使用该目录下的 `unified-interpreter/traces.sqlite3`。运行用户需要能读写数据库，并能在其目录中创建文件。单次试运行可加 `--trace-db :memory:`。

## 运行程序

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

纯标量程序正常返回时，`schedule.events` 为空。

`returns` 按执行流列出函数返回值。通过缓冲区输出结果的程序，请查看 `memory_hex` 中对应存储名称的最终字节。`schedule` 记录本次执行的调度。相同输入可能因调度顺序不同而产生不同结果。

### 用两次运行判断 benchmark 是否暴露问题

只需要可执行文件和 benchmark 的 MLIR 源文件。选择源文件及其 IR 层，使用默认调度执行两次。两次使用相同的输入、同一个新建的历史数据库，并分别保存输出。下面的命令适用于 Bash，`src` 和 `stage` 按实际文件填写。

```bash
src=vector_add_hivm.mlir
stage=hivm
out=$(mktemp -d ./benchmark-run-XXXXXX)
run_pair() {
  for n in 1 2; do
    ./unified-interpreter run "$src" --stage "$stage" --seed 17 \
      --trace-db "$out/history.sqlite3" > "$out/$n.json" 2> "$out/$n.err" ||
      { rc=$?; cat "$out/$n.err" >&2; return "$rc"; }
    jq -es 'length == 1 and (.[0].status | type == "string")' "$out/$n.json" >/dev/null ||
      { echo "无法读取 $out/$n.json" >&2; return 1; }
  done
}
run_pair
```

将示例中的 `src` 换为手头文件的实际路径。例如文件名为 `benchmarks/12.hfusion.mlir` 时，使用该路径并设置 `stage=hfusion`。每份 IR 源文件使用一个新的 `out` 目录。需要指定输入时，两次均将 `--seed 17` 换为同一个 `--launch launch.json`。保存或复用启动配置只会复现输入；复用历史数据库会影响下次选中的调度。只有 `run_pair` 成功时才比较两份结果；若只有一次成功，该次已报告的故障仍然有效。

```sh
jq '{status, detail, extent: .schedule.extent, targets: .schedule.targets}' "$out/1.json" "$out/2.json"
```

| 输出证据 | 可作出的判断 |
|---|---|
| 任一次 `status = deadlock` | 该输入触发死锁。`detail` 列出阻塞位置。 |
| 任一次 `status = invalid-memory` | 该输入触发无效内存访问。分别查看两次的 `detail`：同一个程序可能一次报告下标越界，另一次报告读取未初始化的描述符。 |
| `schedule.extent = "race_prefix"` | 调度器报告数据竞争。`targets` 是按本次完成或执行顺序排列的两个冲突访问。即使 `status = returned`，程序也可能存在竞争。 |
| 两次均正常返回，且均无竞争目标 | 这两次执行未观察到上述问题。其他输入或调度仍可能触发问题。 |
| 命令失败或未生成有效 JSON | 该次测试未完成，保留标准错误和操作位置。 |

每个目标的 `source` 给出入口、操作和循环轮次。`event` 的五个元素依次是流编号、操作位置、管线、该操作的动态出现编号、事件阶段。循环中的同一个操作可以执行多次，比较时需要保留动态编号。

定位操作时先查找 `source.entry`，再按 `source.path` 中从 0 开始的序号查找。例如 `[2,0,0,1]` 表示入口的第 3 个操作、该操作的第 1 个 region、第 1 个 block 中的第 2 个操作。可用 `source.opcode` 核对名称。竞争目标给出的是解析后的操作位置；要确定冲突字节范围，还需结合源码的访存操作和本次启动配置。

要确认两条 trace 实际展示了同一对访问交换顺序，可以执行下面的命令。它比较完整的动态事件标识，并检查两个事件在各自的 `schedule.events` 中按目标顺序出现。输出 `true` 即确认了这对竞争；输出 `false` 时仍需按上表检查各次结果。两个 trace 的哈希不同或最终缓冲区的值相同，都无法单独判定竞争。

```sh
jq -s '
  def pair:
    .schedule as $s
    | if $s.extent == "race_prefix" and ($s.targets | length) == 2 then
        ($s.targets | map(.event)) as $p
        | if $p[0] != $p[1] and $s.events[-1] == $p[1]
             and any($s.events[:-1][]; . == $p[0]) then $p else null end
      else null end;
  map(pair) | length == 2 and .[0] != null and .[1] == (.[0] | reverse)
' "$out/1.json" "$out/2.json"
```

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

这里的输出缓冲区为 2048 字节。函数通过缓冲区写回结果，因此即使正常返回，`returns` 也可以是 `[[]]`。

若保持两轮并将输入的 `shape` 改为 `[1024]`，第二轮创建子视图时请求下标 1024 至 2047，超出了输入范围。程序以退出码 0 输出 JSON，`status` 为 `invalid-memory`。`detail` 指出出错的 `memref.subview`、请求的下标和维度大小，以及本例的源码位置 `issue316_missing_ready_hivm.mlir:24:5`。可用 `jq '{status, detail}' tiles-result.json` 查看。

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
