### 性能优化具体描述
            
问题：
当一个标量由vf1产生，然后经过scalar计算，再给到vf2消费时，如果scalar计算与vf2距离比较远，会导致scalar一直等待vf1，从而引起后续的指令无法发射。
![image.png](https://raw.gitcode.com/user-images/assets/7494336/b8023858-84f6-4c5a-8b8f-cde0d32876fb/image.png 'image.png')

解决方案：
将scalar计算下沉到最近的消费者之前，使wait_flag推后执行
![image.png](https://raw.gitcode.com/user-images/assets/7494336/080a468c-63de-409c-89cd-182816c5a871/image.png 'image.png')
### 性能劣化说明
            
实测提升![image.png](https://raw.gitcode.com/user-images/assets/7494336/2e1ab9ff-aa76-4e2d-a5e1-4b72c6fa4989/image.png 'image.png')



### 其他相关讨论
            

### 环境信息
            
```
例如：
- 操作系统
- 昇腾硬件信息
- CANN软件版本
- 安装的对应软件版本
```

