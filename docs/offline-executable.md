# 离线执行 HIVM 和 HFusion

在收到的 tar 文件所在目录解包。如果从 GitHub 下载，请在 **Actions → Build and verify offline interpreter** 中选择一次成功构建，下载 **Artifacts** 下的 `offline-interpreter-linux-x86_64`，解开 ZIP 即可得到 tar 文件。

```sh
tar -xf unified-interpreter-benchmarks-linux-x86_64.tar
cd unified-interpreter-benchmarks
```

以下示例在解包目录中运行。包内的 84 个 benchmark 位于 `benchmarks/<用例名称>/`，每个用例都有 `hivm.mlir` 和 `hfusion.mlir`。

可执行文件面向 Ubuntu 24.04 x86_64，需要兼容的 glibc、`/proc`、`/bin/tar` 和 PATH 中的 `gzip`。Ubuntu 22.04 自带的 glibc 无法运行此发行文件。

首次运行会解包到 `$XDG_CACHE_HOME/unified-interpreter`，默认使用 `~/.cache/unified-interpreter`，需要允许写入和执行。请确保运行用户可以在 `$XDG_STATE_HOME`（默认 `~/.local/state`）下创建和读写文件。

## 运行程序

将尖括号内的内容替换为实际参数，去掉尖括号。`<IR层>` 取 `hivm` 或 `hfusion`，与源文件一致。省略输出重定向时，结果直接显示在终端。

```text
./unified-interpreter run <MLIR源文件路径> --stage <IR层> --seed 17 > <结果文件路径>
```

省略 `--launch` 时会自动生成输入。发行版收录的 benchmark 可以直接运行。对其他程序，解释器启动一个入口实例，自动选择的动态维度和普通整数参数在 11 至 20 之间。程序要求特定输入、多个执行实例或共享缓冲区时，用 `--launch <启动配置文件路径>` 指定配置。

要用相同输入再次运行同一程序，重复使用相同的 `--seed` 即可。需要查看、保存或修改自动生成的输入时，可以用 `jq` 提取启动配置，再通过 `--launch` 传入。显式传入的配置文件请自行保留。

```text
jq '.launch' <结果文件路径> > <启动配置文件路径>
./unified-interpreter run <MLIR源文件路径> --stage <IR层> --launch <启动配置文件路径> > <重放结果文件路径>
```

例如，在解包目录中用相同输入运行 HIVM 向量加法两次：

```sh
./unified-interpreter run vector_add_hivm.mlir --stage hivm --seed 17 > result.json
./unified-interpreter run vector_add_hivm.mlir --stage hivm --seed 17 > second.json
```

运行 HFusion 版本：

```sh
./unified-interpreter run vector_add_hfusion.mlir --stage hfusion --seed 17 > hfusion-result.json
```

这三个结果文件中的 `status` 都应为 `returned`。

## 查看结果

命令正常结束时查看标准输出中的 JSON，例如 `jq '{status, detail, returns}' result.json`。即使退出码为 0，也请查看 `status` 判断 kernel 是否遇到死锁或无效内存访问。命令以非零退出码结束时，先查看终端的标准错误；此时重定向得到的结果文件可能为空。

| `status` | 含义 |
|---|---|
| `returned` | 程序正常返回。 |
| `deadlock` | 程序发生死锁，`detail` 列出阻塞位置。 |
| `invalid-memory` | 内存访问无效，`detail` 给出访问错误。 |

`returns` 按执行流列出函数返回值。通过缓冲区输出结果的程序，请查看 `memory_hex` 中对应存储名称的最终字节。

### 用两次运行判断 benchmark 是否暴露问题

将 `src` 设为待测源文件的路径，`stage` 设为对应的 IR 层。以下 Bash 示例使用相同输入运行两次，将结果保存在新建的 `$out` 目录中。

```bash
src=vector_add_hivm.mlir
stage=hivm
out=$(mktemp -d "$PWD/benchmark-run-XXXXXX")
run_pair() {
  for n in 1 2; do
    XDG_STATE_HOME="$out" ./unified-interpreter run "$src" --stage "$stage" --seed 17 \
      > "$out/$n.json" 2> "$out/$n.err" ||
      { rc=$?; cat "$out/$n.err" >&2; return "$rc"; }
    jq -es 'length == 1 and (.[0].status | type == "string")' "$out/$n.json" >/dev/null ||
      { echo "无法读取 $out/$n.json" >&2; return 1; }
  done
}
run_pair
```

例如，测试 `benchmarks/cv/scene1/correct/hfusion.mlir` 时，将 `src` 设为该路径，`stage` 设为 `hfusion`。需要指定输入时，将示例中的 `--seed 17` 换为 `--launch launch.json`，两次使用同一份配置。只有 `run_pair` 成功时才比较两份结果。若只有一次成功，该次已报告的故障仍然有效。

```sh
jq '{status, detail, extent: .schedule.extent, targets: .schedule.targets}' "$out/1.json" "$out/2.json"
```

| 输出证据 | 可作出的判断 |
|---|---|
| 任一次 `status = deadlock` | 该输入触发死锁。`detail` 列出阻塞位置。 |
| 任一次 `status = invalid-memory` | 该输入触发无效内存访问。分别查看两次的 `detail`：同一个程序可能一次报告下标越界，另一次报告读取未初始化的描述符。 |
| `schedule.extent = "race_prefix"` | 本次结果报告了数据竞争。`targets` 列出两个冲突访问。程序仍可正常返回。 |
| 两次均正常返回，且均无竞争目标 | 这两次执行未观察到上述问题。 |
| 命令失败或未生成有效 JSON | 该次测试未完成，保留标准错误和操作位置。 |

每个目标的 `source` 给出入口、操作和循环轮次。`event` 的五个元素依次是流编号、操作位置、管线、该操作的动态出现编号、事件阶段。循环中的同一个操作可以执行多次，比较时需要保留动态编号。

定位操作时先查找 `source.entry`，再按 `source.path` 中从 0 开始的序号查找。例如 `[2,0,0,1]` 表示入口的第 3 个操作、该操作的第 1 个 region、第 1 个 block 中的第 2 个操作。可用 `source.opcode` 核对名称。竞争目标给出的是解析后的操作位置；要确定冲突字节范围，还需结合源码的访存操作和本次启动配置。

要确认同一对冲突访问在两次执行中以相反的顺序出现，可以执行下面的命令。输出 `true` 表示已观察到顺序交换。输出 `false` 时，仍需按上表检查每次运行的结果。

```sh
jq -es '
  def pair:
    .schedule as $s
    | if $s.extent == "race_prefix" and ($s.targets | length) == 2 then
        ($s.targets | map(.event)) as $p
        | if $p[0] != $p[1] and $s.events[-1] == $p[1]
             and any($s.events[:-1][]; . == $p[0]) then $p else null end
      else null end;
  if length != 2 or any(.[]; (.status | type) != "string" or (.schedule | type) != "object")
    then error("需要两份完整的运行结果")
  elif .[0].launch != .[1].launch then error("两次启动配置不同")
  else map(pair) | .[0] != null and .[1] == (.[0] | reverse) end
' "$out/1.json" "$out/2.json"
```

批量处理时，上述 `jq` 命令输出 `true` 的退出码为 0，输出 `false` 的退出码为 1。读取文件或校验输入失败时查看标准错误，将该组记为未完成。手工指定启动配置时，请在两次执行之间保持该文件内容相同。

## 填写启动配置

在源文件中找到要执行的 `func.func`，将函数名写入 `entry`，按声明顺序为每个形参填写一个 `arguments` 元素，包括输出缓冲区。模块只有一个函数时可以省略 `entry`。

解包目录中的 `issue316_missing_ready_hivm.mlir` 定义了 `@issue316_vexp`。三个形参依次是输入缓冲区、输出缓冲区和循环次数。每轮读取 1024 个 f16 元素。下面的配置执行两轮，因此输入有 2048 个元素。输出的 1024 个元素已在 IR 中声明，可以省略其形状。

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

将此 JSON 保存为 `tiles.json`，然后执行：

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

需要同时运行多个实例时，使用 `streams` 数组。每项填写该实例的入口和参数，数组下标就是流编号，从 0 开始。解包目录中的 `fixed.hivm.mlir` 定义了一个 cube 生产者和一个 vector 消费者。两个入口的形参都是循环次数，因此流 0 调用 `@producer(2)` 发送两次通知，流 1 调用 `@consumer(2)` 等待两次通知。`edges: [[0, 1]]` 指定通知从流 0 发往流 1。

```json
{
  "streams": [
    {"entry": "@producer", "arguments": [2], "core": "cube"},
    {"entry": "@consumer", "arguments": [2], "core": "vector"}
  ],
  "edges": [[0, 1]]
}
```

将此 JSON 保存为 `streams.json`，然后执行：

```sh
./unified-interpreter run fixed.hivm.mlir --stage hivm --launch streams.json > streams-result.json
jq '{status, returns}' streams-result.json
```

预期 `status` 为 `returned`，`returns` 为 `[[],[]]`，表示两个实例都已返回且均无函数返回值。

实例需要指定块编号时填写 `block` 和 `subblock`，两者默认都是 0。需要限定管线时，在实例的 `pipes` 数组中填写管线名称，可选 `S`、`V`、`M`、`MTE1`、`MTE2`、`MTE3`、`FIX`。

在配置顶层可以用 `capacity` 指定每个同步信号最多保留多少次尚未消费的通知，默认 1。需要预置 HIVM 局部内存时，填写顶层数组 `local_initial`。例如其中一项 `{"stream":0,"space":"ub","base_bytes":256,"element":"f32","count":32,"value":3}` 表示从流 0 的 UB 字节位置 256 起，连续写入 32 个值为 3 的 f32 元素。
