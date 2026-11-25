# 芯片配置

两个 MLIR 文件是同一编译器对空模块执行 `hacc-append-device-spec` 得到的设备参数。上游 TableGen 将容量与对齐表示为 bit；下表换算为 KiB。core 的硬件配置可从此处读取容量，但每个 benchmark 仍需从分核函数、启动配置和 sub-block guard 确定活动流与同步参与者。[固定版本的目标定义](https://gitcode.com/Ascend/AscendNPU-IR/blob/fbdf863a8c8c268e5cfea0d5f1d921e227267fd5/bishengir/include/bishengir/Dialect/HACC/Targets/NPUTargetSpec.td)

| 参数 | [Ascend910B1](Ascend910B1.mlir) | [Ascend950PR_9579](Ascend950PR_9579.mlir) |
|---|---:|---:|
| 架构标识（TableGen） | dav-c220 | dav-c310 |
| 整片 Cube / Vector 数量 | 24 / 48 | 28 / 56 |
| 每个 UB / L1 容量（KiB） | 192 / 512 | 248 / 512 |
| L0A / L0B / L0C 容量（KiB） | 64 / 64 / 128 | 64 / 64 / 256 |
| 第一批 add 实际运行主体 | AIV | AIV，包括其调用的 vector functions |
| add 的管道边 | V→MTE2、MTE2→V、V→MTE3 | V→MTE2、MTE2→V、V→MTE3 |

**配置层次。** 硬件 core 比例描述可用资源。程序的 0:1、1:1 或 1:2 工作划分及实际收件人按 kernel 记录，保留运行 guard。核内 flag 以流与有向 (set_pipe, wait_pipe, event_id) 区分。跨核记录同步操作种类、发出端、目标 pipe、参与者与 flag ID。第一批 kern3 是显式运行 solver 的单测，没有指定物理芯片或活动 AIV 数量。[Auto-Subtiling](https://ascendnpu-ir.gitcode.com/en/developer_guide/features/auto_subtiling.html)

**跨代行为。** 910B 类 memory-based MIX 同步可涉及 FFTS；RegBase 支持分核后重建跨核同步。950 的逻辑 sync_block 操作与针对单个物理计数器的 sync_intra_block 操作有不同的配对含义。实现 core 时应保留操作种类。一个 set 逐接收者消费且同键最多一轮在途，是可选的 benchmark 协议；A2 的官方跨核接口使用计数器。芯片资料与单轮协议应分别标注。[固定版 Auto-Sync](https://gitcode.com/Ascend/AscendNPU-IR/blob/fbdf863a8c8c268e5cfea0d5f1d921e227267fd5/docs/source/en/developer_guide/features/auto_sync.md) · [HIVM Dialect](https://ascendnpu-ir.gitcode.com/en/developer_guide/dialects/hivm_dialect.html) · [A2 CrossCoreSetFlag](https://www.hiascend.com/doc_center/source/zh/canncommercial/80RC2/apiref/opdevgapi/atlasascendc_api_07_0268.html)
