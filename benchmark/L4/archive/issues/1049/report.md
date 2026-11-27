### 环境信息
            
CANN 9.2.1
Daily 11.17 NPU-IR
### 🐛 问题描述
            
Distributed SHMEM custom ops can modify remote memory and shared UDMA queue state even when gm_addr_args_indices is empty. Skipping the guard allows both Vector subblocks to issue the same transfers, causing numerical corruption in mixed Cube/Vector GMM-alltoallv kernels.
