# TestPlan — PluginConversationCacheHitRate

## 包概述

PluginConversationCacheHitRate Lumi 编辑器插件。

平台: macOS 14+, iOS 17+
测试文件: 6 个，用例总数: 63

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

- **CacheHitRateChartGeometry**（2 条）：由 `singlePointMatchesFullMapping`、`valueIsClampedToUnitRange` 等用例锁定；改动该模块时优先跑对应测试文件。
- **CacheHitRateHistory**（15 条）：由 `historyBuildsOneSamplePerUsableAssistantMessage`、`historyAssignsSequentialIndexesInChronologicalOrder`、`historyCumulativeHitRateIsTokenWeighted` 等用例锁定；改动该模块时优先跑对应测试文件。
- **CacheHitRateObserverAndLifecycle**（26 条）：由 `observerReplaysCurrentSelectionOnInit`、`observerForwardsSelectionChanges`、`observerForwardsEveryMessageChangeKind` 等用例锁定；改动该模块时优先跑对应测试文件。
- **CacheHitRateRefreshGate**（4 条）：由 `latestRevisionForCurrentConversationIsPublished`、`supersededRevisionIsDropped`、`cancelledRefreshIsDropped` 等用例锁定；改动该模块时优先跑对应测试文件。
- **综合**（16 条）：由 `cacheHitRatePluginInstantiates`、`cacheHitRateToolbarStateForwardsTypedEvents`、`cacheHitRateStatsUseTypedTokenFields` 等用例锁定；改动该模块时优先跑对应测试文件。

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | CacheHitRateChartGeometry | 单点坐标与全量映射一致 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `singlePointMatchesFullMapping` |
| 2 | CacheHitRateChartGeometry | 值域被钳制到 0...1 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `valueIsClampedToUnitRange` |
| 3 | CacheHitRateHistory | historyBuildsOneSamplePerUsableAssistantMessage | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `historyBuildsOneSamplePerUsableAssistantMessage` |
| 4 | CacheHitRateHistory | historyAssignsSequentialIndexesInChronologicalOrder | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `historyAssignsSequentialIndexesInChronologicalOrder` |
| 5 | CacheHitRateHistory | historyCumulativeHitRateIsTokenWeighted | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `historyCumulativeHitRateIsTokenWeighted` |
| 6 | CacheHitRateHistory | historyClampsCachedTokensToTotal | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `historyClampsCachedTokensToTotal` |
| 7 | CacheHitRateHistory | historyFallsBackToInputTokenCountWhenTotalIsMissing | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `historyFallsBackToInputTokenCountWhenTotalIsMissing` |
| 8 | CacheHitRateHistory | historyReadsLegacyMetadataKeys | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `historyReadsLegacyMetadataKeys` |
| 9 | CacheHitRateHistory | historyUsesMetadataTotalInsteadOfUncachedInputTokenCount | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `historyUsesMetadataTotalInsteadOfUncachedInputTokenCount` |
| 10 | CacheHitRateHistory | historyPrefersStrongCachedTotalOverMetadata | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `historyPrefersStrongCachedTotalOverMetadata` |
| 11 | CacheHitRateHistory | historyCumulativeNotInflatedByLegacyMixedRepresentation | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `historyCumulativeNotInflatedByLegacyMixedRepresentation` |
| 12 | CacheHitRateHistory | historySkipsNonAssistantAndInvalidSamples | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `historySkipsNonAssistantAndInvalidSamples` |
| 13 | CacheHitRateHistory | historyStatisticsMatchSamples | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `historyStatisticsMatchSamples` |
| 14 | CacheHitRateHistory | emptyHistoryHasNoStatistics | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `emptyHistoryHasNoStatistics` |
| 15 | CacheHitRateHistory | historyAndStatsAgreeOnParsing | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `historyAndStatsAgreeOnParsing` |
| 16 | CacheHitRateHistory | percentTextKeepsOneDecimalForSmallNonZeroRates | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `percentTextKeepsOneDecimalForSmallNonZeroRates` |
| 17 | CacheHitRateHistory | smoothedPathNeverOvershootsSegmentEndpoints | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `smoothedPathNeverOvershootsSegmentEndpoints` |
| 18 | CacheHitRateObserverAndLifecycle | 初始化时立即回放当前选中会话 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `observerReplaysCurrentSelectionOnInit` |
| 19 | CacheHitRateObserverAndLifecycle | 选中会话变化时转发新的会话 ID | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `observerForwardsSelectionChanges` |
| 20 | CacheHitRateObserverAndLifecycle | 五类消息变化事件都转发所属会话 ID | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `observerForwardsEveryMessageChangeKind` |
| 21 | CacheHitRateObserverAndLifecycle | 取消后释放两个订阅并停止转发 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `observerCancelReleasesSubscriptions` |
| 22 | CacheHitRateObserverAndLifecycle | 重复取消是幂等的 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `observerCancelIsIdempotent` |
| 23 | CacheHitRateObserverAndLifecycle | 启动后注册工具栏按钮 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `bootRegistersToolbarButton` |
| 24 | CacheHitRateObserverAndLifecycle | 缺少必需 Provider 时不注册按钮也不抛错 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `bootWithoutProvidersIsNoop` |
| 25 | CacheHitRateObserverAndLifecycle | 启动时把当前选中会话同步到工具栏状态 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `bootSyncsSelectedConversationToToolbarState` |
| 26 | CacheHitRateObserverAndLifecycle | 选中会话变化后工具栏状态跟随更新 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `selectionChangeUpdatesToolbarState` |
| 27 | CacheHitRateObserverAndLifecycle | 重复启动会注销上一轮的观察者 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `secondBootCancelsPreviousObserver` |
| 28 | CacheHitRateObserverAndLifecycle | 关闭时移除工具栏按钮并注销观察者 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `shutdownRemovesButtonAndCancelsObserver` |
| 29 | CacheHitRateObserverAndLifecycle | 未启动就关闭不会抛错 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `shutdownWithoutBootIsSafe` |
| 30 | CacheHitRateObserverAndLifecycle | 多个观察者都能收到事件 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `multipleObserversReceiveEvents` |
| 31 | CacheHitRateObserverAndLifecycle | 注销一个观察者不影响另一个 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `cancellingOneObserverKeepsOther` |
| 32 | CacheHitRateObserverAndLifecycle | 重复注销同一个观察者只生效一次 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `cancellingTwiceIsIdempotent` |
| 33 | CacheHitRateObserverAndLifecycle | 消息变化事件携带会话 ID | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `messagesChangedCarriesConversationID` |
| 34 | CacheHitRateObserverAndLifecycle | 选中会话变化事件携带新的会话 ID | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `selectionChangedCarriesConversationID` |
| 35 | CacheHitRateObserverAndLifecycle | metadata 中非数字的缓存用量被忽略 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `metadataWithNonNumericValueIsRejected` |
| 36 | CacheHitRateObserverAndLifecycle | metadata 只有缓存用量、没有总量时返回 nil | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `metadataWithoutTotalIsRejected` |
| 37 | CacheHitRateObserverAndLifecycle | 强类型字段优先于 metadata 回退 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `typedFieldsWinOverMetadata` |
| 38 | CacheHitRateObserverAndLifecycle | 缓存用量被夹取到不超过总输入量 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `cachedTokensAreClamped` |
| 39 | CacheHitRateObserverAndLifecycle | 非 assistant 消息不参与采样 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `nonAssistantMessageIsSkipped` |
| 40 | CacheHitRateObserverAndLifecycle | 空历史的统计值均为 nil | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `emptyHistoryHasNoStatistics` |
| 41 | CacheHitRateObserverAndLifecycle | 同一时间戳按 UUID 排序保证稳定顺序 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `sameTimestampIsOrderedByUUID` |
| 42 | CacheHitRateObserverAndLifecycle | 累计命中率按 token 加权而非算术平均 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `cumulativeRateIsTokenWeighted` |
| 43 | CacheHitRateObserverAndLifecycle | 预览样例消息可构造出非空历史 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `previewMessagesProduceHistory` |
| 44 | CacheHitRateRefreshGate | latestRevisionForCurrentConversationIsPublished | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `latestRevisionForCurrentConversationIsPublished` |
| 45 | CacheHitRateRefreshGate | supersededRevisionIsDropped | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `supersededRevisionIsDropped` |
| 46 | CacheHitRateRefreshGate | cancelledRefreshIsDropped | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `cancelledRefreshIsDropped` |
| 47 | CacheHitRateRefreshGate | staleConversationSnapshotIsDropped | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `staleConversationSnapshotIsDropped` |
| 48 | 综合 | cacheHitRatePluginInstantiates | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `cacheHitRatePluginInstantiates` |
| 49 | 综合 | cacheHitRateToolbarStateForwardsTypedEvents | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `cacheHitRateToolbarStateForwardsTypedEvents` |
| 50 | 综合 | cacheHitRateStatsUseTypedTokenFields | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `cacheHitRateStatsUseTypedTokenFields` |
| 51 | 综合 | cacheHitRateStatsKeepLegacyMetadataCompatibility | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `cacheHitRateStatsKeepLegacyMetadataCompatibility` |
| 52 | 综合 | cacheHitRateStatsIgnoreUnsupportedRequests | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `cacheHitRateStatsIgnoreUnsupportedRequests` |
| 53 | 综合 | cacheHitRateUsesTokenWeightedRateAsPrimaryValue | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `cacheHitRateUsesTokenWeightedRateAsPrimaryValue` |
| 54 | 综合 | cacheHitRateExplainsMissingUsageWithDistinctNonEmptyText | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `cacheHitRateExplainsMissingUsageWithDistinctNonEmptyText` |
| 55 | 综合 | cacheHitRateLocalizationCatalogDefinesAllReasons | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `cacheHitRateLocalizationCatalogDefinesAllReasons` |
| 56 | 综合 | cacheHitRatePrecisePercentTextRendersOneDecimal | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `cacheHitRatePrecisePercentTextRendersOneDecimal` |
| 57 | 综合 | cacheHitRateEmptyStatsHaveZeroWeightedRate | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `cacheHitRateEmptyStatsHaveZeroWeightedRate` |
| 58 | 综合 | toolbarStateDoesNotNotifyWhenSelectedConversationIsUnchanged | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `toolbarStateDoesNotNotifyWhenSelectedConversationIsUnchanged` |
| 59 | 综合 | cacheHitRateBoundsCachedTokensToTotalTokens | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `cacheHitRateBoundsCachedTokensToTotalTokens` |
| 60 | 综合 | cacheHitRateIgnoresNonAssistantMessages | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `cacheHitRateIgnoresNonAssistantMessages` |
| 61 | 综合 | cacheHitRateSkipsRequestsWithNonPositiveTotal | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `cacheHitRateSkipsRequestsWithNonPositiveTotal` |
| 62 | 综合 | cacheHitRateSkipsRequestsWithNegativeCachedTokens | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `cacheHitRateSkipsRequestsWithNegativeCachedTokens` |
| 63 | 综合 | cacheHitRateFallsBackToInputTokenCountWhenTotalIsMissing | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `cacheHitRateFallsBackToInputTokenCountWhenTotalIsMissing` |

> 说明：全部 **63 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 8 / 8
- P1: 已覆盖 50 / 50
- P2: 已覆盖 5 / 5
- **合计: 63 / 63**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（8 条）
- **P1**: 其余功能性用例（50 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（5 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 63 条用例位于 `Tests/`，需在目标平台执行 `swift test`

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
