**[Feature]: 【Q4】为 LIB_EVENT_ID 与 GraphSyncSolver/InjectSync 的 id 分配增加一致性防护**

### 需求背景

历史上发生过模板库 `LIB_EVENT_ID0`（EVENT_ID6）与编译器GraphSyncSolver/InjectSync 分配的 event id 冲突，导致 `wait_flag` 被无关`set_flag` 提前释放、load 读到脏数据、最终以标量越界形式报 Runtime 错误。`003f08450`（已在 master）已把 `LIB_EVENT_ID0` 移到 `EVENT_ID7` 并补齐预留 pipe pair，但该修复是"点修复"：`Utils.h` 新注释（50-53 行）明确写着"如果需要其他 eventId，请手工更新 sync 相关 pass 的`inject-sync::reservedEventIdNum`"——约定仍只存在于注释中，靠人工同步，没有任何可执行手段防止回归。

### 需求描述

1. 在 `GraphSyncSolver/Utility.cpp` 与 `InjectSync/SyncEventIdAllocation.cpp`   中把"模板库保留 id"写成单一共享常量（头文件唯一来源），两个分配器   均从该常量推导可用集合，而不是各自硬编码 `kTotalEventIdNum`；
2. 增加回归测试：对每个受影响 pipe pair，断言编译器生成的`set_flag/wait_flag` 不占用 `LIB_EVENT_ID*` 对应的硬件 event id；
3. 清理 `lib/Template/include/Utils.h` 中残留的过期注释（44-45 行"compiler which use id among 0 and 5" 挂在 MIN/MAX 宏上方，位置错乱且描述与实际分配不符）。

### 其他说明

`GraphSyncSolver`（`Utility.h` 的 `INTRA_CORE_EVENT_ID_NUM`）与`InjectSync`（`SyncEventIdAllocation.h` 的 `kTotalEventIdNum`）两个分配器各自硬编码 id 总数，修复需两处同步。