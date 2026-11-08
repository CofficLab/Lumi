# TestPlan — PluginConversationCacheHitRate

## 包概述

PluginConversationCacheHitRate Lumi 编辑器插件。

平台: macOS 14+, iOS 17+
测试文件: 5 个，用例总数: 57

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
- **缓存命中率Observer**（5 条）：由 `observerReplaysCurrentSelectionOnInit`、`observerForwardsSelectionChanges`、`observerCancelReleasesSubscriptions` 等用例锁定。
- **缓存命中率插件生命周期**（7 条）：由 `bootRegistersToolbarButton`、`selectionChangeUpdatesToolbarState`、`shutdownRemovesButtonAndCancelsObserver` 等用例锁定。
- **缓存命中率工具栏状态**（5 条）：由 `multipleObserversReceiveEvents`、`messagesChangedCarriesConversationID`、`selectionChangedCarriesConversationID` 等用例锁定。
- **缓存命中率采样解析**（5 条）：由 `typedFieldsWinOverMetadata`、`cachedTokensAreClamped`、`nonAssistantMessageIsSkipped` 等用例锁定。
- **缓存命中率历史**（3 条）：由 `sameTimestampIsOrderedByUUID`、`cumulativeRateIsTokenWeighted`、`previewMessagesProduceHistory` 等用例锁定。

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
| 28 | 缓存命中率Observer | 初始化时立即回放当前选中会话 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `observerReplaysCurrentSelectionOnInit` |
| 29 | 缓存命中率Observer | 选中会话变化时转发新的会话 ID | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `observerForwardsSelectionChanges` |
| 30 | 缓存命中率Observer | 五类消息变化事件都转发所属会话 ID | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `observerForwardsEveryMessageChangeKind` |
| 31 | 缓存命中率Observer | 取消后释放两个订阅并停止转发 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `observerCancelReleasesSubscriptions` |
| 32 | 缓存命中率Observer | 重复取消是幂等的 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `observerCancelIsIdempotent` |
| 33 | 缓存命中率插件生命周期 | 启动后注册工具栏按钮 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `bootRegistersToolbarButton` |
| 34 | 缓存命中率插件生命周期 | 缺少必需 Provider 时不注册按钮也不抛错 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `bootWithoutProvidersIsNoop` |
| 35 | 缓存命中率插件生命周期 | 启动时把当前选中会话同步到工具栏状态 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `bootSyncsSelectedConversationToToolbarState` |
| 36 | 缓存命中率插件生命周期 | 选中会话变化后工具栏状态跟随更新 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `selectionChangeUpdatesToolbarState` |
| 37 | 缓存命中率插件生命周期 | 重复启动会注销上一轮的观察者 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `secondBootCancelsPreviousObserver` |
| 38 | 缓存命中率插件生命周期 | 关闭时移除工具栏按钮并注销观察者 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `shutdownRemovesButtonAndCancelsObserver` |
| 39 | 缓存命中率插件生命周期 | 未启动就关闭不会抛错 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `shutdownWithoutBootIsSafe` |
| 40 | 缓存命中率工具栏状态 | 多个观察者都能收到事件 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `multipleObserversReceiveEvents` |
| 41 | 缓存命中率工具栏状态 | 注销一个观察者不影响另一个 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `cancellingOneObserverKeepsOther` |
| 42 | 缓存命中率工具栏状态 | 重复注销同一个观察者只生效一次 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `cancellingTwiceIsIdempotent` |
| 43 | 缓存命中率工具栏状态 | 消息变化事件携带会话 ID | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `messagesChangedCarriesConversationID` |
| 44 | 缓存命中率工具栏状态 | 选中会话变化事件携带新的会话 ID | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `selectionChangedCarriesConversationID` |
| 45 | 缓存命中率采样解析 | metadata 中非数字的缓存用量被忽略 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `metadataWithNonNumericValueIsRejected` |
| 46 | 缓存命中率采样解析 | metadata 只有缓存用量、没有总量时返回 nil | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `metadataWithoutTotalIsRejected` |
| 47 | 缓存命中率采样解析 | 强类型字段优先于 metadata 回退 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `typedFieldsWinOverMetadata` |
| 48 | 缓存命中率采样解析 | 缓存用量被夹取到不超过总输入量 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `cachedTokensAreClamped` |
| 49 | 缓存命中率采样解析 | 非 assistant 消息不参与采样 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `nonAssistantMessageIsSkipped` |
| 50 | 缓存命中率历史 | 同一时间戳按 UUID 排序保证稳定顺序 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `sameTimestampIsOrderedByUUID` |
| 51 | 缓存命中率历史 | 累计命中率按 token 加权而非算术平均 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `cumulativeRateIsTokenWeighted` |
| 52 | 缓存命中率历史 | 预览样例消息可构造出非空历史 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `previewMessagesProduceHistory` |
| 53 | 缓存命中率折线图 | 平滑曲线不越出每段采样点的取值区间 | 像素坐标 0→100%→100% 的三个点 | 调用 `smoothedPath` 并检查控制点与曲线中点 | 控制点与中点 y 均在该段两端之间 | P0 | ✅ 已覆盖 | `smoothedPathNeverOvershootsSegmentEndpoints` |
| 54 | 刷新门禁 | 当前会话的最新代次刷新可以发布（**回归 #998**） | revision 与当前一致 | 调用 `shouldPublish` | 返回 true | P1 | ✅ 已覆盖 | `latestRevisionForCurrentConversationIsPublished` |
| 55 | 刷新门禁 | 被新 revision 取代的刷新不得发布（**回归 #998**） | S1 的 revision 1 晚于 S2 的 revision 2 返回 | 调用 `shouldPublish` | 返回 false，新统计不被旧快照覆盖 | P0 | ✅ 已覆盖 | `supersededRevisionIsDropped` |
| 56 | 刷新门禁 | 已取消的刷新不得发布（**回归 #998**） | 外层任务已取消但 detached 快照仍返回 | 调用 `shouldPublish` | 返回 false | P0 | ✅ 已覆盖 | `cancelledRefreshIsDropped` |
| 57 | 刷新门禁 | 切换会话后上一会话的快照不得发布 | 快照会话与当前选中会话不同 | 调用 `shouldPublish` | 返回 false | P1 | ✅ 已覆盖 | `staleConversationSnapshotIsDropped` |

> 说明：全部 **57 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 4 / 4
- P1: 已覆盖 43 / 43
- P2: 已覆盖 10 / 10
- **合计: 57 / 57**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（4 条）
- **P1**: 其余功能性用例（43 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（10 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 53 条用例位于 `Tests/`，需在目标平台执行 `swift test`

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
