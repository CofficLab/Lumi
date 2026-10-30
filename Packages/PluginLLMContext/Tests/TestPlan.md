# TestPlan — PluginLLMContext

## 包概述

PluginLLMContext 的实现包，包含 12 个主要类型；当前测试覆盖 27 条用例。

平台: macOS 14+, iOS 17+
测试文件: 3 个，用例总数: 27

核心组件（源码目录）:
- `Hooks/`
- `Providers/`

## 公开 API

包内主要类型（按声明顺序抽取，供定位被测对象）:

- `ContextPopover`
- `ContextSummaryModel`
- `ContextSummaryRecord`
- `ContextToolbarState`
- `ContextToolbarView`
- `ContextUsageSample`
- `ContextUsageRing`
- `ContextUsageTrendMarkers`
- `ContextUsageTrendView`
- `LLMContextPlugin`
- `LLMContextTurnFinishedHook`
- `ContextWindowUsageSnapshot`

## 关键行为契约（实现约定，非协议要求）

按测试模块归纳，改动对应模块时须保持既有断言成立:

- **ContextPopoverLayout**（5 条）：由 `trendMarkersHeightIsConstrained`、`trendMarkersRendersInTightSpace`、`popoverHeightIsConstrainedWithManyEvents` 等用例锁定；改动该模块时优先跑对应测试文件。
- **ContextUsageHistory**（9 条）：由 `emptyHistory`、`samplesUseReportedInputTokens`、`assistantOutputExcludedFromInput` 等用例锁定；改动该模块时优先跑对应测试文件。
- **LLMContextPlugin**（13 条）：由 `timelineMessagesAreExcludedFromLLMHistory`、`shortConversationUsesFullHistory`、`contextWindowUsageMatchesPreparedRequest` 等用例锁定；改动该模块时优先跑对应测试文件。

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | ContextPopoverLayout | ContextUsageTrendMarkers 在宽松空间下不应超过图表高度 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `trendMarkersHeightIsConstrained` |
| 2 | ContextPopoverLayout | ContextUsageTrendMarkers 在极小空间下仍能渲染 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `trendMarkersRendersInTightSpace` |
| 3 | ContextPopoverLayout | ContextPopover 在内容很多时不应超出最大高度 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `popoverHeightIsConstrainedWithManyEvents` |
| 4 | ContextPopoverLayout | ContextPopover 在内容很少时不超过最大高度 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `popoverHeightRespectsMaxHeightWithMinimalContent` |
| 5 | ContextPopoverLayout | ContextPopover 无压缩事件时只显示窗口信息和趋势 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `popoverWithoutCompactionEvents` |
| 6 | ContextUsageHistory | 没有请求时历史为空 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `emptyHistory` |
| 7 | ContextUsageHistory | 采样点取服务端上报的 inputTokenCount | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `samplesUseReportedInputTokens` |
| 8 | ContextUsageHistory | assistant 自身的输出不计入下一轮输入 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `assistantOutputExcludedFromInput` |
| 9 | ContextUsageHistory | 供应商未上报 usage 时用本地累计估算 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `fallsBackToLocalEstimate` |
| 10 | ContextUsageHistory | 无累计内容时不产生估算采样，避免零值点 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `noSampleWhenNothingAccumulated` |
| 11 | ContextUsageHistory | 真实的压缩事件只作为标记，不计入采样 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `actualCompactionBecomesMarker` |
| 12 | ContextUsageHistory | 后台预热事件不显示为压缩标记 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `prewarmEventIsNotAMarker` |
| 13 | ContextUsageHistory | 错误与状态消息不计入累计 token | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `nonLLMRolesExcluded` |
| 14 | ContextUsageHistory | 采样点按时间排序，与消息插入顺序无关 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `samplesAreChronologicallyOrdered` |
| 15 | LLMContextPlugin | 时间线消息只展示给用户，不进入 LLM 历史 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `timelineMessagesAreExcludedFromLLMHistory` |
| 16 | LLMContextPlugin | 短会话透传完整历史 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `shortConversationUsesFullHistory` |
| 17 | LLMContextPlugin | 工具栏统计复用 LLMContext 请求的估算和预算 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `contextWindowUsageMatchesPreparedRequest` |
| 18 | LLMContextPlugin | 摘要生成失败时不阻塞，继续返回完整历史 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `summaryFailureFallsBackToFullHistory` |
| 19 | LLMContextPlugin | 生成摘要时使用防提示注入的摘要指令 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `summaryPromptTreatsConversationAsData` |
| 20 | LLMContextPlugin | 后台生成摘要后返回摘要和最近消息 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `backgroundSummaryCompactsHistory` |
| 21 | LLMContextPlugin | 后台摘要沿用对话模型 ID，不会误路由到同名全局模型 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `backgroundSummaryUsesConversationModelID` |
| 22 | LLMContextPlugin | 硬阈值请求会在发送前等待摘要 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `hardBudgetWaitsForCompaction` |
| 23 | LLMContextPlugin | 软阈值只预热，不记录实际压缩 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `softThresholdOnlyPrewarms` |
| 24 | LLMContextPlugin | 工具 schema usage 不会放大后续消息上下文估算 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `toolSchemaUsageDoesNotInflateMessageCalibration` |
| 25 | LLMContextPlugin | 成功请求会逐步修正过高的历史校准倍率 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `successfulUsageReducesInflatedCalibration` |
| 26 | LLMContextPlugin | 超过原先消息上限后仍能滚动生成摘要 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `rollingSummaryContinuesPastLegacyMessageLimit` |
| 27 | LLMContextPlugin | 重新创建 Provider 后复用磁盘摘要 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `persistedSummarySurvivesProviderRecreation` |

> 说明：全部 **27 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 0 / 0
- P1: 已覆盖 25 / 25
- P2: 已覆盖 2 / 2
- **合计: 27 / 27**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（0 条）
- **P1**: 其余功能性用例（25 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（2 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 27 条用例位于 `Tests/`，需在目标平台执行 `swift test`

## 测试执行

```bash
cd Packages/PluginLLMContext
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例，再写实现
2. **Bug 修复** → 追加回归用例，标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan，标记 ✅ 并填写测试方法名
5. **改名同步** → 重命名 `@Test` 函数后必须同步本表，否则 `Scripts/verify-testplan.py` 会报「登记方法在源码不存在」
