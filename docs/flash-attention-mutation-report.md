# FlashAttention IR 变异测试报告

在同一输入的成对实验中，HFusion 和 HIVM 的输出地址变体均触发了未初始化读检查。K 转置、V stride 和分母归约的变体产生了可预测的错误计算结果，独立参考比较检出了这些差异。

2026 年 11 月 24 日在 `codex/flash-attention-ir-mutations` 的 `3b53c6c` 上复跑。环境使用 OCaml 5.3.0、Dune 3.23.1 和 xDSL 0.74.0。

## 测试设计

两份基准来自仓库归档的 FlashAttention IR。每种变异在 HFusion 和 HIVM 各构造一份样本，模拟编译降级时的一项错误决策。基准和对应变体使用同一份输入及入口签名。实验使用 CPU `host-float64`，固定单 batch、单 head、`N=D=128`、`scale=1`，执行非因果注意力和单个 K/V tile。[样本定义](../attention_test/fixtures/flash_attention_mutations.json)

两个输入的 V 都只有 `V[1,0]=1`。其中一个令 Q、K 全零，另一个令 Q 的每一行为第 0 个基向量，K 只有 `K[0,1]=1`。两种输入在正确 IR 上的分数均为零，因此 `O` 的第 0 列全为 `1/128`，其余元素为零，所有行的 `log_sum_exp` 都是 `log(128)`。

数值用例逐元素比较 `O` 和 `log_sum_exp`，要求实际值与预期值有限，绝对误差至多为 `1e-10 + 1e-9 × abs(expected)`。每个数值变体既要匹配按其 IR 推导的 `ir_expected`，也要偏离正确程序的 `source_expected`。运行时错误用例同时断言异常类型和触发位置。[回归断言](../attention_test/flash_attention_mutation_test.ml)

## 执行结果

两份基准分别用两个输入运行，四次都匹配正确程序的参考。下表列出两个阶段各自运行所得的相同结果。数值列展示 `O` 第 0 行的前两个元素和该行的 `log_sum_exp`，校验覆盖完整数组。

| 变异 | 独立预期 | HFusion 和 HIVM 实测 |
| --- | --- | --- |
| K 转置丢失 | 唯一分数为 1 的 key 对应 V 的第 1 行。非零输出为 `e/(127+e)`，`log_sum_exp=log(127+e)`。 | `[0.02095527160970061, 0]`，`4.865365036119043` |
| V stride 互换 | 非零输出从第 0 列移到第 1 列，`log_sum_exp` 保持 `log(128)`。 | `[0, 0.0078125]`，`4.852030263919617` |
| 分母从求和改为取最大值 | 指数权重全为 1，分母从 128 变为 1。非零输出为 1，`log_sum_exp=0`。 | `[1, 0]`，`0` |
| O tile 地址复用 | 四个有效 program 都写到第一个 tile，O 的其余 tile 保持未初始化。 | 在 `materialize_output` 抛出 `ReadUninitialized` |

本次复跑中，四次基准和六次数值变体相对于各自预期的最大绝对误差均为 0。两个地址变体均命中指定异常和位置。`dune runtest --force` 全部通过。[样本生成与重放](user-guide.md#flashattention-ir-变异测试集)

## 检查能力

**运行时内存检查。** 地址变体通过前端和执行校验，直至读取输出时由解释器报告 `ReadUninitialized`。回归测试同时要求 trace 到达 `materialize_output` 和捕获该类型的异常。这给出了两个方言阶段调用同一未初始化读规则的端到端证据。[异常断言](../attention_test/flash_attention_mutation_test.ml) · [内存错误映射](../rocq/Memory/Handler.v)

**与源程序的语义比较。** 六个合法变体的输出符合变异后 IR 的语义。测试再与正确程序的独立参考比较，检出转置、stride 和归约三个模式带来的差异。该结论针对归档的单 tile FlashAttention 和上述 CPU 数值模型。[数值参考推导](user-guide.md#flashattention-ir-变异测试集)

## 重放命令

在仓库根目录生成测试集并重放。

```sh
python3 scripts/generate_flash_attention_mutations.py --output _build/flash-attention-mutations-report
opam exec --switch=unified-interpreter -- dune exec ./attention_test/flash_attention_mutation_test.exe -- _build/flash-attention-mutations-report
opam exec --switch=unified-interpreter -- dune runtest --force
```
