# TestPlan — PluginLLMContext

## 包概述

PluginLLMContext 的实现包，包含 12 个主要类型；当前测试覆盖 39 条用例。

平台: macOS 14+, iOS 17+
测试文件: 5 个，用例总数: 39

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
- **LLMContextPlugin**（19 条）：由 `timelineMessagesAreExcludedFromLLMHistory`、`shortConversationUsesFullHistory`、`contextWindowUsageMatchesPreparedRequest` 等用例锁定；改动该模块时优先跑对应测试文件。
- **不可发送角色的预算隔离**（2 条）：由 `nonSendableRolesAreExcludedFromLLMHistory`、`fallbackKeepsUserRequestWhenErrorExceedsBudget` 锁定；`.error` / `.status` 必须在估算、摘要和 fallback 之前排除，否则尾部错误会挤掉真实用户请求（**回归 #1025**）。
- **ContextTokenFormatting**（3 条）：由 `smallSizesKeepActualTokens`、`largeSizesUseShortUnits`、`zeroHasNoUnit` 锁定；小于 1000 的用量必须显示真实 token 数，不能因整数除法塌缩成 `0K`（**回归 #936**）。
- **确定性降级的量纲与用户请求保留**（2 条）：由 `oversizedChineseUserMessageIsTruncatedInsteadOfDropped`、`largeSystemMessageDoesNotEvictUserRequest` 锁定；裁剪必须按 token 估算，且系统消息占满预算时仍要保留最新用户消息（**回归 #1022**）。
- **StalePrewarmSummaryRetry**（1 条）：由 `hardThresholdRetriesAfterDiscardedPrewarm` 锁定。硬阈值等待的预热摘要若因请求期间产生新消息而被丢弃，必须按最新历史重新生成一次再决定是否降级，不能把过期预热当作本轮压缩已完成（**回归 #1118**）。

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
| 28 | LLMContextPlugin | 压缩结果落在目标水位内，不会把预算填满 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `compactionResultStaysUnderTargetWatermark` |
| 29 | LLMContextPlugin | 摘要仍然覆盖得住最近区间时不会重新生成 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `validSnapshotIsReusedWithoutNewSummary` |
| 30 | LLMContextPlugin | 压缩上下文会裁剪超大的旧工具输出 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `oversizedToolOutputIsTruncatedInCompactedContext` |
| 31 | LLMContextPlugin | 保留窗口本身就超预算时仍然产出不超过预算的上下文 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `irreducibleProtectedWindowStillProducesValidContext` |
| 32 | LLMContextPlugin | 不可发送的错误与状态消息不进入 LLM 历史（**回归 #1025**） | 历史含 user、error 与 status 消息 | 调用 `messagesForLLM` | 只返回 user 消息 | P1 | ✅ 已覆盖 | `nonSendableRolesAreExcludedFromLLMHistory` |
| 33 | LLMContextPlugin | 降级裁剪不会让尾部错误消息挤掉真实用户请求（**回归 #1025**） | 输入上限约 1,096 token，历史为 user("hi") + 5,000 字符 error | 调用 `prepareContext` | 返回 user("hi")，错误不参与预算 | P1 | ✅ 已覆盖 | `fallbackKeepsUserRequestWhenErrorExceedsBudget` |
| 34 | LLMContextPlugin | 超长中文用户消息按 token 裁剪后保留，而不是整条丢弃（**回归 #1022**） | 输入上限约 1,096 token，最新用户消息为 2,000 个汉字 | 调用 `prepareContext` | 保留一条带截断标记的用户消息，估算不超过上限 | P0 | ✅ 已覆盖 | `oversizedChineseUserMessageIsTruncatedInsteadOfDropped` |
| 35 | LLMContextPlugin | 系统消息占满预算时仍保留本轮用户请求（**回归 #1022**） | 1,050 字中文 system + 30 字中文 user | 调用 `prepareContext` | 结果包含非空用户消息，估算不超过上限 | P0 | ✅ 已覆盖 | `largeSystemMessageDoesNotEvictUserRequest` |
| 36 | ContextTokenFormatting | 小于 1000 的用量显示真实 token 数而不是 0K（**回归 #936**） | token 数为 1 / 500 / 999 | 调用 `formattedContextSize` | 分别显示 "1" / "500" / "999" | P1 | ✅ 已覆盖 | `smallSizesKeepActualTokens` |
| 37 | ContextTokenFormatting | 千级与百万级仍使用 K/M 简写 | token 数为 1000 / 128000 / 1000000 / 1500000 | 调用 `formattedContextSize` | 分别显示 1K / 128K / 1M / 1.5M | P1 | ✅ 已覆盖 | `largeSizesUseShortUnits` |
| 38 | ContextTokenFormatting | 零值不再显示为 0K | token 数为 0 | 调用 `formattedContextSize` | 显示 "0" | P2 | ✅ 已覆盖 | `zeroHasNoUnit` |
| 39 | StalePrewarmSummaryRetry | 等待过期预热摘要后按最新历史重试（**回归 #1118**） | 无可用摘要且已达硬阈值；预热摘要请求被挂起 | 请求挂起期间插入下一回合消息，硬阈值 `prepareContext` 等待该预热后放行 | 预热因水位过旧被丢弃后重新生成一次摘要，返回压缩上下文且不降级；摘要请求共 2 次 | P0 | ✅ 已覆盖 | `hardThresholdRetriesAfterDiscardedPrewarm` |

> 说明：全部 **39 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 3 / 3
- P1: 已覆盖 33 / 33
- P2: 已覆盖 3 / 3
- **合计: 39 / 39**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（3 条）
- **P1**: 其余功能性用例（33 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（3 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 39 条用例位于 `Tests/`，需在目标平台执行 `swift test`

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
