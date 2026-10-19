# TestPlan — ProviderLLMContext

## 包概述

ProviderLLMContext 的实现包，包含 1 个主要类型；当前测试覆盖 31 条用例。

平台: macOS 14+, iOS 17+
测试文件: 1 个，用例总数: 31

## 公开 API

包内主要类型（按声明顺序抽取，供定位被测对象）:

- `LLMContextPreparationMode`

## 关键行为契约（实现约定，非协议要求）

按测试模块归纳，改动对应模块时须保持既有断言成立:

- **LLMContextProviding**（31 条）：由 `contextBudgetReservesSpace`、`unknownContextWindowUsesFallback`、`tokenEstimatorIncludesMessageParts` 等用例锁定；改动该模块时优先跑对应测试文件。

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | LLMContextProviding | 上下文预算为输出、工具和安全余量预留空间 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `contextBudgetReservesSpace` |
| 2 | LLMContextProviding | 未知窗口使用保守 fallback | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `unknownContextWindowUsesFallback` |
| 3 | LLMContextProviding | token 估算包含消息正文、reasoning 和工具参数 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `tokenEstimatorIncludesMessageParts` |
| 4 | LLMContextProviding | 透传 Provider 保留消息顺序和内容 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `passthroughPreservesMessages` |
| 5 | LLMContextProviding | 透传 Provider 不返回其他会话的消息 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `passthroughScopesConversation` |
| 6 | LLMContextProviding | 预算将负值输出、工具和安全余量钳为零 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `budgetClampsNegativeReservations` |
| 7 | LLMContextProviding | effective window 低于 4096 时抬到下限 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `effectiveWindowFloor` |
| 8 | LLMContextProviding | fallback window 低于 4096 时抬到下限 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `fallbackWindowFloor` |
| 9 | LLMContextProviding | inputTokenLimit 不会低于 1024 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `inputTokenLimitFloor` |
| 10 | LLMContextProviding | usesFallbackWindow 仅在未提供窗口时为真 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `usesFallbackWindowFlag` |
| 11 | LLMContextProviding | 保守预算按窗口比例计算输出预留和安全余量 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `conservativeBudgetScalesWithWindow` |
| 12 | LLMContextProviding | 保守预算对小窗口使用输出预留和安全余量下限 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `conservativeBudgetFloorsForSmallWindow` |
| 13 | LLMContextProviding | 保守预算将 toolSchemaTokens 计入输入限额 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `conservativeBudgetCountsToolSchema` |
| 14 | LLMContextProviding | 准备模式暴露三个 release track 及其 rawValue | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `preparationModeCases` |
| 15 | LLMContextProviding | 估算来源暴露三种来源及其 rawValue | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `estimateSourceCases` |
| 16 | LLMContextProviding | 请求优先使用 modelID 解析 provider 和 model | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `requestPrefersModelID` |
| 17 | LLMContextProviding | 请求在未提供 modelID 时从字符串回退构建 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `requestFallsBackToProviderStrings` |
| 18 | LLMContextProviding | 请求在 providerID 或 model 为空时不构造 modelID | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `requestWithEmptyStringsHasNoModelID` |
| 19 | LLMContextProviding | 请求默认模式为 beforeSend | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `requestDefaultMode` |
| 20 | LLMContextProviding | 请求相等性比较关键字段 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `requestEquatable` |
| 21 | LLMContextProviding | 结果默认值为 estimated、未压缩、未降级 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `resultDefaults` |
| 22 | LLMContextProviding | 结果相等性比较所有字段 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `resultEquatable` |
| 23 | LLMContextProviding | 空文本至少估算为 1 个 token | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `estimateEmptyTextIsOne` |
| 24 | LLMContextProviding | 文本估算基于 UTF-8 字节数 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `estimateTextUsesUTF8Bytes` |
| 25 | LLMContextProviding | 空消息列表估算为零 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `estimateEmptyMessagesIsZero` |
| 26 | LLMContextProviding | 纯文本消息估算为内容加固定开销 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `estimateBareMessage` |
| 27 | LLMContextProviding | reasoning 内容并入估算 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `estimateIncludesReasoning` |
| 28 | LLMContextProviding | 默认 prepareContext 返回消息、估算 token 并使用预算限额 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `defaultPrepareContextBuildsResult` |
| 29 | LLMContextProviding | 默认 prepareContext 在窗口未知时标记为 fallback 来源 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `defaultPrepareContextMarksFallbackSource` |
| 30 | LLMContextProviding | 空会话的 prepareContext 返回空消息和零估算 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `prepareContextWithEmptyConversation` |
| 31 | LLMContextProviding | 透传 Provider 对空会话返回空消息 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `passthroughEmptyConversation` |

> 说明：全部 **31 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 4 / 4
- P1: 已覆盖 18 / 18
- P2: 已覆盖 9 / 9
- **合计: 31 / 31**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（4 条）
- **P1**: 其余功能性用例（18 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（9 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 31 条用例位于 `Tests/`，需在目标平台执行 `swift test`

## 测试执行

```bash
cd Packages/ProviderLLMContext
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例，再写实现
2. **Bug 修复** → 追加回归用例，标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan，标记 ✅ 并填写测试方法名
5. **改名同步** → 重命名 `@Test` 函数后必须同步本表，否则 `Scripts/verify-testplan.py` 会报「登记方法在源码不存在」
