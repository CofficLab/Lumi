# TestPlan — PluginNetworkManager

## 包概述

PluginNetworkManager Network monitoring and HTTP exchange management plugin for Lumi. Migrated from the legacy `Plugins/NetworkManagerPlugin` (KernelLumi / LumiPlugin architecture) to the new KernelCore / SuperPlugin architecture.

平台: macOS 14+, iOS 17+
测试文件: 4 个，用例总数: 61

核心组件（源码目录）:
- `Extensions/`
- `Models/`
- `Observers/`
- `ProcessNetworkMonitor/`
- `Providers/`
- `Services/`
- `Support/`
- `Tools/`
- `ViewModels/`
- `Views/`

## 公开 API

包内主要类型（按声明顺序抽取，供定位被测对象）:

- `NetworkManagerPlugin`
- `HTTPExchangeRecord`
- `NetworkState`
- `HTTPExchangeChangeCenter`
- `NetworkMetricsObserver`
- `ProcessMonitorService`
- `NetworkProcess`
- `LLMNetworkProviderAdapter`
- `NetworkProvider`
- `HTTPExchangeRetentionCoordinator`
- `HTTPExportProgress`
- `NetworkDataPoint`
- `NetworkService`
- `HTTPExchangeBodyFileWriter`

## 关键行为契约（实现约定，非协议要求）

按测试模块归纳，改动对应模块时须保持既有断言成立:

- **LLMNetworkProviderAdapterRetry**（9 条）：由 `errorIsNormalizedToRetryableHTTPStatus`、`normalizedErrorIsClassifiedRetryable`、`agentLoopFailureIsRetryable` 等用例锁定；改动该模块时优先跑对应测试文件。
- **NetworkSpeedFormatter**（13 条）：由 `formatsGigabytesPerSecond`、`formatsMegabytesPerSecond`、`formatsKilobytesPerSecond` 等用例锁定；改动该模块时优先跑对应测试文件。
- **综合**（25 条）：由 `brotliSSEDecompressionHandlesHighCompressionRatio`、`publicIPRefreshUsesCache`、`publicIPRefreshCanBeForced` 等用例锁定；改动该模块时优先跑对应测试文件。

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | LLMNetworkProviderAdapterRetry | 修复后：529 被归一化为 VendorAPIError.httpStatus，重试策略可识别 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `errorIsNormalizedToRetryableHTTPStatus` |
| 2 | LLMNetworkProviderAdapterRetry | 修复后：归一化错误命中可重试判定（500...599） | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `normalizedErrorIsClassifiedRetryable` |
| 3 | LLMNetworkProviderAdapterRetry | 修复后：AgentLoopFailure 归类为 .server 且可整回合重试 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `agentLoopFailureIsRetryable` |
| 4 | LLMNetworkProviderAdapterRetry | 修复后：529 触发传输层重试至 maxAttempts 上限 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `vendorAPIServiceRetriesOn529` |
| 5 | LLMNetworkProviderAdapterRetry | 修复后：流式路径 529 同样触发重试 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `streamingPathRetriesOn529` |
| 6 | LLMNetworkProviderAdapterRetry | 修复后：流式响应头 529 在转发任何 SSE 事件前抛出，保护重放安全 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `streamingRejectsNon2xxBeforeForwardingEvents` |
| 7 | LLMNetworkProviderAdapterRetry | 取消错误原样透出，不触发重试 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `cancellationPassesThroughWithoutRetry` |
| 8 | LLMNetworkProviderAdapterRetry | 4xx 客户端错误仍不重试（避免放大无效请求） | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `clientErrorStillDoesNotRetry` |
| 9 | LLMNetworkProviderAdapterRetry | 连接类失败（NSURLError 码）行为不变：可重试 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `transportFailureStillRetries` |
| 10 | NetworkSpeedFormatter | formatsGigabytesPerSecond | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `formatsGigabytesPerSecond` |
| 11 | NetworkSpeedFormatter | formatsMegabytesPerSecond | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `formatsMegabytesPerSecond` |
| 12 | NetworkSpeedFormatter | formatsKilobytesPerSecond | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `formatsKilobytesPerSecond` |
| 13 | NetworkSpeedFormatter | formatsBytesPerSecond | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `formatsBytesPerSecond` |
| 14 | NetworkSpeedFormatter | gigabyteThresholdIsInclusive | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `gigabyteThresholdIsInclusive` |
| 15 | NetworkSpeedFormatter | zeroSpeedDisplaysZeroKB | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `zeroSpeedDisplaysZeroKB` |
| 16 | NetworkSpeedFormatter | nonzeroSpeedAppendsPerSecond | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `nonzeroSpeedAppendsPerSecond` |
| 17 | NetworkSpeedFormatter | zeroBytesDisplaysZeroKB | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `zeroBytesDisplaysZeroKB` |
| 18 | NetworkSpeedFormatter | nonzeroBytesNoPerSecondSuffix | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `nonzeroBytesNoPerSecondSuffix` |
| 19 | NetworkSpeedFormatter | zeroSpeedDisplaysZeroKB | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `zeroSpeedDisplaysZeroKB` |
| 20 | NetworkSpeedFormatter | nonzeroSpeedAppendsPerSecond | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `nonzeroSpeedAppendsPerSecond` |
| 21 | NetworkSpeedFormatter | zeroBytesDisplaysZeroKB | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `zeroBytesDisplaysZeroKB` |
| 22 | NetworkSpeedFormatter | nonzeroBytesNoPerSecondSuffix | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `nonzeroBytesNoPerSecondSuffix` |
| 23 | 综合 | brotliSSEDecompressionHandlesHighCompressionRatio | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `brotliSSEDecompressionHandlesHighCompressionRatio` |
| 24 | 综合 | publicIPRefreshUsesCache | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `publicIPRefreshUsesCache` |
| 25 | 综合 | publicIPRefreshCanBeForced | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `publicIPRefreshCanBeForced` |
| 26 | 综合 | processMonitorToggleIgnoresRepeatedAssignments | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `processMonitorToggleIgnoresRepeatedAssignments` |
| 27 | 综合 | networkUsageUpdatePublishesOnce | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `networkUsageUpdatePublishesOnce` |
| 28 | 综合 | networkHistoryQuarantinesInvalidStorageAndRecovers | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `networkHistoryQuarantinesInvalidStorageAndRecovers` |
| 29 | 综合 | dailyHTTPExchangeCountSeriesIncludesEmptyDaysAndIgnoresOlderRecords | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `dailyHTTPExchangeCountSeriesIncludesEmptyDaysAndIgnoresOlderRecords` |
| 30 | 综合 | dailyHTTPExchangeCountCachePersistsCleanDaysAndInvalidatesDirtyDays | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `dailyHTTPExchangeCountCachePersistsCleanDaysAndInvalidatesDirtyDays` |
| 31 | 综合 | dailyHTTPExchangeCountCacheRejectsStaleReadAfterInvalidation | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `dailyHTTPExchangeCountCacheRejectsStaleReadAfterInvalidation` |
| 32 | 综合 | dailyHTTPExchangeSeriesPersistsHistoricalCountsAndRefreshesToday | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `dailyHTTPExchangeSeriesPersistsHistoricalCountsAndRefreshesToday` |
| 33 | 综合 | dailyHTTPExchangeSeriesInvalidatesCacheAfterRetentionDeletesRecords | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `dailyHTTPExchangeSeriesInvalidatesCacheAfterRetentionDeletesRecords` |
| 34 | 综合 | httpExchangeExportIncludesRequestResponseAndErrorDetails | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `httpExchangeExportIncludesRequestResponseAndErrorDetails` |
| 35 | 综合 | fetchDomainsCollectsDistinctHostsFromRecentRecords | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `fetchDomainsCollectsDistinctHostsFromRecentRecords` |
| 36 | 综合 | httpExchangeRetentionKeepsOnlyRecentRecordsWithinCountLimit | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `httpExchangeRetentionKeepsOnlyRecentRecordsWithinCountLimit` |
| 37 | 综合 | searchPageAndCountFilterByExactHost | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `searchPageAndCountFilterByExactHost` |
| 38 | 综合 | listPageFiltersMetadataAndLoadsBodiesOnlyForSelectedDetail | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `listPageFiltersMetadataAndLoadsBodiesOnlyForSelectedDetail` |
| 39 | 综合 | httpExchangeStoreCreatesStartedAtIndexForExistingStoreCompatibility | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `httpExchangeStoreCreatesStartedAtIndexForExistingStoreCompatibility` |
| 40 | 综合 | httpExchangeBatchExportIncludesAllRecordsWithNumberedHeaders | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `httpExchangeBatchExportIncludesAllRecordsWithNumberedHeaders` |
| 41 | 综合 | httpExchangeSnapshotExportMatchesRecordExport | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `httpExchangeSnapshotExportMatchesRecordExport` |
| 42 | 综合 | batchExportFromSnapshotsReportsProgressPerRecord | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `batchExportFromSnapshotsReportsProgressPerRecord` |
| 43 | 综合 | exportFileNameIsStableUniqueAndSanitized | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `exportFileNameIsStableUniqueAndSanitized` |
| 44 | 综合 | timeRangeFilterCutOffsAreCorrect | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `timeRangeFilterCutOffsAreCorrect` |
| 45 | 综合 | exportProgressTracksLifecycleAndFailure | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `exportProgressTracksLifecycleAndFailure` |
| 46 | 综合 | emitSSEEventsSplitsByBlankLineAndKeepsTail | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `emitSSEEventsSplitsByBlankLineAndKeepsTail` |
| 47 | 综合 | emitSSEEventsHonorsStopAndHandlesDelimiterVariants | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `emitSSEEventsHonorsStopAndHandlesDelimiterVariants` |
| 48 | LLMNetworkProviderAdapterRetry | 529 携带 Retry-After 时，归一化错误保留服务端建议的等待时间 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `normalizedErrorCarriesRetryAfter` |
| 49 | LLMNetworkProviderAdapterRetry | Retry-After 进入重试决策，成为实际等待时长 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `retryAfterBecomesRetryDelay` |
| 50 | LLMNetworkProviderAdapterRetry | 流式路径同样保留 Retry-After | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `streamingPathCarriesRetryAfter` |
| 51 | LLMNetworkProviderAdapterRetry | 没有 Retry-After 头时退避建议为空，交由本地抖动退避决定 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `missingRetryAfterYieldsNoAdvice` |
| 52 | LLMNetworkProviderAdapterRetry | AgentLoopFailure 保留服务端退避建议，供整回合重试遵守 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `agentLoopFailureCarriesRetryAfter` |
| 53 | ProcessMonitorLifecycle | start 后 nettop 处于运行状态 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `startMonitoringLaunchesNettop` |
| 54 | ProcessMonitorLifecycle | stop 后 nettop 被终止 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `stopMonitoringTerminatesNettop` |
| 55 | ProcessMonitorLifecycle | 多次 start 只启动一个 nettop | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `repeatedStartLaunchesSingleNettop` |
| 56 | ProcessMonitorLifecycle | 引用计数归零后 nettop 退出 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `nettopStopsWhenRefCountReachesZero` |
| 57 | ProcessMonitorLifecycle | stop 多于 start 不会崩溃且保持停止状态 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `extraStopKeepsServiceStopped` |
| 58 | ProcessMonitorLifecycle | 观察者不再启动 nettop（#128 核心断言） | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `observerDoesNotStartNettop` |
| 59 | ProcessMonitorLifecycle | 面板开关切换会成对调用 start/stop | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `togglePairsStartAndStop` |
| 60 | ProcessMonitorLifecycle | 面板开关重复赋值不会重复启停 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `repeatedAssignmentDoesNotDuplicateCalls` |
| 61 | ProcessMonitorLifecycle | 面板可见时 nettop 启动，隐藏时退出（端到端联动） | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `panelVisibilityDrivesNettopLifecycle` |

> 说明：全部 **61 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 24 / 24
- P1: 已覆盖 35 / 35
- P2: 已覆盖 2 / 2
- **合计: 61 / 61**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（24 条）
- **P1**: 其余功能性用例（35 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（2 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 47 条用例位于 `Tests/`，需在目标平台执行 `swift test`

## 测试执行

```bash
cd Packages/PluginNetworkManager
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例，再写实现
2. **Bug 修复** → 追加回归用例，标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan，标记 ✅ 并填写测试方法名
5. **改名同步** → 重命名 `@Test` 函数后必须同步本表，否则 `Scripts/verify-testplan.py` 会报「登记方法在源码不存在」
