# 重构：扁平化 VendorLLMProvider 体系


# 重构：扁平化 VendorLLMProvider 体系

## 目标
删除 `RemoteModelVendorProvider` 中间层，让所有供应商统一继承 `VendorLLMProvider`，各自决定 `availableModels` 的获取策略。

## 文件清单

### 新增
- `Packages/KitLLM/Sources/KitLLM/Support/RemoteModelMerger.swift` — 静态合并函数
- `Packages/KitLLM/Sources/KitLLM/Support/RemoteModelMerger+Cache.swift` — 可选：封装缓存/状态管理

### 删除
- `Packages/KitLLM/Sources/KitLLM/Base/RemoteModelVendorProvider.swift`

### 修改
- `Packages/KitLLM/Sources/KitLLM/Base/VendorLLMProvider.swift` — 移除文档引用
- `Packages/KitLLM/Sources/KitLLM/Contracts/RemoteModelSource.swift` — 更新文档
- `Packages/KitLLM/Tests/KitLLMTests/RemoteModelListTests.swift` — 移除 `RemoteBaseTestProvider` 和相关测试
- `Packages/PluginLLMProviderCommandCode/Sources/.../GoatPlanProvider.swift` — 改为继承 `VendorLLMProvider`，自行实现远程逻辑

## 验收
- 所有 LLM 供应商均直接继承 `VendorLLMProvider`
- `RemoteModelVendorProvider` 符号不存在
- `GoatPlanProvider` 远程模型刷新/缓存/合并行为不变
- 测试通过
