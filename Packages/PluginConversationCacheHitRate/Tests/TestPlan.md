# TestPlan — PluginConversationCacheHitRate

## 包概述

PluginConversationCacheHitRate Lumi 编辑器插件。

平台: macOS 14+, iOS 17+
测试文件: 2 个，用例总数: 27

核心组件（源码目录）:
- `Models/`
- `Observers/`
- `Support/`

## 公开 API

包内主要类型（按声明顺序抽取，供定位被测对象）:

- `CacheHitRateLineChart`
- `CacheHitRatePopover`
- `CacheHitRateToolbarView`
- `CacheHitRateTrendView`
- `ConversationCacheHitRatePlugin`
- `CacheHitRateRequestMetrics`
- `CacheHitRateObserver`

## 关键行为契约（实现约定，非协议要求）

按测试模块归纳，改动对应模块时须保持既有断言成立:

- **CacheHitRateHistory**（11 条）：由 `historyBuildsOneSamplePerUsableAssistantMessage`、`historyAssignsSequentialIndexesInChronologicalOrder`、`historyCumulativeHitRateIsTokenWeighted` 等用例锁定；改动该模块时优先跑对应测试文件。
- **综合**（16 条）：由 `cacheHitRatePluginInstantiates`、`cacheHitRateToolbarStateForwardsTypedEvents`、`cacheHitRateStatsUseTypedTokenFields` 等用例锁定；改动该模块时优先跑对应测试文件。

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | CacheHitRateHistory | historyBuildsOneSamplePerUsableAssistantMessage | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `historyBuildsOneSamplePerUsableAssistantMessage` |
| 2 | CacheHitRateHistory | historyAssignsSequentialIndexesInChronologicalOrder | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `historyAssignsSequentialIndexesInChronologicalOrder` |
| 3 | CacheHitRateHistory | historyCumulativeHitRateIsTokenWeighted | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `historyCumulativeHitRateIsTokenWeighted` |
| 4 | CacheHitRateHistory | historyClampsCachedTokensToTotal | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `historyClampsCachedTokensToTotal` |
| 5 | CacheHitRateHistory | historyFallsBackToInputTokenCountWhenTotalIsMissing | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `historyFallsBackToInputTokenCountWhenTotalIsMissing` |
| 6 | CacheHitRateHistory | historyReadsLegacyMetadataKeys | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `historyReadsLegacyMetadataKeys` |
| 7 | CacheHitRateHistory | historySkipsNonAssistantAndInvalidSamples | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `historySkipsNonAssistantAndInvalidSamples` |
| 8 | CacheHitRateHistory | historyStatisticsMatchSamples | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `historyStatisticsMatchSamples` |
| 9 | CacheHitRateHistory | emptyHistoryHasNoStatistics | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `emptyHistoryHasNoStatistics` |
| 10 | CacheHitRateHistory | historyAndStatsAgreeOnParsing | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `historyAndStatsAgreeOnParsing` |
| 11 | CacheHitRateHistory | percentTextKeepsOneDecimalForSmallNonZeroRates | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `percentTextKeepsOneDecimalForSmallNonZeroRates` |
| 12 | 综合 | cacheHitRatePluginInstantiates | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `cacheHitRatePluginInstantiates` |
| 13 | 综合 | cacheHitRateToolbarStateForwardsTypedEvents | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `cacheHitRateToolbarStateForwardsTypedEvents` |
| 14 | 综合 | cacheHitRateStatsUseTypedTokenFields | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `cacheHitRateStatsUseTypedTokenFields` |
| 15 | 综合 | cacheHitRateStatsKeepLegacyMetadataCompatibility | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `cacheHitRateStatsKeepLegacyMetadataCompatibility` |
| 16 | 综合 | cacheHitRateStatsIgnoreUnsupportedRequests | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `cacheHitRateStatsIgnoreUnsupportedRequests` |
| 17 | 综合 | cacheHitRateUsesTokenWeightedRateAsPrimaryValue | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `cacheHitRateUsesTokenWeightedRateAsPrimaryValue` |
| 18 | 综合 | cacheHitRateExplainsMissingUsageWithDistinctNonEmptyText | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `cacheHitRateExplainsMissingUsageWithDistinctNonEmptyText` |
| 19 | 综合 | cacheHitRateLocalizationCatalogDefinesAllReasons | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `cacheHitRateLocalizationCatalogDefinesAllReasons` |
| 20 | 综合 | cacheHitRatePrecisePercentTextRendersOneDecimal | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `cacheHitRatePrecisePercentTextRendersOneDecimal` |
| 21 | 综合 | cacheHitRateEmptyStatsHaveZeroWeightedRate | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `cacheHitRateEmptyStatsHaveZeroWeightedRate` |
| 22 | 综合 | toolbarStateDoesNotNotifyWhenSelectedConversationIsUnchanged | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `toolbarStateDoesNotNotifyWhenSelectedConversationIsUnchanged` |
| 23 | 综合 | cacheHitRateBoundsCachedTokensToTotalTokens | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `cacheHitRateBoundsCachedTokensToTotalTokens` |
| 24 | 综合 | cacheHitRateIgnoresNonAssistantMessages | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `cacheHitRateIgnoresNonAssistantMessages` |
| 25 | 综合 | cacheHitRateSkipsRequestsWithNonPositiveTotal | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `cacheHitRateSkipsRequestsWithNonPositiveTotal` |
| 26 | 综合 | cacheHitRateSkipsRequestsWithNegativeCachedTokens | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `cacheHitRateSkipsRequestsWithNegativeCachedTokens` |
| 27 | 综合 | cacheHitRateFallsBackToInputTokenCountWhenTotalIsMissing | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `cacheHitRateFallsBackToInputTokenCountWhenTotalIsMissing` |

> 说明：全部 **27 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 1 / 1
- P1: 已覆盖 23 / 23
- P2: 已覆盖 3 / 3
- **合计: 27 / 27**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（1 条）
- **P1**: 其余功能性用例（23 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（3 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 27 条用例位于 `Tests/`，需在目标平台执行 `swift test`

## 测试执行

```bash
cd Packages/PluginConversationCacheHitRate
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例，再写实现
2. **Bug 修复** → 追加回归用例，标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan，标记 ✅ 并填写测试方法名
5. **改名同步** → 重命名 `@Test` 函数后必须同步本表，否则 `Scripts/verify-testplan.py` 会报「登记方法在源码不存在」
