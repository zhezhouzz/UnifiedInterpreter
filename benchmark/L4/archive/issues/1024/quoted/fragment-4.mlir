%start = llvm.mul %0, %c8192 : i64        // 只算起点（此处为 0），没有逐 lane 的 stride 寻址
hivm.vstus.post.f32 %vec, %ptr, 16, %addr // 连续写 16 字节 = 4 × f32，4 个值被挤在一起
hivm.vstas %addr, %ptr, 0, 0              // 提交
