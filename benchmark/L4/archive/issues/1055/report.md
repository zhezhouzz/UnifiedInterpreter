### 性能优化具体描述
            
demo:
```py
for i in range(10):
  if i % 2 == 0:
    load
    use
```

will cause the load to be guarded by the same flag id even when multibuffer is enabled, causing unnecessary wait.
### 性能劣化说明
            

### 其他相关讨论
            

### 环境信息
            
```
例如：
- 操作系统
- 昇腾硬件信息
- CANN软件版本
- 安装的对应软件版本
```

