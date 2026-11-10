# TestPlan — PluginLLMManager

## 包概述

PluginLLMManager 的实现包，包含 11 个主要类型；当前测试覆盖 23 条用例。

平台: macOS 14+, iOS 17+
测试文件: 4 个，用例总数: 23

核心组件（源码目录）:
- `Capabilities/`
- `Managers/`
- `Messages/`
- `Observers/`
- `Renderers/`
- `Support/`
- `ViewModels/`
- `Views/`

## 公开 API

包内主要类型（按声明顺序抽取，供定位被测对象）:

- `PluginLLMManager`
- `LLMManagerCapability`
- `CustomLLMManager`
- `LLMProviderAPIKeyMessage`
- `ConversationProviderObserver`
- `SelectedConversationObserver`
- `APIKeyAccessFailedRenderer`
- `APIKeyMissingRenderer`
- `ProviderAPIKeyViewModel`
- `ProviderAPIKeyAccessFailedView`
- `ProviderAPIKeyMissingView`

## 关键行为契约（实现约定，非协议要求）

按测试模块归纳，改动对应模块时须保持既有断言成立:

- **综合**（15 条）：由 `onBootReplacesDefaultManager`、`onBootRegistersAPIKeyRenderers`、`legacyMissingAPIKeyMessageMatchesRenderer` 等用例锁定；改动该模块时优先跑对应测试文件。
- **ProviderAPIKeySaveVerification**（3 条）：由 `writeFailureKeepsInputAndReportsError`、`silentWriteLossIsNotReportedAsSaved`、`readBackMatchConfirmsSave` 锁定。API Key 卡片必须调用 throwing 写入并在读回值等于提交值后才显示 Saved；写入失败或读回不一致时保留用户输入并展示错误（**回归 #1119**）。
- **ProviderAPIKeyLegacyProviderResolution**（5 条）：由 `legacyRawErrorDetailBindsOwningProvider`、`legacyContentBindsOwningProvider`、`unknownLegacyProviderDisablesInlineSave`、`identitylessLegacyMessageDisablesInlineSave`、`ambiguousDisplayNameDisablesInlineSave` 锁定。没有 `providerID` 的旧错误消息只能按文本中的供应商名唯一反查；无法唯一确定时必须禁用内联写入，禁止回退到当前全局选中项（**回归 #1120**）。

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | 综合 | onBoot 替换默认 LLMManaging 为 CustomLLMManager | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `onBootReplacesDefaultManager` |
| 2 | 综合 | onBoot 注册 API Key 消息渲染器 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `onBootRegistersAPIKeyRenderers` |
| 3 | 综合 | 旧版 missingAPIKey 文本消息也能命中 API Key 渲染器 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `legacyMissingAPIKeyMessageMatchesRenderer` |
| 4 | 综合 | CustomLLMManager 转发注册与路由 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `customManagerRoutesToRegisteredProvider` |
| 5 | 综合 | CustomLLMManager 广播 modelsRefreshed 事件 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `customManagerBroadcastsModelsRefreshed` |
| 6 | 综合 | CustomLLMManager 按全局模型 ID 解析重复模型名 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `customManagerRoutesByGlobalModelID` |
| 7 | 综合 | 请求显式供应商时不会被 CustomLLMManager 的全局选择覆盖 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `customManagerRoutesToExplicitProvider` |
| 8 | 综合 | routingOverride 优先路由 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `routingOverrideTakesPrecedence` |
| 9 | 综合 | 切换对话不会改写全局供应商/模型选择 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `switchingConversationDoesNotMutateGlobalSelection` |
| 10 | 综合 | 切换当前对话的模型不会同步到全局 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `selectedConversationModelDoesNotSyncGlobalSelection` |
| 11 | 综合 | 对话过期模型 ID 不会改写全局选择 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `staleConversationModelDoesNotSyncGlobalSelection` |
| 12 | 综合 | 非当前对话的变更不影响全局 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `nonSelectedConversationChangeDoesNotSyncGlobalSelection` |
| 13 | 综合 | models(for:) 读取动态模型池，含远程新增模型 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `modelsReadsDynamicPool` |
| 14 | 综合 | 远程新增模型可解析 modelID 并路由 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `remoteModelSelectableAndRoutable` |
| 15 | 综合 | 请求自带远程新增模型时不被回退到默认模型 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `requestedRemoteModelIsNotDowngraded` |
| 16 | ProviderAPIKeySaveVerification | Keychain 写入失败时不显示 Saved 并保留输入（**回归 #1119**） | 供应商模拟 `setApiKeyReportingErrors` 抛 `writeFailed` | 输入 `sk-new` 后调用 `saveAPIKey` | `didSaveAPIKey == false`，`saveError` 为真实错误，输入仍为 `sk-new`，没有写入任何 Key | P0 | ✅ 已覆盖 | `writeFailureKeepsInputAndReportsError` |
| 17 | ProviderAPIKeySaveVerification | 静默写失败不会被当作保存成功（**回归 #1119**） | 已有旧 Key `sk-old`，写入实现不落盘也不抛错 | 输入 `sk-new` 后调用 `saveAPIKey` | 读回仍是 `sk-old`，`didSaveAPIKey == false` 且有错误，输入保留 `sk-new` | P0 | ✅ 已覆盖 | `silentWriteLossIsNotReportedAsSaved` |
| 18 | ProviderAPIKeySaveVerification | 读回值与提交值一致才显示 Saved | 供应商正常持久化，输入前后带空格 | 输入 `  sk-new  ` 后调用 `saveAPIKey` | 存储值为 `sk-new`，`didSaveAPIKey == true`，无错误，`keyIsReadable == true` | P1 | ✅ 已覆盖 | `readBackMatchConfirmsSave` |
| 19 | ProviderAPIKeyLegacyProviderResolution | 旧消息按 rawErrorDetail 中的供应商名绑定（**回归 #1120**） | 消息无 `providerID`，`rawErrorDetail` 为 `Missing API key for: Provider A`，当前选中 Provider B | 输入 Key 后调用 `saveAPIKey` | 卡片绑定 Provider A；Key 写入 A，B 的 Key 不被覆盖 | P0 | ✅ 已覆盖 | `legacyRawErrorDetailBindsOwningProvider` |
| 20 | ProviderAPIKeyLegacyProviderResolution | 旧版 missingAPIKey 文本同样按供应商名绑定（**回归 #1120**） | 消息无 `providerID`，内容为 `missingAPIKey("Provider A")`，当前选中 Provider B | 输入 Key 后调用 `saveAPIKey` | 卡片绑定 Provider A；Key 写入 A，B 的 Key 不被覆盖 | P0 | ✅ 已覆盖 | `legacyContentBindsOwningProvider` |
| 21 | ProviderAPIKeyLegacyProviderResolution | 旧消息记录的供应商未注册时禁用内联写入（**回归 #1120**） | 消息指向未注册的 Provider C，当前选中 Provider B | 初始化卡片并尝试保存 | `providerAvailable == false`、需手动选择；A/B 的 Key 均不变 | P0 | ✅ 已覆盖 | `unknownLegacyProviderDisablesInlineSave` |
| 22 | ProviderAPIKeyLegacyProviderResolution | 旧消息无法解析供应商身份时不回退到当前选中项（**回归 #1120**） | 消息既无 `providerID` 也无供应商名，当前选中 Provider B | 初始化卡片并尝试保存 | 卡片禁用内联写入，不读取也不写入 B 的 Key | P0 | ✅ 已覆盖 | `identitylessLegacyMessageDisablesInlineSave` |
| 23 | ProviderAPIKeyLegacyProviderResolution | 展示名重复时无法唯一归属，禁用内联写入（**回归 #1120**） | 两个已注册供应商展示名相同，消息只记录该名称 | 初始化卡片并尝试保存 | 不任意选择其一；A/B 的 Key 均不变 | P1 | ✅ 已覆盖 | `ambiguousDisplayNameDisablesInlineSave` |
> 说明：全部 **23 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 7 / 7
- P1: 已覆盖 15 / 15
- P2: 已覆盖 1 / 1
- **合计: 23 / 23**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（7 条）
- **P1**: 其余功能性用例（15 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（1 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 23 条用例位于 `Tests/`，需在目标平台执行 `swift test`

## 测试执行

```bash
cd Packages/PluginLLMManager
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例，再写实现
2. **Bug 修复** → 追加回归用例，标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan，标记 ✅ 并填写测试方法名
5. **改名同步** → 重命名 `@Test` 函数后必须同步本表，否则 `Scripts/verify-testplan.py` 会报「登记方法在源码不存在」
