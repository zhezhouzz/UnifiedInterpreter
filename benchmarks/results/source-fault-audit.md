# 默认输入下的 benchmark 源码核查

共 84 个 benchmark。每行链接到两份实际编译产物。源码判断采用项目的队列与 flag 规则，race 表示同址、至少一方写入的两个完成事件在合法执行前缀中可以交换。若还要求两条执行都正常返回，请排除明确标注的死锁前缀。

两列执行结果来自既有记录。`R` 表示 scheduler 给出了 race 目标且解释器有回放；`D` 表示解释器报告死锁，`O` 表示报告越界，`U` 表示未初始化描述符，`返回` 表示所记录的执行正常结束。记录中的一对目标不代表覆盖同一程序内的所有竞争事件对。

| Benchmark | HFusion 记录 | HIVM 记录 | 源码判断依据 |
|---|---|---|---|
| cv/scene1/correct | [R · linalg.fill / memref.copy](../../benchmarks/ir-pairs/cv/scene1/correct/hfusion.mlir) | [R · func.call / func.call](../../benchmarks/ir-pairs/cv/scene1/correct/hivm.mlir) | HFusion 涉及填充、复制和稀疏索引；HIVM 涉及 AIC/AIV 跨流与向量函数。已定位可交换的事件，但未证明所有间接地址在所有调度下均合法。 |
| cv/scene1/error | [R · linalg.fill / memref.copy](../../benchmarks/ir-pairs/cv/scene1/error/hfusion.mlir) | [R · func.call / func.call](../../benchmarks/ir-pairs/cv/scene1/error/hivm.mlir) | HFusion 涉及填充、复制和稀疏索引；HIVM 涉及 AIC/AIV 跨流与向量函数。已定位可交换的事件，但未证明所有间接地址在所有调度下均合法。 |
| fixture/all-barrier | [返回](../../benchmarks/ir-pairs/fixture/all-barrier/hfusion.mlir) | [返回](../../benchmarks/ir-pairs/fixture/all-barrier/hivm.mlir) | 两次复制经过同一中间元素；HIVM 的全管线屏障隔开两次完成，HFusion 调用顺序执行。 |
| fixture/allocation | [返回](../../benchmarks/ir-pairs/fixture/allocation/hfusion.mlir) | [R · func.call / func.call](../../benchmarks/ir-pairs/fixture/allocation/hivm.mlir) | 分配后对同一元素写、读；HIVM 分别派发任务，HFusion 的读函数已无读取。 |
| fixture/block-data-wait | [返回](../../benchmarks/ir-pairs/fixture/block-data-wait/hfusion.mlir) | [返回](../../benchmarks/ir-pairs/fixture/block-data-wait/hivm.mlir) | HIVM 的写入、跨流 set/wait、读取形成先后关系；HFusion 的读已消除。 |
| fixture/block-handoff | [返回](../../benchmarks/ir-pairs/fixture/block-handoff/hfusion.mlir) | [返回](../../benchmarks/ir-pairs/fixture/block-handoff/hivm.mlir) | 检查发送方写入和接收方读取之间的通知；HFusion 只保留实际写入。 |
| fixture/blocked-before-loop | [返回](../../benchmarks/ir-pairs/fixture/blocked-before-loop/hfusion.mlir) | [D](../../benchmarks/ir-pairs/fixture/blocked-before-loop/hivm.mlir) | HIVM 在循环入口之前等待无人发送的信号；HFusion 投影没有该等待。 |
| fixture/broadcast | [返回](../../benchmarks/ir-pairs/fixture/broadcast/hfusion.mlir) | [R · func.call / func.call](../../benchmarks/ir-pairs/fixture/broadcast/hivm.mlir) | 两个接收者等待同一次广播，之后的同址读、写相互独立；HFusion 消除了读取。 |
| fixture/concurrent-loop | [返回](../../benchmarks/ir-pairs/fixture/concurrent-loop/hfusion.mlir) | [R · func.call / func.call](../../benchmarks/ir-pairs/fixture/concurrent-loop/hivm.mlir) | HIVM 循环写与另一执行流的读取重叠；HFusion 的读函数为空。 |
| fixture/disjoint-reads-writes | [返回](../../benchmarks/ir-pairs/fixture/disjoint-reads-writes/hfusion.mlir) | [返回](../../benchmarks/ir-pairs/fixture/disjoint-reads-writes/hivm.mlir) | HIVM 写入位置 0、读取位置 1；HFusion 只保留写入。 |
| fixture/duplicate-set | [返回](../../benchmarks/ir-pairs/fixture/duplicate-set/hfusion.mlir) | [D](../../benchmarks/ir-pairs/fixture/duplicate-set/hivm.mlir) | HIVM 第二次 set 因容量 1 而阻塞；它后面的两个 PIPE_V 复制可以先完成，分别写、读 mem[1]。这是死锁前缀中的竞争。 |
| fixture/else-branch | [返回](../../benchmarks/ir-pairs/fixture/else-branch/hfusion.mlir) | [R · func.call / func.call](../../benchmarks/ir-pairs/fixture/else-branch/hivm.mlir) | 可达分支执行两次有重叠的复制；HIVM 为异步调用，HFusion 调用顺序执行。 |
| fixture/fifo-copy | [返回](../../benchmarks/ir-pairs/fixture/fifo-copy/hfusion.mlir) | [R · func.call / func.call](../../benchmarks/ir-pairs/fixture/fifo-copy/hivm.mlir) | 先复制 0→1，再复制 1→2；HIVM 的两个完成事件可交换，HFusion 中是顺序标量循环。 |
| fixture/hivm-two-loads | [R · linalg.copy / linalg.copy](../../benchmarks/ir-pairs/fixture/hivm-two-loads/hfusion.mlir) | [R · load / load](../../examples/kernels/two_loads_hivm.mlir) | 两个不同来源写入同一目的缓冲区；HFusion 对应两次 linalg.copy。 |
| fixture/invalid-allocation-offset | [O](../../benchmarks/ir-pairs/fixture/invalid-allocation-offset/hfusion.mlir) | [O](../../benchmarks/ir-pairs/fixture/invalid-allocation-offset/hivm.mlir) | reserve 分配一个元素，两层的 write_shared 均写下标 1。HIVM 的 read_shared 也读取下标 1，可先于写任务完成而触发读越界。 |
| fixture/large-bound-return | [返回](../../benchmarks/ir-pairs/fixture/large-bound-return/hfusion.mlir) | [返回](../../benchmarks/ir-pairs/fixture/large-bound-return/hivm.mlir) | 循环的布尔携带值控制提前退出；不能只依据巨大上界判定尾部写入可达。 |
| fixture/late-address | [返回](../../benchmarks/ir-pairs/fixture/late-address/hfusion.mlir) | [R · func.call / func.call](../../benchmarks/ir-pairs/fixture/late-address/hivm.mlir) | HIVM 先读取 11，随后循环写入随迭代变化的地址，覆盖 11；HFusion 删除了读取。 |
| fixture/local-handoff | [返回](../../benchmarks/ir-pairs/fixture/local-handoff/hfusion.mlir) | [返回](../../benchmarks/ir-pairs/fixture/local-handoff/hivm.mlir) | 写与读之间存在匹配的 set_flag/wait_flag；HFusion 只保留写入。 |
| fixture/loop-allocation | [返回](../../benchmarks/ir-pairs/fixture/loop-allocation/hfusion.mlir) | [返回](../../benchmarks/ir-pairs/fixture/loop-allocation/hivm.mlir) | 循环体每轮重新分配，虽然访问下标相同，底层存储不同。 |
| fixture/loop-write | [返回](../../benchmarks/ir-pairs/fixture/loop-write/hfusion.mlir) | [R · func.call / func.call](../../benchmarks/ir-pairs/fixture/loop-write/hivm.mlir) | 每轮写同一位置；HIVM 各次调用独立，HFusion 同一执行流内顺序写。 |
| fixture/loop-zero | [返回](../../benchmarks/ir-pairs/fixture/loop-zero/hfusion.mlir) | [R · func.call / func.call](../../benchmarks/ir-pairs/fixture/loop-zero/hivm.mlir) | 默认输入跳过循环，随后仍执行两个有重叠的复制。 |
| fixture/nested-loop | [返回](../../benchmarks/ir-pairs/fixture/nested-loop/hfusion.mlir) | [R · func.call / func.call](../../benchmarks/ir-pairs/fixture/nested-loop/hivm.mlir) | 内外循环产生重复的同址写；HIVM 的异步完成可交换。 |
| fixture/other-pipe-barrier | [返回](../../benchmarks/ir-pairs/fixture/other-pipe-barrier/hfusion.mlir) | [R · func.call / func.call](../../benchmarks/ir-pairs/fixture/other-pipe-barrier/hivm.mlir) | 屏障约束的管线与两个复制所在的管线不同，复制仍冲突。 |
| fixture/overlapping-writes | [返回](../../benchmarks/ir-pairs/fixture/overlapping-writes/hfusion.mlir) | [R · func.call / func.call](../../benchmarks/ir-pairs/fixture/overlapping-writes/hivm.mlir) | 两次各写两个元素，起点分别为 0 和 1，共享下标 1。 |
| fixture/pipe-barrier | [返回](../../benchmarks/ir-pairs/fixture/pipe-barrier/hfusion.mlir) | [返回](../../benchmarks/ir-pairs/fixture/pipe-barrier/hivm.mlir) | 两个复制之间等待其所在管线；HFusion 顺序执行两个复制。 |
| fixture/repeated-broadcast | [返回](../../benchmarks/ir-pairs/fixture/repeated-broadcast/hfusion.mlir) | [D](../../benchmarks/ir-pairs/fixture/repeated-broadcast/hivm.mlir) | 一个接收者没有消费第一次广播；第二次发送和另一接收者的第二次等待都受阻，后者的写入不可达。 |
| fixture/return-from-loop | [返回](../../benchmarks/ir-pairs/fixture/return-from-loop/hfusion.mlir) | [返回](../../benchmarks/ir-pairs/fixture/return-from-loop/hivm.mlir) | 第一次循环将继续标志置为假，返回前无冲突访问。 |
| fixture/shared-allocation | [返回 / U](../../benchmarks/ir-pairs/fixture/shared-allocation/hfusion.mlir) | [R · func.call / func.call](../../benchmarks/ir-pairs/fixture/shared-allocation/hivm.mlir) | 两个执行流共享描述符槽；先发布描述符时 HIVM 的读写任务访问同一合法元素，先读取描述符时可能出现未初始化访问。 |
| fixture/stride-minus-two | [返回](../../benchmarks/ir-pairs/fixture/stride-minus-two/hfusion.mlir) | [R · func.call / func.call](../../benchmarks/ir-pairs/fixture/stride-minus-two/hivm.mlir) | 循环指标递减，写入目的地址仍相同；HIVM 两次任务可交换。 |
| fixture/three-accesses | [返回](../../benchmarks/ir-pairs/fixture/three-accesses/hfusion.mlir) | [R · func.call / func.call](../../benchmarks/ir-pairs/fixture/three-accesses/hivm.mlir) | 两个写任务和一个读任务访问同一元素；HFusion 删除不使用的读，写操作顺序执行。 |
| fixture/two-reads | [返回](../../benchmarks/ir-pairs/fixture/two-reads/hfusion.mlir) | [返回](../../benchmarks/ir-pairs/fixture/two-reads/hivm.mlir) | 两次均为读操作，HFusion 还消除了没有被使用的读取。 |
| fixture/two-streams | [返回](../../benchmarks/ir-pairs/fixture/two-streams/hfusion.mlir) | [R · func.call / func.call](../../benchmarks/ir-pairs/fixture/two-streams/hivm.mlir) | 两个执行流分别读写共享 GM；HFusion 中读函数为空。 |
| fixture/wrong-flag | [返回](../../benchmarks/ir-pairs/fixture/wrong-flag/hfusion.mlir) | [D](../../benchmarks/ir-pairs/fixture/wrong-flag/hivm.mlir) | HIVM 等待 EVENT_ID1，实际只发送 EVENT_ID0；MTE2 后续读受阻。 |
| fixture/zero-step | [返回](../../benchmarks/ir-pairs/fixture/zero-step/hfusion.mlir) | [返回](../../benchmarks/ir-pairs/fixture/zero-step/hivm.mlir) | 条件中的继续标志初始为假，复制分支不可达。 |
| flash-attention | [R · memref.copy / linalg.transpose](../../artifacts/flash_attention/ir/hfusion_level.mlir) | [返回](../../benchmarks/ir-pairs/flash-attention/hivm.mlir) | HFusion 复制与转置间使用同一缓冲区；HIVM 入口以程序编号划分输出块。对缺少记录的其他间接访问不作安全证明。 |
| issue316/missing-ready | [R · linalg.copy / linalg.elemwise_unary](../../benchmarks/ir-pairs/issue316/missing-ready/hfusion.mlir) | [D](../../examples/kernels/issue316_missing_ready_hivm.mlir) | HFusion 的复制与计算缺少屏障；HIVM 第一轮 load 写入 bufA，vexp 读取 bufA，缺少 MTE2→V 等待。第三轮重复发送未消费的就绪令牌。 |
| issue316/ordered | [返回](../../benchmarks/ir-pairs/issue316/ordered/hfusion.mlir) | [返回](../../examples/kernels/issue316_vexp_hivm.mlir) | HFusion 用 barrier 分开复制与计算，HIVM 有相应的就绪和释放通知。 |
| litao/add-Ascend910B1/buggy | [R · memref.copy / linalg.elemwise_binary](../../benchmark/L1/triton-add/Ascend910B1/source.mlir) | [R · load / vadd](../../benchmark/L1/triton-add/Ascend910B1/buggy.hivm.mlir) | 检查输入复制、向量加法与写回。HIVM fixed 在跨管线读写之间加入成对通知；两份 HFusion 计算相同。 |
| litao/add-Ascend910B1/fixed | [R · memref.copy / linalg.elemwise_binary](../../benchmark/L1/triton-add/Ascend910B1/source.mlir) | [返回](../../benchmark/L1/triton-add/Ascend910B1/fixed.hivm.mlir) | 检查输入复制、向量加法与写回。HIVM fixed 在跨管线读写之间加入成对通知；两份 HFusion 计算相同。 |
| litao/broadcast-guard/buggy | [返回](../../benchmark/L2/broadcast-guard/buggy.hfusion.mlir) | [返回](../../benchmark/L2/broadcast-guard/buggy.hivm.mlir) | HIVM 消费条件分别为 subblock<1 和 <2；当前只有一次广播，未消费的令牌不会单独阻止程序返回。 |
| litao/broadcast-guard/fixed | [返回](../../benchmark/L2/broadcast-guard/fixed.hfusion.mlir) | [返回](../../benchmark/L2/broadcast-guard/fixed.hivm.mlir) | HIVM 消费条件分别为 subblock<1 和 <2；当前只有一次广播，未消费的令牌不会单独阻止程序返回。 |
| litao/counter-capacity/buggy | [返回](../../benchmark/L2/counter-capacity/buggy.hfusion.mlir) | [返回](../../benchmark/L2/counter-capacity/buggy.hivm.mlir) | buggy 向 flag 6 发送 16 次，接收方也等待 16 次，可交替消费；第 16 次暂时阻塞并不足以形成全局死锁。fixed 分流到 flag 7。 |
| litao/counter-capacity/fixed | [返回](../../benchmark/L2/counter-capacity/fixed.hfusion.mlir) | [返回](../../benchmark/L2/counter-capacity/fixed.hivm.mlir) | buggy 向 flag 6 发送 16 次，接收方也等待 16 次，可交替消费；第 16 次暂时阻塞并不足以形成全局死锁。fixed 分流到 flag 7。 |
| litao/cross-loop-placement/buggy | [返回](../../benchmark/L2/cross-loop-placement/buggy.hfusion.mlir) | [D](../../benchmark/L2/cross-loop-placement/buggy.hivm.mlir) | HIVM 默认循环两轮；buggy 只在循环外发送一次，fixed 在循环内每轮发送。HFusion 无跨核等待。 |
| litao/cross-loop-placement/fixed | [返回](../../benchmark/L2/cross-loop-placement/fixed.hfusion.mlir) | [返回](../../benchmark/L2/cross-loop-placement/fixed.hivm.mlir) | HIVM 默认循环两轮；buggy 只在循环外发送一次，fixed 在循环内每轮发送。HFusion 无跨核等待。 |
| litao/double-buffer/buggy | [R · linalg.copy / linalg.elemwise_unary](../../benchmark/L2/double-buffer/buggy.hfusion.mlir) | [R · vabs / vabs](../../benchmark/L2/double-buffer/buggy.hivm.mlir) | 轮次选择两块输入 UB，第 3 轮复用第 1 块；fixed 加了复用等待。历轮 vabs 还写同一输出 UB，两版本均须检查写写竞争。 |
| litao/double-buffer/fixed | [R · linalg.copy / linalg.elemwise_unary](../../benchmark/L2/double-buffer/fixed.hfusion.mlir) | [R · vabs / vabs](../../benchmark/L2/double-buffer/fixed.hivm.mlir) | 轮次选择两块输入 UB，第 3 轮复用第 1 块；fixed 加了复用等待。历轮 vabs 还写同一输出 UB，两版本均须检查写写竞争。 |
| litao/empty-preload/buggy | [返回](../../benchmark/L2/empty-preload/buggy.hfusion.mlir) | [D](../../benchmark/L2/empty-preload/buggy.hivm.mlir) | HIVM buggy 的 producer 直接返回，consumer 等待；fixed 增加发送。HFusion 投影没有等待。 |
| litao/empty-preload/fixed | [返回](../../benchmark/L2/empty-preload/fixed.hfusion.mlir) | [返回](../../benchmark/L2/empty-preload/fixed.hivm.mlir) | HIVM buggy 的 producer 直接返回，consumer 等待；fixed 增加发送。HFusion 投影没有等待。 |
| litao/event-collision/buggy | [返回](../../benchmark/L2/event-collision/buggy.hfusion.mlir) | [返回](../../benchmark/L2/event-collision/buggy.hivm.mlir) | buggy 连续两次发送同一编号，也有两次匹配等待；目标管线可以消费。fixed 使用不同编号。源码没有数据访问。 |
| litao/event-collision/fixed | [返回](../../benchmark/L2/event-collision/fixed.hfusion.mlir) | [返回](../../benchmark/L2/event-collision/fixed.hivm.mlir) | buggy 连续两次发送同一编号，也有两次匹配等待；目标管线可以消费。fixed 使用不同编号。源码没有数据访问。 |
| litao/indirect-atomic/buggy | [R · linalg.copy / memref.load](../../benchmark/L2/indirect-atomic/buggy.hfusion.mlir) | [R · custom / load](../../benchmark/L2/indirect-atomic/buggy.hivm.mlir) | 核对间接更新和后续读取；HIVM fixed 加入跨管线等待。HFusion 的复制和标量读取仍共享缓冲区。 |
| litao/indirect-atomic/fixed | [R · linalg.copy / memref.load](../../benchmark/L2/indirect-atomic/fixed.hfusion.mlir) | [返回](../../benchmark/L2/indirect-atomic/fixed.hivm.mlir) | 核对间接更新和后续读取；HIVM fixed 加入跨管线等待。HFusion 的复制和标量读取仍共享缓冲区。 |
| litao/missing-wait/buggy | [R · linalg.copy / linalg.elemwise_unary](../../benchmark/L1/missing-wait/buggy.hfusion.mlir) | [R · load / vabs](../../benchmark/L1/missing-wait/buggy.hivm.mlir) | HIVM buggy 在 load 后发通知但 vabs 未等待，fixed 补上等待；HFusion 的复制与计算无对应屏障。 |
| litao/missing-wait/fixed | [R · linalg.copy / linalg.elemwise_unary](../../benchmark/L1/missing-wait/fixed.hfusion.mlir) | [返回](../../benchmark/L1/missing-wait/fixed.hivm.mlir) | HIVM buggy 在 load 后发通知但 vabs 未等待，fixed 补上等待；HFusion 的复制与计算无对应屏障。 |
| litao/mix-handoff/buggy | [R · memref.copy / linalg.copy](../../benchmark/L1/mix-handoff/buggy.hfusion.mlir) | [R · fixpipe / load](../../benchmark/L1/mix-handoff/buggy.hivm.mlir) | HIVM fixed 在消费端增加跨流等待；buggy 的 fixpipe 写与 load 读可交换。两份 HFusion 的复制仍需检查。 |
| litao/mix-handoff/fixed | [R · memref.copy / linalg.copy](../../benchmark/L1/mix-handoff/fixed.hfusion.mlir) | [返回](../../benchmark/L1/mix-handoff/fixed.hivm.mlir) | HIVM fixed 在消费端增加跨流等待；buggy 的 fixpipe 写与 load 读可交换。两份 HFusion 的复制仍需检查。 |
| litao/scalar-fallback/buggy | [R · linalg.elemwise_unary / memref.store](../../benchmark/L2/scalar-fallback/buggy.hfusion.mlir) | [R · vabs / memref.store](../../benchmark/L2/scalar-fallback/buggy.hivm.mlir) | HIVM buggy 的向量操作与标量写共享地址；fixed 增加双向同步。HFusion 的缓冲区计算与标量写仍有冲突。 |
| litao/scalar-fallback/fixed | [R · linalg.elemwise_unary / memref.store](../../benchmark/L2/scalar-fallback/fixed.hfusion.mlir) | [返回](../../benchmark/L2/scalar-fallback/fixed.hivm.mlir) | HIVM buggy 的向量操作与标量写共享地址；fixed 增加双向同步。HFusion 的缓冲区计算与标量写仍有冲突。 |
| litao/slot-release/buggy | [R · linalg.elemwise_unary / linalg.copy](../../benchmark/L2/slot-release/buggy.hfusion.mlir) | [R · vabs / load](../../benchmark/L2/slot-release/buggy.hivm.mlir) | HIVM buggy 可在前一计算读取 UB 后或之前覆盖该槽，fixed 等待释放。HFusion 计算及复制仍重叠。 |
| litao/slot-release/fixed | [R · linalg.elemwise_unary / linalg.copy](../../benchmark/L2/slot-release/fixed.hfusion.mlir) | [返回](../../benchmark/L2/slot-release/fixed.hivm.mlir) | HIVM buggy 可在前一计算读取 UB 后或之前覆盖该槽，fixed 等待释放。HFusion 计算及复制仍重叠。 |
| litao/wrong-event/buggy | [R · linalg.copy / linalg.elemwise_unary](../../benchmark/L1/wrong-event/buggy.hfusion.mlir) | [D](../../benchmark/L1/wrong-event/buggy.hivm.mlir) | HIVM buggy 发送 ID0 却等待 ID1，后续计算无法完成；fixed 编号匹配。HFusion 计算与复制之间无等待。 |
| litao/wrong-event/fixed | [R · linalg.copy / linalg.elemwise_unary](../../benchmark/L1/wrong-event/fixed.hfusion.mlir) | [返回](../../benchmark/L1/wrong-event/fixed.hivm.mlir) | HIVM buggy 发送 ID0 却等待 ID1，后续计算无法完成；fixed 编号匹配。HFusion 计算与复制之间无等待。 |
| litao/zero-trip-alias/buggy | [R · linalg.copy / linalg.elemwise_unary](../../benchmark/L2/zero-trip-alias/buggy.hfusion.mlir) | [R · load / vabs](../../benchmark/L2/zero-trip-alias/buggy.hivm.mlir) | 检查循环次数为零时选中的缓冲区；buggy 仍有 load 与 vabs 的冲突，fixed 增加匹配的跨管线通知。 |
| litao/zero-trip-alias/fixed | [R · linalg.copy / linalg.elemwise_unary](../../benchmark/L2/zero-trip-alias/fixed.hfusion.mlir) | [返回](../../benchmark/L2/zero-trip-alias/fixed.hivm.mlir) | 检查循环次数为零时选中的缓冲区；buggy 仍有 load 与 vabs 的冲突，fixed 增加匹配的跨管线通知。 |
| regression/barrier | [返回](../../benchmarks/ir-pairs/regression/barrier/hfusion.mlir) | [返回](../../benchmarks/ir-pairs/regression/barrier/hivm.mlir) | 循环每轮写入后执行本管线屏障；HFusion 同一执行流顺序写入。 |
| regression/disjoint | [返回](../../benchmarks/ir-pairs/regression/disjoint/hfusion.mlir) | [返回](../../benchmarks/ir-pairs/regression/disjoint/hivm.mlir) | 循环中访问不同的下标，逐轮增加的地址互不重叠。 |
| regression/early-return | [返回](../../benchmarks/ir-pairs/regression/early-return/hfusion.mlir) | [返回](../../benchmarks/ir-pairs/regression/early-return/hivm.mlir) | 循环携带的继续条件使后续同址写不可达。 |
| regression/flag-expression | [返回](../../benchmarks/ir-pairs/regression/flag-expression/hfusion.mlir) | [R · func.call / func.call](../../benchmarks/ir-pairs/regression/flag-expression/hivm.mlir) | 默认参数使发送条件成立；收到通知之后，同址读写间仍可能交换完成顺序。 |
| regression/fresh-allocation | [返回](../../benchmarks/ir-pairs/regression/fresh-allocation/hfusion.mlir) | [返回](../../benchmarks/ir-pairs/regression/fresh-allocation/hivm.mlir) | 每轮分配独立的内存对象；下标相同并不产生跨轮冲突。 |
| regression/handoff | [返回](../../benchmarks/ir-pairs/regression/handoff/hfusion.mlir) | [返回](../../benchmarks/ir-pairs/regression/handoff/hivm.mlir) | 检查共享地址的写入、发送、等待、读取顺序。 |
| regression/late-branch | [返回](../../benchmarks/ir-pairs/regression/late-branch/hfusion.mlir) | [R · func.call / func.call](../../benchmarks/ir-pairs/regression/late-branch/hivm.mlir) | 默认循环到达末尾条件，条件写与先前提交的读取访问同一位置。 |
| regression/nested-descending | [返回](../../benchmarks/ir-pairs/regression/nested-descending/hfusion.mlir) | [R · func.call / func.call](../../benchmarks/ir-pairs/regression/nested-descending/hivm.mlir) | 递减内循环嵌套在外循环中，重复提交对同一元素的写操作。 |
| regression/opposite-inputs | [返回](../../benchmarks/ir-pairs/regression/opposite-inputs/hfusion.mlir) | [返回](../../benchmarks/ir-pairs/regression/opposite-inputs/hivm.mlir) | 两个入口共享默认条件值 0，选择互补的发送和等待分支，使写入先于读取。 |
| regression/repeated-write | [返回](../../benchmarks/ir-pairs/regression/repeated-write/hfusion.mlir) | [R · func.call / func.call](../../benchmarks/ir-pairs/regression/repeated-write/hivm.mlir) | 两轮异步写操作访问同一地址。 |
| regression/shared-parameter | [返回](../../benchmarks/ir-pairs/regression/shared-parameter/hfusion.mlir) | [返回](../../benchmarks/ir-pairs/regression/shared-parameter/hivm.mlir) | 默认参数均为 3；两个入口要求的值分别是 3 和 4，读写不会同时发生。 |
| regression/single-broadcast | [返回](../../benchmarks/ir-pairs/regression/single-broadcast/hfusion.mlir) | [D](../../benchmarks/ir-pairs/regression/single-broadcast/hivm.mlir) | 生产者发送一次，接收者等待两次。其后的读写无法执行。 |
| regression/two-broadcasts | [返回](../../benchmarks/ir-pairs/regression/two-broadcasts/hfusion.mlir) | [R · func.call / func.call](../../benchmarks/ir-pairs/regression/two-broadcasts/hivm.mlir) | 两个发送者使两次等待均可完成；随后同址读写任务存在竞争。 |
| regression/zero-trip | [返回](../../benchmarks/ir-pairs/regression/zero-trip/hfusion.mlir) | [R · func.call / func.call](../../benchmarks/ir-pairs/regression/zero-trip/hivm.mlir) | 默认轮数为 0，循环后的分支仍提交同址读写。 |
| row-sum | [返回](../../examples/kernels/row_sum_hfusion.mlir) | [返回](../../benchmarks/ir-pairs/row-sum/hivm.mlir) | 单入口按行归约，输入 3×4，输出 3 个元素。 |
| strided-output | [R · bufferization.materialize_in_destination / bufferization.materialize_in_destination](../../benchmarks/hfusion/strided-output.mlir) | [R · bufferization.materialize_in_destination / bufferization.materialize_in_destination](../../benchmarks/ir-pairs/strided-output/hivm.mlir) | 两个流写同一份 7 元素输出，偏移为各自基址加循环指标模 4；两个输出范围在下标 3 重叠。 |
| vector-add | [返回](../../examples/kernels/vector_add_hfusion.mlir) | [返回](../../examples/kernels/vector_add_hivm.mlir) | 单入口读取两个 8 元素输入，将逐元素加法结果写入独立的 8 元素输出。 |
| vectorlayout/fail | [R · memref.copy / linalg.transpose](../../benchmarks/ir-pairs/vectorlayout/fail/hfusion.mlir) | [R · func.call / func.call](../../benchmarks/hivm/vectorlayout_fail.mlir) | HFusion 复制与转置、HIVM 向量函数访问共享缓冲区；谓词参与间接地址选择。记录覆盖部分事件对，未穷尽所有谓词和调度。 |
| vectorlayout/ok | [R · memref.copy / linalg.transpose](../../benchmarks/ir-pairs/vectorlayout/ok/hfusion.mlir) | [R · func.call / func.call](../../benchmarks/hivm/vectorlayout_ok.mlir) | HFusion 复制与转置、HIVM 向量函数访问共享缓冲区；谓词参与间接地址选择。记录覆盖部分事件对，未穷尽所有谓词和调度。 |

[两次调度的逐项结果](scheduled-interpreter-matrix.csv) · [死锁和越界的终止 trace](bfs-terminal-faults.csv) · [竞争事件对数量](scheduler-mlir-matrix.csv)

HFusion 的 `fixture/invalid-allocation-offset` 在另一条历史 trace 中还报告过未初始化描述符。HIVM 的已归档越界 trace 定位在写操作；读任务先执行的读越界来自源码推断。

### 竞争事件对的回放覆盖

以下 34 个版本各有多对已记录的竞争事件。按两个目标事件的完整源位置和动态身份合并顺序相反的 trace，这批每项两次的解释器执行在每个版本中只选中一对。下表的数量来自同一默认输入下的 scheduler 全事件对分析。可据此区分解释器已经报告程序有竞争和测试已经覆盖每一对竞争。

| Benchmark | IR | Scheduler 事件对数 |
|---|---|---:|
| cv/scene1/correct | hfusion | 7 |
| cv/scene1/correct | hivm | 68 |
| cv/scene1/error | hfusion | 7 |
| cv/scene1/error | hivm | 68 |
| fixture/concurrent-loop | hivm | 3 |
| fixture/three-accesses | hivm | 3 |
| flash-attention | hfusion | 12 |
| issue316/missing-ready | hfusion | 9 |
| litao/add-Ascend910B1/buggy | hfusion | 2 |
| litao/add-Ascend910B1/buggy | hivm | 4 |
| litao/add-Ascend910B1/fixed | hfusion | 2 |
| litao/double-buffer/buggy | hfusion | 9 |
| litao/double-buffer/buggy | hivm | 5 |
| litao/double-buffer/fixed | hfusion | 9 |
| litao/double-buffer/fixed | hivm | 2 |
| litao/indirect-atomic/buggy | hfusion | 35 |
| litao/indirect-atomic/buggy | hivm | 3 |
| litao/indirect-atomic/fixed | hfusion | 35 |
| litao/missing-wait/buggy | hfusion | 2 |
| litao/missing-wait/fixed | hfusion | 2 |
| litao/mix-handoff/buggy | hfusion | 2 |
| litao/mix-handoff/fixed | hfusion | 2 |
| litao/scalar-fallback/buggy | hfusion | 2 |
| litao/scalar-fallback/buggy | hivm | 2 |
| litao/scalar-fallback/fixed | hfusion | 2 |
| litao/wrong-event/buggy | hfusion | 2 |
| litao/wrong-event/fixed | hfusion | 2 |
| litao/zero-trip-alias/buggy | hfusion | 2 |
| litao/zero-trip-alias/fixed | hfusion | 2 |
| regression/nested-descending | hivm | 3 |
| vectorlayout/fail | hfusion | 4 |
| vectorlayout/fail | hivm | 29 |
| vectorlayout/ok | hfusion | 4 |
| vectorlayout/ok | hivm | 33 |
