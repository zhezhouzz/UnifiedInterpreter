[NDDMA] NddmaDesc硬编码上限需代际隔离

## 现状
硬编码了 NDDMA 描述符部分字段上限：
static constexpr int64_t kSizeBits = 20;
static constexpr int64_t kSrcStrideBits = 40;
static constexpr int64_t kDstStrideBits = 40;

## 隐患
字段宽度（20 / 40 / 40位）来自 cce侧的`nddma_desc`，新增 A7/A8 代际时若格式变化需要人工同步