# TestPlan — PluginLLMManager

## 包概述

PluginLLMManager 的实现包，包含 11 个主要类型；当前测试覆盖 18 条用例。

平台: macOS 14+, iOS 17+
测试文件: 3 个，用例总数: 18

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

> 说明：全部 **18 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 3 / 3
- P1: 已覆盖 14 / 14
- P2: 已覆盖 1 / 1
- **合计: 18 / 18**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（3 条）
- **P1**: 其余功能性用例（14 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（1 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 18 条用例位于 `Tests/`，需在目标平台执行 `swift test`

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
