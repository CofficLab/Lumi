# TestPlan — PluginConversationSpeed

## 包概述

PluginConversationSpeed 的实现包，包含 8 个主要类型；当前测试覆盖 21 条用例。

平台: macOS 14+, iOS 17+
测试文件: 3 个，用例总数: 21

核心组件（源码目录）:
- `Observers/`
- `Support/`
- `ViewModels/`

## 公开 API

包内主要类型（按声明顺序抽取，供定位被测对象）:

- `ConversationSpeedPlugin`
- `SpeedLineChart`
- `SpeedSample`
- `SpeedPopover`
- `SpeedToolbarView`
- `SpeedConversationObserver`
- `SpeedMessageObserver`
- `ConversationSpeedViewModel`

## 关键行为契约（实现约定，非协议要求）

按测试模块归纳，改动对应模块时须保持既有断言成立:

- **综合**（8 条）：由 `speedPluginInstantiates`、`speedViewModelUpdatesFromMessageSnapshot`、`speedViewModelClearsWhenConversationIsDeselected`、`speedViewModelReadsLegacyMetadataTiming` 等用例锁定；改动该模块时优先跑对应测试文件。
- **SpeedModels**（9 条）：由 `speedDurationUsesTheLongerAvailableRequestDuration`、`speedDurationFallsBackToEitherPositiveMeasurement`、`legacyMetadataTimingRestoresHistoricalSpeedAndTTFT` 等用例锁定——强类型计时缺失时必须回退到旧版 metadata（**#1029**）。
- **SpeedObserver**（4 条）：由 `conversationObserverLoadsAndTracksTheSelectedConversation`、`conversationObserverCancelStopsFurtherSelectionUpdates`、`conversationObserverBindsNewSelectionBeforeSnapshotArrives` 等用例锁定；改动该模块时优先跑对应测试文件。

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | 综合 | speedPluginInstantiates | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `speedPluginInstantiates` |
| 2 | 综合 | speedViewModelUpdatesFromMessageSnapshot | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `speedViewModelUpdatesFromMessageSnapshot` |
| 3 | 综合 | speedViewModelClearsWhenConversationIsDeselected | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `speedViewModelClearsWhenConversationIsDeselected` |
| 4 | 综合 | speedViewModelIgnoresRefreshForAnotherConversation | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `speedViewModelIgnoresRefreshForAnotherConversation` |
| 5 | 综合 | speedViewModelClearsPreviousConversationDetailsWhenSelectionChanges | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `speedViewModelClearsPreviousConversationDetailsWhenSelectionChanges` |
| 6 | 综合 | speedViewModelUsesAssistantMetricsInsteadOfUserMessageMetadata | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `speedViewModelUsesAssistantMetricsInsteadOfUserMessageMetadata` |
| 7 | SpeedModels | speedDurationUsesTheLongerAvailableRequestDuration | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `speedDurationUsesTheLongerAvailableRequestDuration` |
| 8 | SpeedModels | speedDurationFallsBackToEitherPositiveMeasurement | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `speedDurationFallsBackToEitherPositiveMeasurement` |
| 9 | SpeedModels | speedRequiresOutputTokensAndPositiveDuration | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `speedRequiresOutputTokensAndPositiveDuration` |
| 10 | SpeedModels | speedSamplesSortChronologicallyAndExcludeMessagesWithoutSpeedData | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `speedSamplesSortChronologicallyAndExcludeMessagesWithoutSpeedData` |
| 11 | SpeedModels | averageSpeedIsNilForNoSamplesAndArithmeticMeanOtherwise | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `averageSpeedIsNilForNoSamplesAndArithmeticMeanOtherwise` |
| 12 | SpeedModels | unavailabilityReasonDistinguishesMissingMetrics | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `unavailabilityReasonDistinguishesMissingMetrics` |
| 13 | SpeedModels | everyUnavailabilityReasonHasLocalizedExplanation | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `everyUnavailabilityReasonHasLocalizedExplanation` |
| 14 | SpeedObserver | conversationObserverLoadsAndTracksTheSelectedConversation | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `conversationObserverLoadsAndTracksTheSelectedConversation` |
| 15 | SpeedObserver | conversationObserverCancelStopsFurtherSelectionUpdates | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `conversationObserverCancelStopsFurtherSelectionUpdates` |
| 16 | SpeedObserver | messageObserverDebouncesSelectedConversationAndIgnoresOtherConversations | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `messageObserverDebouncesSelectedConversationAndIgnoresOtherConversations` |
| 17 | SpeedObserver | 切换选中会话时立即绑定新会话并清空旧指标，不等异步快照返回 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `conversationObserverBindsNewSelectionBeforeSnapshotArrives` |
| 18 | 综合 | 最新响应缺少速度指标时 Current speed 不可用且详情来自最新响应 | 会话内有 A（有指标）与 B（无 outputTokenCount）两条 assistant | 选中会话后读取 ViewModel | cachedTPS 为 nil、原因为 missingOutputTokens、model/provider 来自 B、历史保留 A | P0 | ✅ 已覆盖 | `speedViewModelShowsLatestResponseWhenItLacksMetrics` |
| 19 | 综合 | 旧消息仅 metadata 有计时时 ViewModel 仍展示 TPS/TTFT（**#1029**） | assistant 消息无强类型计时，metadata 含 latency/streaming/TTFT | 选中会话后读取 ViewModel | TPS 20、历史 1 条、TTFT 2000、状态为可用 | P0 | ✅ 已覆盖 | `speedViewModelReadsLegacyMetadataTiming` |
| 20 | SpeedModels | 强类型计时缺失时从 metadata 恢复历史速度与 TTFT（**#1029**） | 同上，outputTokenCount = 120 | 读取 `speedDurationMs` / `speedTokensPerSecond` / `speedTimeToFirstTokenMs` | 6000 ms、20 tokens/s、2000 ms | P0 | ✅ 已覆盖 | `legacyMetadataTimingRestoresHistoricalSpeedAndTTFT` |
| 21 | SpeedModels | 强类型计时优先于 metadata | 强类型与 metadata 同时存在 | 读取时长与 TTFT | 取强类型值 | P1 | ✅ 已覆盖 | `typedTimingTakesPrecedenceOverLegacyMetadata` |

> 说明：全部 **21 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 4 / 4
- P1: 已覆盖 17 / 17
- P2: 已覆盖 0 / 0
- **合计: 21 / 21**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（4 条）
- **P1**: 其余功能性用例（17 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（0 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 21 条用例位于 `Tests/`，需在目标平台执行 `swift test`

## 测试执行

```bash
cd Packages/PluginConversationSpeed
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例，再写实现
2. **Bug 修复** → 追加回归用例，标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan，标记 ✅ 并填写测试方法名
5. **改名同步** → 重命名 `@Test` 函数后必须同步本表，否则 `Scripts/verify-testplan.py` 会报「登记方法在源码不存在」
