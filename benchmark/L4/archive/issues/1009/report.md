## 问题

A5 SIMT 的调试信息存在三处问题。

- 内联的 Triton 辅助函数沿用 kernel 的文件作用域，导致 `standard.py` 的 272、302 行显示在用例文件中。
- SSA 为 `i1` 的布尔值使用 1 位调试类型，BiSheng 生成的 `DW_AT_byte_size` 为 0。
- 开启局部变量调试时，生成的 SIMT `umulhi` 库调用会截断实参的位置范围。进入 `test_index_select_flaggems_ascend.py` 的 kernel 后，msdebug 可能显示入参不可用。

## 预期

保留内联源码的文件名，使用 1 字节的布尔调试类型，并在局部变量调试路径展开生成的 32 位无符号乘积高位运算，以保留 kernel 入参的位置。

## 验证

增加三个 A5 编译回归用例，检查 LLVM IR 中的内联文件作用域、布尔类型和入参记录，并验证仅开启行号信息时仍保留原来的库调用。
