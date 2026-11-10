# TestPlan — PluginNetworkManager

## 包概述

PluginNetworkManager Network monitoring and HTTP exchange management plugin for Lumi. Migrated from the legacy `Plugins/NetworkManagerPlugin` (KernelLumi / LumiPlugin architecture) to the new KernelCore / SuperPlugin architecture.

平台: macOS 14+, iOS 17+
测试文件: 12 个，用例总数: 95

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
- **NetworkProviderResponseHeaderTimeout**（1 条）：由 `stalledResponseHeaderTimeoutSurvivesRetryClassification` 锁定兜底超时必须带 `NSURLErrorTimedOut`；改动流式响应头超时或错误归一化时优先跑对应测试文件。
- **DownloadFileToolExchangeLogging**（3 条）：由 `successfulDownloadIsRecordedInExchangeLog`、`failedDownloadIsRecordedWithError`、`non2xxDownloadIsRecordedWithStatus` 锁定下载工具的 exchange 记录；改动 `network_download_file` 时优先跑对应测试文件。
- **NetworkSpeedFormatter**（13 条）：由 `formatsGigabytesPerSecond`、`formatsMegabytesPerSecond`、`formatsKilobytesPerSecond` 等用例锁定；改动该模块时优先跑对应测试文件。
- **NetworkHistoryGraphGeometry**（3 条）：由 `timeFractionsReflectSamplingGap`、`hoverPicksPointByTimestamp` 等用例锁定；改动历史图表时间轴或悬停命中逻辑时优先跑对应测试文件。
- **网络历史范围裁剪**（4 条）：由 `oneHourRangeUsesHighResolutionBuffer`、`fourHourRangeTrimsLongTermBuffer` 等用例锁定；改动历史时间范围语义或视图取数方式时优先跑对应测试文件。
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
| 43 | 综合 | exportFileNameIsStableUniqueAndSanitized（文件名带 exchange ID，不同批次同方法/URL 不碰撞；长 URL 截断保留 ID 后缀，**回归 #976**） | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `exportFileNameIsStableUniqueAndSanitized` |
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
| 62 | ProcessMonitorLifecycle | 默认 nettop 参数包含 `-n` 与 `-s 1` | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `defaultNettopArgumentsIncludeNameResolutionOffAndInterval` |
| 63 | ProcessMonitorLifecycle | 默认 nettop 环境包含 `NSUnbufferedIO=YES` | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `defaultNettopEnablesUnbufferedOutput` |
| 64 | ProcessMonitorLifecycle | start 为子进程保留阻塞 stdin 管道 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `startRetainsInputPipe` |
| 65 | ProcessMonitorLifecycle | stop 释放 stdin 管道与 nettop 进程 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `stopReleasesInputPipeAndProcess` |
| 66 | ProcessMonitorLifecycle | 只返回能解析到运行程序的 PID，不存在的 PID 不给兜底图标 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `batchSkipsPIDsWithoutRunningApplication` |
| 67 | 网络历史范围裁剪 | 1 小时范围取高频缓冲并剔除过期样本 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `oneHourRangeUsesHighResolutionBuffer` |
| 68 | 网络历史范围裁剪 | 4 小时范围剔除超出范围的长期样本 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `fourHourRangeTrimsLongTermBuffer` |
| 69 | 网络历史范围裁剪 | 24 小时与 30 天范围返回不同的数据量 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `differentLongRangesReturnDifferentData` |
| 70 | 网络历史范围裁剪 | 迷你趋势图按时间窗口取样而非按条数 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `miniTrendUsesTimeWindow` |
| 71 | get_http_exchange_detail | schema 允许仅传 id 或仅传 url | 读取工具 inputSchema | 检查 required/anyOf | 不存在全局 required；anyOf 同时包含 id 与 url 的 required 分支 | P0 | ✅ 已覆盖 | `httpExchangeDetailSchemaAcceptsIDOrURL` |
| 72 | NetworkManager 菜单栏生命周期 | 禁用自动撤回，重新启用恢复贡献 | 真实 kernel 启停插件 | 禁用/启用插件 | 禁用后贡献为空，启用后恢复 speed 与 popup 贡献 | P1 | ✅ 已覆盖 | `disableAndEnableRestoresContributions` |
| 73 | HTTP 统计工具 | limit 只裁剪明细，不改变匹配总数 | 60 条记录（30×200 / 30×500，500 均 2.5s），limit 分别取 10/10/20 | 调用 domain / failed / slow 三个工具 | Total=60、Summary=30、5xx=30、Found=30，且明细数量受限 | P0 | ✅ 已覆盖 | `summariesCountAllMatchesWhileLimitOnlyCapsDetails` |
| 74 | ProcessMonitorParsing | nettop 首帧的累计字节不会作为瞬时速度发布 | 注入首帧 900MB/100MB 累计值 | 解析 + flush | processes 为空 | P1 | ✅ 已覆盖 | `firstSampleIsIgnored` |
| 75 | ProcessMonitorParsing | 第二帧才按周期 delta 发布速度 | 首帧累计值 + 第二帧 1024/2048 | 解析 + flush | 仅一条进程记录，速度为 1024/2048 | P1 | ✅ 已覆盖 | `secondSamplePublishesDeltaSpeed` |
| 76 | ProcessMonitorParsing | 截断到同名的不同进程按完整名称区分，不会错误合并 | 两行截断名均为 `com.apple.WebKi`、PID 100/101，注入完整名称 | 解析 + flush | 得到 2 条记录，名称分别为 WebContent 与 Networking | P1 | ✅ 已覆盖 | `truncatedNamesAreResolvedAndNotMerged` |
| 77 | ProcessMonitorParsing | 无法解析完整名称时回退 nettop 原名 | 假 PID 无法通过 proc_pidpath 解析 | 解析 + flush | 名称保留为 `Lumi` | P2 | ✅ 已覆盖 | `fallsBackToNettopNameWhenResolutionFails` |
| 78 | ProcessMonitorParsing | 首个有效 delta 发布后才标记快照就绪 | 首帧仅累计值，第二帧为 delta | 解析 + flush | 首帧后未就绪，第二帧后置位 | P2 | ✅ 已覆盖 | `snapshotFlagTurnsReadyAfterFirstDelta` |
| 79 | TopNetworkProcesses | 内联进程列表按总速率降序、最多 5 条并排除零值与显示为 0 的速率 | 构造 8 条不同速率的进程，其中 1 条零速率、1 条亚字节速率 | 读取 `topNetworkProcesses` | 得到 5 条且顺序为速率降序 | P1 | ✅ 已覆盖 | `sortsLimitsAndFiltersZeroSpeed` |
| 80 | TopNetworkProcesses | 速率格式化随量级切换单位与小数位 | 512 B/s、16 KB/s、1.5 MB/s、2 GB/s | 调用 `formatForStatusBar` | 分别输出 512B/s、16KB/s、1.5MB/s、2.0GB/s | P2 | ✅ 已覆盖 | `rateFormattingSwitchesUnitsAndDecimals` |
| 81 | TopNetworkProcesses | 内联列表与详情浮层同时可见时不会提前停止监控 | 连续 acquire 两次后 release 一次 | 观察启动/停止次数 | 启动 1 次、停止 0 次；再次 release 后停止 1 次 | P1 | ✅ 已覆盖 | `concurrentVisibilityKeepsMonitoring` |
| 82 | ProcessMonitorParsing | 同名进程聚合为一条并标注份数，本应用组单独标记 | 两个同名 Helper + Lumi 自身 PID | 解析 + flush | Helper 一条且份数 2、速率相加；Lumi 标记为本应用 | P1 | ✅ 已覆盖 | `sameNameProcessesAggregateWithCountAndSelfFlag` |
| 83 | ProcessMonitorParsing | 单次 flush 合并多帧时按采样跨度归一化速率 | 一次输出两帧、每帧 1024 字节 | 解析 + flush | 速率为 1024 B/s 而非 2048 | P1 | ✅ 已覆盖 | `coalescedFramesNormalizeBySampleSpan` |
| 84 | NetworkHistoryGraphGeometry | 历史图表按真实时间戳布置点位，采样空档占据对应水平距离 | 10 个点，中间有 600s 空档 | 计算水平比例 | 第 5 点为 40/680，空档后点 > 0.9，非等距 5/9 | P1 | ✅ 已覆盖 | `timeFractionsReflectSamplingGap` |
| 85 | NetworkHistoryGraphGeometry | 悬停按时间映射命中最近点，空档中间不误选相邻序号 | 同上不规则时间序列 | 以 0.5 比例求最近点 | 命中空档两端更近者；0/1 分别命中首末点 | P1 | ✅ 已覆盖 | `hoverPicksPointByTimestamp` |
| 86 | NetworkHistoryGraphGeometry | 单点或时间戳相同时退回等距布局，空输入返回 nil | 单点、同时间戳两点、空数组 | 求值比例与最近点 | 比例为 nil，最近点按下标钳制，空数组为 nil | P2 | ✅ 已覆盖 | `degenerateInputsFallBackToEvenSpacing` |
| 87 | HTTP 统计工具 | exchange store 不可用时抛出而非返回错误字符串 | 清空 store | 依次调用 summary / failed / slow / list / detail | 五次均抛出 `ToolExecutionError` | P1 | ✅ 已覆盖 | `toolsThrowWhenExchangeStoreIsUnavailable` |
| 88 | HTTP 统计工具 | 参数非法时抛出而非返回错误字符串 | 无 | 调用 domain 工具缺 domain、下载工具传非法 URL | 两次均抛出 `ToolExecutionError` | P1 | ✅ 已覆盖 | `toolsThrowForInvalidArguments` |
| 89 | get_http_exchange_detail | 记录不存在时抛出而非返回 "not found" 字符串 | 空 store | 调用 detail 工具传随机 id | 抛出 `ToolExecutionError` | P1 | ✅ 已覆盖 | `exchangeDetailThrowsWhenRecordIsMissing` |
| 90 | HTTP 查询窗口 | 过滤在完整保留数据上执行，旧匹配不被固定窗口截断 | 5,001 条记录，最旧一条命中 domain / 失败 / 慢请求 / URL 关键词 | 依次调用 list / domain / failed / slow | 四个工具均找到该记录（各 1 条），list 额外返回其请求体 | P0 | ✅ 已覆盖 | `filtersFindMatchesOlderThanTheFormerFetchWindow` |
| 91 | get_http_exchange_detail | 按 UUID 与 URL 都能查到超出旧 1,000 条窗口的记录 | 1,001 条记录，最旧一条使用唯一 URL | 分别按 id 与 url 调用 detail 工具 | 两次都返回该记录详情 | P1 | ✅ 已覆盖 | `exchangeDetailFindsRecordOlderThanTheFormerWindow` |
| 92 | NetworkProviderResponseHeaderTimeout | 响应头兜底超时保留可重试分类（**回归 #975**） | 注入永不返回响应头的 URLProtocol 桩，兜底超时 0.2s | 调用 `withResponseHeaderTimeout`，再把合成错误经 `LLMNetworkProviderAdapter` 归一化并判定重试 | 错误带 `NSURLErrorTimedOut`；归一化为 `NSURLErrorDomain/-1001`；默认 3 次尝试下 `shouldRetry == true` | P0 | ✅ 已覆盖 | `stalledResponseHeaderTimeoutSurvivesRetryClassification` |
| 93 | DownloadFileToolExchangeLogging | 成功下载写入一条 HTTP exchange（**回归 #977**） | 注入返回 200 + 正文的下载桩，配置临时 exchange store | 调用 `network_download_file` | 记录 1 条 GET，URL/状态码/响应正文/完成时间/耗时齐全 | P1 | ✅ 已覆盖 | `successfulDownloadIsRecordedInExchangeLog` |
| 94 | DownloadFileToolExchangeLogging | 网络失败下载写入带错误的 HTTP exchange（**回归 #977**） | 注入抛 `URLError(.timedOut)` 的下载桩 | 调用 `network_download_file` | 仍然记录 1 条 exchange，errorDomain/errorCode 为 NSURLError 超时，状态码为空 | P1 | ✅ 已覆盖 | `failedDownloadIsRecordedWithError` |
| 95 | DownloadFileToolExchangeLogging | 非 2xx 下载写入带状态码的 HTTP exchange（**回归 #977**） | 注入返回 500 + 正文的下载桩 | 调用 `network_download_file` | 记录 1 条 exchange，状态码 500 且保留响应正文 | P1 | ✅ 已覆盖 | `non2xxDownloadIsRecordedWithStatus` |

> 说明：全部 **95 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 34 / 34
- P1: 已覆盖 55 / 55
- P2: 已覆盖 6 / 6
- **合计: 95 / 95**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（34 条）
- **P1**: 其余功能性用例（55 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（6 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 95 条用例位于 `Tests/`，需在目标平台执行 `swift test`

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
