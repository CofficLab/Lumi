# TestPlan — PluginLLMProviderMiniMax

## 包概述

PluginLLMProviderMiniMax 的实现包，包含 18 个主要类型；当前测试覆盖 149 条用例。

平台: macOS 14+, iOS 17+
测试文件: 15 个，用例总数: 149

核心组件（源码目录）:
- `LLMProviders/`
- `Models/`
- `Observers/`
- `Services/`
- `Support/`
- `ViewModels/`
- `Views/`

## 公开 API

包内主要类型（按声明顺序抽取，供定位被测对象）:

- `MiniMaxLocalStore`
- `MiniMaxProviderPlugin`
- `MiniMaxUITestingSupport`
- `MiniMaxVendorModels`
- `MiniMaxRemoteModelListLoader`
- `TokenPlanModelDisplayConfig`
- `TokenPlanStatus`
- `MiniMaxSelectionGate`
- `TokenPlanService`
- `MiniMaxSharedConstants`
- `TokenPlanPreviewFixtures`
- `TokenPlanToolbarMetrics`
- `TokenPlanViewModel`
- `TokenPlanDetailView`
- `TokenPlanQuotaList`
- `TokenPlanQuotaCard`
- `TokenPlanQuotaUnit`
- `TokenPlanMetric`

## 关键行为契约（实现约定，非协议要求）

按测试模块归纳，改动对应模块时须保持既有断言成立:

- **MiniMaxLocalStore**（9 条）：由 `writesSnapshotToPluginDirectory`、`configureUsesPluginDataDirectory` 等用例锁定；改动该模块时优先跑对应测试文件。
- **MiniMaxProviderPlugin**（10 条）：由 `pluginIdentityAndMetadata`、`pluginRegistersMiniMaxProvider` 等用例锁定；改动该模块时优先跑对应测试文件。
- **MiniMaxRefreshReproduction**（2 条）：由 `refreshKeepsModelPoolAlignedWithRemote`、`remoteOnlyModelsAreAppended` 用例锁定；改动该模块时优先跑对应测试文件。
- **MiniMaxSelectionGate**（11 条）：由 `allVariantIDsEnableGate`、`otherProvidersDisableGate` 等用例锁定；改动该模块时优先跑对应测试文件。
- **TokenPlanModelDisplayConfig**（12 条）：由 `generalKeys`、`videoKeys` 等用例锁定；改动该模块时优先跑对应测试文件。
- **TokenPlanServiceFetch**（8 条）：由 `fetchesWithBearerToken`、`missingAPIKeyReturnsAuthErrorWithoutRequest` 等用例锁定；改动该模块时优先跑对应测试文件。
- **TokenPlanServiceParsing**（12 条）：由 `parsesAllFields`、`convertsMillisecondsToSeconds` 等用例锁定；改动该模块时优先跑对应测试文件。
- **TokenPlanStatusFormatting**（21 条）：由 `generalModelJoinsBothPercents`、`videoModelAppendsRemainingCount` 等用例锁定；改动该模块时优先跑对应测试文件。
- **TokenPlanTimeFormatting**（15 条）：由 `intervalTimeRangeJoinsBothEnds`、`weeklyTimeRangeJoinsBothEnds` 等用例锁定；改动该模块时优先跑对应测试文件。
- **TokenPlanToolbarRegistration**（9 条）：由 `registersToolbarItemOnTrailing`、`toolbarItemIDIsNamespaced` 等用例锁定；改动该模块时优先跑对应测试文件。
- **TokenPlanViewModel**（10 条）：由 `startsLoadingWithoutChipText`、`nonSuccessStatesHaveNoChipText` 等用例锁定；改动该模块时优先跑对应测试文件。
- **TokenPlanQuotaLayout**（4 条）：由 `quotaListDoesNotOverflowWidth`、`quotaListFitsWithoutScrolling` 等用例锁定；改动该模块时优先跑对应测试文件。
- **MiniMax 模型家族推断**（12 条）：由 `recognizesM3Family`、`recognizesM2Family` 等用例锁定；改动该模块时优先跑对应测试文件。
- **SingleModelProvider**（8 条）：由 `conversationPinnedToMiniMaxWinsOverGlobalSelection`、`conversationPinnedToOtherProviderHidesMiniMaxQuota` 等用例锁定；改动该模块时优先跑对应测试文件。
- **MiniMax 退役模型标记**（6 条）：由 `marksAbsentCatalogModelsRetired`、`doesNotMarkPresentModelsRetired` 等用例锁定；改动该模块时优先跑对应测试文件。

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | MiniMaxLocalStore | 写入后落盘到指定目录的 models.json | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `writesSnapshotToPluginDirectory` |
| 2 | MiniMaxLocalStore | configure 绑定到内核分配的插件目录 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `configureUsesPluginDataDirectory` |
| 3 | MiniMaxLocalStore | store 空列表被忽略，不覆盖已有缓存 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `storeEmptyIgnored` |
| 4 | MiniMaxLocalStore | 过期快照仍可读，仅标记 isStale | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `staleSnapshotStillReadable` |
| 5 | MiniMaxLocalStore | 磁盘内容损坏时返回 nil 并回退静态清单 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `corruptedDiskFallsBack` |
| 6 | MiniMaxLocalStore | clear 清空内存与磁盘文件 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `clearRemovesSnapshot` |
| 7 | MiniMaxLocalStore | 未绑定目录时降级为纯内存，不产生任何文件 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `inMemoryFallbackWritesNothing` |
| 8 | MiniMaxLocalStore | provider 在 store 未注入时仍回退静态清单 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `providerFallsBackToStaticCatalogWithoutStore` |
| 9 | MiniMaxLocalStore | provider 从注入的 store 读到缓存模型并合入模型池 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `providerReadsInjectedStore` |
| 10 | MiniMaxProviderPlugin | 插件身份与元数据稳定 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `pluginIdentityAndMetadata` |
| 11 | MiniMaxProviderPlugin | onBoot 注册唯一 MiniMax OpenAI 协议供应商 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `pluginRegistersMiniMaxProvider` |
| 12 | MiniMaxProviderPlugin | MiniMax 共享模型清单完整有序 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `miniMaxModelCatalog` |
| 13 | MiniMaxProviderPlugin | MiniMax 指向 minimaxi.com 端点 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `miniMaxEndpointConfiguration` |
| 14 | MiniMaxProviderPlugin | MiniMax 支持远程模型源 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `miniMaxUsesRemoteModelSource` |
| 15 | MiniMaxProviderPlugin | 远程模型列表解析只提取模型 id | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `remoteModelListParsing` |
| 16 | MiniMaxProviderPlugin | 远程列表解析失败时抛错而非返回空列表 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `remoteModelListParsingRejectsInvalidPayload` |
| 17 | MiniMaxProviderPlugin | 合并策略保留静态元数据并追加远程新增模型 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `remoteMergeKeepsStaticMetadata` |
| 18 | MiniMaxProviderPlugin | onBoot 在缺少 LLM 管理器时不抛错 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `onBootWithoutManagerDoesNotThrow` |
| 19 | MiniMaxProviderPlugin | onShutdown 不抛错 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `onShutdownDoesNotThrow` |
| 20 | MiniMaxRefreshReproduction | 刷新后模型池保持 9 个，不因 id 错位产生重复条目 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `refreshKeepsModelPoolAlignedWithRemote` |
| 21 | MiniMaxRefreshReproduction | 远程新增模型应追加到静态清单之后 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `remoteOnlyModelsAreAppended` |
| 22 | MiniMaxSelectionGate | 三个 MiniMax 协议变体都算选中 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `allVariantIDsEnableGate` |
| 23 | MiniMaxSelectionGate | 其它供应商不展示 chip | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `otherProvidersDisableGate` |
| 24 | MiniMaxSelectionGate | 未选中任何供应商时不展示 chip | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `nilProviderDisablesGate` |
| 25 | MiniMaxSelectionGate | 反复切换供应商时门控跟随最新状态 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `gateTracksLatestSelection` |
| 26 | MiniMaxSelectionGate | 观察者启动时补同步一次当前选中态 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `observerSyncsInitialStateOnStart` |
| 27 | MiniMaxSelectionGate | 初始未选中 MiniMax 时触发取消回调 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `observerTriggersDeselectWhenOtherProviderSelected` |
| 28 | MiniMaxSelectionGate | 收到 selectionChanged 切换到 MiniMax 时开启门控并拉取 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `selectionEventEnablesGateAndFetches` |
| 29 | MiniMaxSelectionGate | 收到 selectionChanged 切走 MiniMax 时关闭门控并取消在途请求 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `selectionEventDisablesGate` |
| 30 | MiniMaxSelectionGate | cancel 后不再响应事件 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `cancelledObserverIgnoresEvents` |
| 31 | MiniMaxSelectionGate | 重复 start 不会重复注册观察者 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `repeatedStartRegistersOnce` |
| 32 | MiniMaxSelectionGate | 工具栏 chip 贡献 id 稳定且可撤回 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `toolbarItemIDIsStable` |
| 33 | TokenPlanModelDisplayConfig | 常规模型映射到常规文案 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `generalKeys` |
| 34 | TokenPlanModelDisplayConfig | 视频模型映射到视频文案 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `videoKeys` |
| 35 | TokenPlanModelDisplayConfig | 未知模型回落到通用文案 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `unknownKeys` |
| 36 | TokenPlanModelDisplayConfig | model_name 精确匹配才归为已知类型 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `classifiesExactNamesOnly` |
| 37 | TokenPlanModelDisplayConfig | 大小写不影响分类 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `classificationIgnoresCase` |
| 38 | TokenPlanModelDisplayConfig | 所有展示 key 在简体中文下都能解析出翻译 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `allKeysResolveInSimplifiedChinese` |
| 39 | TokenPlanModelDisplayConfig | 所有展示 key 在繁体中文下都能解析出翻译 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `allKeysResolveInTraditionalChinese` |
| 40 | TokenPlanModelDisplayConfig | 配额字段文案 key 在四种中文里都能解析 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `quotaFieldKeysResolveInAllChineseLocales` |
| 41 | TokenPlanServiceFetch | 携带 Bearer Key 请求配额端点并解析成功 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `fetchesWithBearerToken` |
| 42 | TokenPlanServiceFetch | API Key 为空时返回 authError 且不发请求 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `missingAPIKeyReturnsAuthErrorWithoutRequest` |
| 43 | TokenPlanServiceFetch | storageKey 为空串时返回 authError | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `emptyStorageKeyReturnsAuthError` |
| 44 | TokenPlanServiceFetch | HTTP 401/403 归类为 authError | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `httpAuthStatusMapsToAuthError` |
| 45 | TokenPlanServiceFetch | 其它 HTTP 错误归类为 unavailable | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `otherHTTPStatusMapsToUnavailable` |
| 46 | TokenPlanServiceFetch | 传输抛错归类为 unavailable | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `transportFailureMapsToUnavailable` |
| 47 | TokenPlanServiceFetch | 业务认证码经完整链路映射为 authError | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `businessAuthStatusOverTheWireMapsToAuthError` |
| 48 | TokenPlanServiceFetch | 200 但返回错误页时归类为 unavailable | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `htmlErrorPageMapsToUnavailable` |
| 49 | TokenPlanServiceParsing | 解析 model_remains 全部字段 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `parsesAllFields` |
| 50 | TokenPlanServiceParsing | 毫秒剩余时间换算为秒 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `convertsMillisecondsToSeconds` |
| 51 | TokenPlanServiceParsing | 缺失的计数字段回落为 0 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `missingNumericFieldsDefaultToZero` |
| 52 | TokenPlanServiceParsing | 多模型按数组顺序保留 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `preservesMultipleModels` |
| 53 | TokenPlanServiceParsing | 缺少 model_name 的条目被丢弃 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `dropsEntriesWithoutModelName` |
| 54 | TokenPlanServiceParsing | 全部条目缺 model_name 时视为不可用 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `unavailableWhenAllEntriesLackModelName` |
| 55 | TokenPlanServiceParsing | 业务认证错误码映射为 authError | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `businessAuthStatusMapsToAuthError` |
| 56 | TokenPlanServiceParsing | 其它业务错误码映射为 unavailable | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `otherBusinessStatusMapsToUnavailable` |
| 57 | TokenPlanServiceParsing | 缺少 model_remains 字段视为不可用 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `missingModelRemainsIsUnavailable` |
| 58 | TokenPlanServiceParsing | 空 model_remains 数组视为不可用 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `emptyModelRemainsIsUnavailable` |
| 59 | TokenPlanServiceParsing | 非 JSON 响应视为不可用 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `invalidJSONIsUnavailable` |
| 60 | TokenPlanServiceParsing | base_resp 缺失时仍按 status_code 0 处理 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `missingBaseRespTreatedAsSuccess` |
| 61 | TokenPlanStatusFormatting | 普通模型按时段%与周%拼接 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `generalModelJoinsBothPercents` |
| 62 | TokenPlanStatusFormatting | 视频模型拼接当天剩余次数 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `videoModelAppendsRemainingCount` |
| 63 | TokenPlanStatusFormatting | 普通与视频模型同时存在时按顺序拼接 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `combinesGeneralThenVideo` |
| 64 | TokenPlanStatusFormatting | 视频模型次数已超用时不为负 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `videoRemainingCountNeverNegative` |
| 65 | TokenPlanStatusFormatting | 非 general/video 模型不出现在 chip 上 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `unknownModelProducesNoChipText` |
| 66 | TokenPlanStatusFormatting | 空计划不产生 chip 文案 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `emptyPlansProduceNoChipText` |
| 67 | TokenPlanStatusFormatting | model_name 大小写不影响分类 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `classificationIsCaseInsensitive` |
| 68 | TokenPlanStatusFormatting | 剩余时长按天时拆分 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `durationSplitsDaysAndHours` |
| 69 | TokenPlanStatusFormatting | 剩余时长按时分拆分 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `durationSplitsHoursAndMinutes` |
| 70 | TokenPlanStatusFormatting | 不足一分钟按秒展示 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `durationFallsBackToSeconds` |
| 71 | TokenPlanStatusFormatting | 剩余时间非正时无时长分量 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `nonPositiveRemainingHasNoDuration` |
| 72 | TokenPlanStatusFormatting | 重置时间分量含绝对与相对两段 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `resetTimeHasAbsoluteAndRelative` |
| 73 | TokenPlanStatusFormatting | 重置时间缺失时无分量 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `resetTimeMissingHasNoComponents` |
| 74 | TokenPlanStatusFormatting | 未知状态码回落为不可用文案 key | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `unknownStatusFallsBackToQuotaUnavailable` |
| 75 | TokenPlanStatusFormatting | 已知状态码映射到正常/耗尽 key | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `knownStatusMapsToLabelKeys` |
| 76 | TokenPlanStatusFormatting | model_name 映射到展示配置 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `modelDisplayConfigMapping` |
| 77 | TokenPlanStatusFormatting | 时间戳非法时显示占位符 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `invalidTimestampShowsPlaceholder` |
| 78 | TokenPlanTimeFormatting | 时段起止时间以破折号连接 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `intervalTimeRangeJoinsBothEnds` |
| 79 | TokenPlanTimeFormatting | 本周起止时间以破折号连接 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `weeklyTimeRangeJoinsBothEnds` |
| 80 | TokenPlanTimeFormatting | 时间戳缺失时范围显示占位符 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `missingTimestampsShowPlaceholder` |
| 81 | TokenPlanTimeFormatting | 时段重置时间分量含绝对与相对两段 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `intervalRemainsComponents` |
| 82 | TokenPlanTimeFormatting | 本周重置时间分量含绝对与相对两段 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `weeklyRemainsComponents` |
| 83 | TokenPlanTimeFormatting | 剩余时间为 0 时没有重置分量 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `zeroRemainingHasNoComponents` |
| 84 | TokenPlanTimeFormatting | 重置时间文本含绝对时间与相对时长 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `resetTimeTextContainsBothParts` |
| 85 | TokenPlanTimeFormatting | 天与小时拼接 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `durationJoinsDaysAndHours` |
| 86 | TokenPlanTimeFormatting | 分钟与秒拼接 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `durationJoinsMinutesAndSeconds` |
| 87 | TokenPlanTimeFormatting | 空时长的拼接结果为空串 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `emptyDurationProducesEmptyText` |
| 88 | TokenPlanTimeFormatting | 非零单位按从大到小排列 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `unitsAreOrderedDescending` |
| 89 | TokenPlanToolbarRegistration | onBoot 把配额 chip 注册到 chat toolbar trailing | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `registersToolbarItemOnTrailing` |
| 90 | TokenPlanToolbarRegistration | 注册 id 全局唯一且带插件命名空间 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `toolbarItemIDIsNamespaced` |
| 91 | TokenPlanToolbarRegistration | 注册顺序排在其它工具栏项之后 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `registersWithLargerOrderThanOtherPlugins` |
| 92 | TokenPlanToolbarRegistration | chip 视图可构建且门控默认关闭 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `chipViewIsBuildableAndGatedOffByDefault` |
| 93 | TokenPlanToolbarRegistration | onShutdown 摘除工具栏项 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `shutdownRemovesToolbarItem` |
| 94 | TokenPlanToolbarRegistration | 重复 onShutdown 幂等 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `repeatedShutdownIsIdempotent` |
| 95 | TokenPlanToolbarRegistration | 未 boot 直接 shutdown 不抛错 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `shutdownWithoutBootDoesNotThrow` |
| 96 | TokenPlanToolbarRegistration | 缺少 ChatSectionProviding 时不影响供应商注册 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `missingChatSectionStillRegistersProvider` |
| 97 | TokenPlanToolbarRegistration | 缺少 LLM 管理器时不注册任何工具栏项 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `missingManagerRegistersNothing` |
| 98 | TokenPlanViewModel | 初始为加载中且没有 chip 文案 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `startsLoadingWithoutChipText` |
| 99 | TokenPlanViewModel | 非成功状态都不产生 chip 文案 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `nonSuccessStatesHaveNoChipText` |
| 100 | TokenPlanViewModel | 刷新后写入状态并递增 revision | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `refreshAppliesStatusAndBumpsRevision` |
| 101 | TokenPlanViewModel | 请求失败时状态收敛为对应错误而非崩溃 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `refreshFailureConvergesToErrorState` |
| 102 | TokenPlanViewModel | 空 Key 时短路为 authError 且不发请求 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `refreshWithoutAPIKeyShortCircuits` |
| 103 | TokenPlanViewModel | TTL 内重复调用 refreshIfNeeded 不再发请求 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `ttlSuppressesDuplicateRequests` |
| 104 | TokenPlanViewModel | 显式 refresh 绕过 TTL 强制请求 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `explicitRefreshBypassesTTL` |
| 105 | TokenPlanViewModel | 连续 refresh 只保留最后一次结果 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `consecutiveRefreshKeepsLatestResult` |
| 106 | TokenPlanViewModel | cancelPendingFetch 后迟到的响应不写入状态 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `cancelledFetchDoesNotApplyLateResult` |
| 107 | TokenPlanViewModel | 取消后仍可重新拉取 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `canRefreshAgainAfterCancel` |
| 108 | TokenPlanModelDisplayConfig | 视频模型的时段按调用次数计量，其余按百分比计量 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `metricFollowsModelGranularity` |
| 109 | TokenPlanModelDisplayConfig | 每个模型都有独立图标 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `eachModelHasIcon` |
| 110 | TokenPlanModelDisplayConfig | 剩余比例按展示口径换算：百分比取百分比，次数取剩余/上限 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `remainingRatiosFollowMetric` |
| 111 | TokenPlanModelDisplayConfig | 次数口径在无上限时不产生比例 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `countMetricWithoutLimitHasNoRatio` |
| 112 | TokenPlanStatusFormatting | 调用次数文案含已用与上限 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `usageTextShowsUsedAndTotal` |
| 113 | TokenPlanStatusFormatting | 无次数上限时说明不限次 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `usageTextFallsBackToUnlimited` |
| 114 | TokenPlanStatusFormatting | 重置倒计时文案只含相对时长 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `resetCountdownTextOmitsAbsoluteTime` |
| 115 | TokenPlanStatusFormatting | 剩余次数不为负 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `remainingCountNeverNegative` |
| 116 | TokenPlanTimeFormatting | 同一天的时间段省略结束日期 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `sameDayRangeOmitsEndDate` |
| 117 | TokenPlanTimeFormatting | 跨天的时间段保留完整时间戳 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `crossDayRangeKeepsBothDates` |
| 118 | TokenPlanTimeFormatting | 时间戳缺失时紧凑时间段显示占位符 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `missingTimestampsShowPlaceholderInCompactRange` |
| 119 | TokenPlanTimeFormatting | 紧凑时间段属性跟随对应周期 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `compactRangesFollowPeriods` |
| 120 | TokenPlanQuotaLayout | 两个模型的配额列表不横向溢出 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `quotaListDoesNotOverflowWidth` |
| 121 | TokenPlanQuotaLayout | 两个模型的配额列表在弹层内排得下 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `quotaListFitsWithoutScrolling` |
| 122 | TokenPlanQuotaLayout | 模型数量增加时列表仍能渲染 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `quotaListRendersWithManyModels` |
| 123 | TokenPlanQuotaLayout | 配额卡片高度紧凑 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `quotaCardStaysCompact` |
| 124 | MiniMax 模型家族推断 | 识别 M3 家族 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `recognizesM3Family` |
| 125 | MiniMax 模型家族推断 | 识别 M2 家族 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `recognizesM2Family` |
| 126 | MiniMax 模型家族推断 | 未知家族不做猜测 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `unknownFamilyIsNotGuessed` |
| 127 | MiniMax 模型家族推断 | M3 家族的上下文窗口与视觉能力元数据 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `m3FamilyMetadata` |
| 128 | MiniMax 模型家族推断 | M2 家族的上下文窗口与视觉能力元数据 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `m2FamilyMetadata` |
| 129 | MiniMax 模型家族推断 | 未知家族没有上下文窗口 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `unknownFamilyHasNoContextWindow` |
| 130 | MiniMax 模型家族推断 | 按家族补齐远程模型元数据 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `enrichedFillsMetadataByFamily` |
| 131 | MiniMax 模型家族推断 | 未知家族保持 nil，不被填充 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `enrichedKeepsNilForUnknownFamily` |
| 132 | MiniMax 模型家族推断 | 合并后的远程模型带上上下文窗口 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `mergedRemoteModelCarriesContextWindow` |
| 133 | MiniMax 模型家族推断 | 合并时优先静态元数据 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `mergePrefersStaticMetadata` |
| 134 | MiniMax 模型家族推断 | 静态清单符合家族推断规则 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `staticCatalogMatchesFamilyRules` |
| 135 | MiniMax 模型家族推断 | 静态清单 ID 与上游一致 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `staticCatalogIDsMatchUpstream` |
| 136 | SingleModelProvider | 会话钉住 MiniMax 时优先于全局选择 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `conversationPinnedToMiniMaxWinsOverGlobalSelection` |
| 137 | SingleModelProvider | 会话钉住其它供应商时隐藏 MiniMax 配额 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `conversationPinnedToOtherProviderHidesMiniMaxQuota` |
| 138 | SingleModelProvider | 未钉住的会话回落到全局选择 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `unpinnedConversationFallsBackToGlobalSelection` |
| 139 | SingleModelProvider | 过期的会话钉住回落到全局选择 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `staleConversationPinFallsBackToGlobalSelection` |
| 140 | SingleModelProvider | 切换会话时通知观察者 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `switchingConversationNotifiesObserver` |
| 141 | SingleModelProvider | 生效供应商未变化时不重复通知 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `unchangedProviderDoesNotNotifyAgain` |
| 142 | SingleModelProvider | 钉住模型会更新生效供应商 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `pinningModelUpdatesEffectiveProvider` |
| 143 | SingleModelProvider | 缺少会话能力时回落到全局选择 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `fallsBackToGlobalSelectionWithoutConversations` |
| 144 | MiniMax 退役模型标记 | 远程缺失的静态模型标记为退役 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `marksAbsentCatalogModelsRetired` |
| 145 | MiniMax 退役模型标记 | 仍在远程清单中的模型不标记退役 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `doesNotMarkPresentModelsRetired` |
| 146 | MiniMax 退役模型标记 | 仅远程存在的模型不标记退役 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `doesNotMarkRemoteOnlyModelsRetired` |
| 147 | MiniMax 退役模型标记 | 远程清单为空时不标记退役 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `doesNotMarkRetiredWhenRemoteEmpty` |
| 148 | MiniMax 退役模型标记 | 标记退役时保留既有元数据 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `retiringPreservesMetadata` |
| 149 | MiniMax 退役模型标记 | 静态清单初始不带退役标记 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `staticCatalogHasNoRetiredFlag` |

> 说明：全部 **149 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 10 / 10
- P1: 已覆盖 114 / 114
- P2: 已覆盖 25 / 25
- **合计: 149 / 149**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（10 条）
- **P1**: 其余功能性用例（114 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（25 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 149 条用例位于 `Tests/`，需在目标平台执行 `swift test`

## 测试执行

```bash
cd Packages/PluginLLMProviderMiniMax
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例，再写实现
2. **Bug 修复** → 追加回归用例，标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan，标记 ✅ 并填写测试方法名
5. **改名同步** → 重命名 `@Test` 函数后必须同步本表，否则 `Scripts/verify-testplan.py` 会报「登记方法在源码不存在」
