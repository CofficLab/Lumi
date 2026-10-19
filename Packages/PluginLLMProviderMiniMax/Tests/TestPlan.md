# TestPlan — PluginLLMProviderMiniMax

## 包概述

PluginLLMProviderMiniMax 的实现包，包含 14 个主要类型；当前测试覆盖 108 条用例。

平台: macOS 14+, iOS 17+
测试文件: 12 个，用例总数: 108

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

## 关键行为契约（实现约定，非协议要求）

按测试模块归纳，改动对应模块时须保持既有断言成立:

- **MiniMaxLocalStore**（9 条）：由 `writesSnapshotToPluginDirectory`、`configureUsesPluginDataDirectory`、`storeEmptyIgnored` 等用例锁定；改动该模块时优先跑对应测试文件。
- **MiniMaxProviderPlugin**（10 条）：由 `pluginIdentityAndMetadata`、`pluginRegistersMiniMaxProvider`、`miniMaxModelCatalog` 等用例锁定；改动该模块时优先跑对应测试文件。
- **MiniMaxRefreshReproduction**（2 条）：由 `refreshShouldExpandModelPoolFrom6To9`、`remoteOnlyModelsAreAppended` 等用例锁定；改动该模块时优先跑对应测试文件。
- **MiniMaxSelectionGate**（12 条）：由 `allVariantIDsEnableGate`、`otherProvidersDisableGate`、`nilProviderDisablesGate` 等用例锁定；改动该模块时优先跑对应测试文件。
- **TokenPlanModelDisplayConfig**（8 条）：由 `generalKeys`、`videoKeys`、`unknownKeys` 等用例锁定；改动该模块时优先跑对应测试文件。
- **TokenPlanServiceFetch**（8 条）：由 `fetchesWithBearerToken`、`missingAPIKeyReturnsAuthErrorWithoutRequest`、`emptyStorageKeyReturnsAuthError` 等用例锁定；改动该模块时优先跑对应测试文件。
- **TokenPlanServiceParsing**（12 条）：由 `parsesAllFields`、`convertsMillisecondsToSeconds`、`missingNumericFieldsDefaultToZero` 等用例锁定；改动该模块时优先跑对应测试文件。
- **TokenPlanStatusFormatting**（17 条）：由 `generalModelJoinsBothPercents`、`videoModelAppendsRemainingCount`、`combinesGeneralThenVideo` 等用例锁定；改动该模块时优先跑对应测试文件。
- **TokenPlanTimeFormatting**（11 条）：由 `intervalTimeRangeJoinsBothEnds`、`weeklyTimeRangeJoinsBothEnds`、`missingTimestampsShowPlaceholder` 等用例锁定；改动该模块时优先跑对应测试文件。
- **TokenPlanToolbarRegistration**（9 条）：由 `registersToolbarItemOnTrailing`、`toolbarItemIDIsNamespaced`、`registersWithLargerOrderThanOtherPlugins` 等用例锁定；改动该模块时优先跑对应测试文件。
- **TokenPlanViewModel**（10 条）：由 `startsLoadingWithoutChipText`、`nonSuccessStatesHaveNoChipText`、`refreshAppliesStatusAndBumpsRevision` 等用例锁定；改动该模块时优先跑对应测试文件。

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
| 20 | MiniMaxRefreshReproduction | 刷新后模型池应从 6 变为 9（manager 即 UI 读取路径） | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `refreshShouldExpandModelPoolFrom6To9` |
| 21 | MiniMaxRefreshReproduction | 远程新增模型应追加到静态清单之后 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `remoteOnlyModelsAreAppended` |
| 22 | MiniMaxSelectionGate | 三个 MiniMax 协议变体都算选中 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `allVariantIDsEnableGate` |
| 23 | MiniMaxSelectionGate | 其它供应商不展示 chip | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `otherProvidersDisableGate` |
| 24 | MiniMaxSelectionGate | 未选中任何供应商时不展示 chip | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `nilProviderDisablesGate` |
| 25 | MiniMaxSelectionGate | 反复切换供应商时门控跟随最新状态 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `gateTracksLatestSelection` |
| 26 | MiniMaxSelectionGate | 观察者启动时补同步一次当前选中态 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `observerSyncsInitialStateOnStart` |
| 27 | MiniMaxSelectionGate | 初始未选中 MiniMax 时触发取消回调 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `observerTriggersDeselectWhenOtherProviderSelected` |
| 28 | MiniMaxSelectionGate | 收到 selectionChanged 切换到 MiniMax 时开启门控并拉取 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `selectionEventEnablesGateAndFetches` |
| 29 | MiniMaxSelectionGate | 收到 selectionChanged 切走 MiniMax 时关闭门控并取消在途请求 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `selectionEventDisablesGate` |
| 30 | MiniMaxSelectionGate | 非 selectionChanged 事件不影响门控 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `unrelatedEventsDoNotChangeGate` |
| 31 | MiniMaxSelectionGate | cancel 后不再响应事件 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `cancelledObserverIgnoresEvents` |
| 32 | MiniMaxSelectionGate | 重复 start 不会重复注册观察者 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `repeatedStartRegistersOnce` |
| 33 | MiniMaxSelectionGate | 工具栏 chip 贡献 id 稳定且可撤回 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `toolbarItemIDIsStable` |
| 34 | TokenPlanModelDisplayConfig | 常规模型映射到常规文案 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `generalKeys` |
| 35 | TokenPlanModelDisplayConfig | 视频模型映射到视频文案 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `videoKeys` |
| 36 | TokenPlanModelDisplayConfig | 未知模型回落到通用文案 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `unknownKeys` |
| 37 | TokenPlanModelDisplayConfig | model_name 精确匹配才归为已知类型 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `classifiesExactNamesOnly` |
| 38 | TokenPlanModelDisplayConfig | 大小写不影响分类 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `classificationIgnoresCase` |
| 39 | TokenPlanModelDisplayConfig | 所有展示 key 在简体中文下都能解析出翻译 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `allKeysResolveInSimplifiedChinese` |
| 40 | TokenPlanModelDisplayConfig | 所有展示 key 在繁体中文下都能解析出翻译 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `allKeysResolveInTraditionalChinese` |
| 41 | TokenPlanModelDisplayConfig | 配额字段文案 key 在四种中文里都能解析 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `quotaFieldKeysResolveInAllChineseLocales` |
| 42 | TokenPlanServiceFetch | 携带 Bearer Key 请求配额端点并解析成功 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `fetchesWithBearerToken` |
| 43 | TokenPlanServiceFetch | API Key 为空时返回 authError 且不发请求 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `missingAPIKeyReturnsAuthErrorWithoutRequest` |
| 44 | TokenPlanServiceFetch | storageKey 为空串时返回 authError | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `emptyStorageKeyReturnsAuthError` |
| 45 | TokenPlanServiceFetch | HTTP 401/403 归类为 authError | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `httpAuthStatusMapsToAuthError` |
| 46 | TokenPlanServiceFetch | 其它 HTTP 错误归类为 unavailable | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `otherHTTPStatusMapsToUnavailable` |
| 47 | TokenPlanServiceFetch | 传输抛错归类为 unavailable | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `transportFailureMapsToUnavailable` |
| 48 | TokenPlanServiceFetch | 业务认证码经完整链路映射为 authError | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `businessAuthStatusOverTheWireMapsToAuthError` |
| 49 | TokenPlanServiceFetch | 200 但返回错误页时归类为 unavailable | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `htmlErrorPageMapsToUnavailable` |
| 50 | TokenPlanServiceParsing | 解析 model_remains 全部字段 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `parsesAllFields` |
| 51 | TokenPlanServiceParsing | 毫秒剩余时间换算为秒 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `convertsMillisecondsToSeconds` |
| 52 | TokenPlanServiceParsing | 缺失的计数字段回落为 0 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `missingNumericFieldsDefaultToZero` |
| 53 | TokenPlanServiceParsing | 多模型按数组顺序保留 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `preservesMultipleModels` |
| 54 | TokenPlanServiceParsing | 缺少 model_name 的条目被丢弃 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `dropsEntriesWithoutModelName` |
| 55 | TokenPlanServiceParsing | 全部条目缺 model_name 时视为不可用 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `unavailableWhenAllEntriesLackModelName` |
| 56 | TokenPlanServiceParsing | 业务认证错误码映射为 authError | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `businessAuthStatusMapsToAuthError` |
| 57 | TokenPlanServiceParsing | 其它业务错误码映射为 unavailable | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `otherBusinessStatusMapsToUnavailable` |
| 58 | TokenPlanServiceParsing | 缺少 model_remains 字段视为不可用 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `missingModelRemainsIsUnavailable` |
| 59 | TokenPlanServiceParsing | 空 model_remains 数组视为不可用 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `emptyModelRemainsIsUnavailable` |
| 60 | TokenPlanServiceParsing | 非 JSON 响应视为不可用 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `invalidJSONIsUnavailable` |
| 61 | TokenPlanServiceParsing | base_resp 缺失时仍按 status_code 0 处理 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `missingBaseRespTreatedAsSuccess` |
| 62 | TokenPlanStatusFormatting | 普通模型按时段%与周%拼接 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `generalModelJoinsBothPercents` |
| 63 | TokenPlanStatusFormatting | 视频模型拼接当天剩余次数 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `videoModelAppendsRemainingCount` |
| 64 | TokenPlanStatusFormatting | 普通与视频模型同时存在时按顺序拼接 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `combinesGeneralThenVideo` |
| 65 | TokenPlanStatusFormatting | 视频模型次数已超用时不为负 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `videoRemainingCountNeverNegative` |
| 66 | TokenPlanStatusFormatting | 非 general/video 模型不出现在 chip 上 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `unknownModelProducesNoChipText` |
| 67 | TokenPlanStatusFormatting | 空计划不产生 chip 文案 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `emptyPlansProduceNoChipText` |
| 68 | TokenPlanStatusFormatting | model_name 大小写不影响分类 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `classificationIsCaseInsensitive` |
| 69 | TokenPlanStatusFormatting | 剩余时长按天时拆分 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `durationSplitsDaysAndHours` |
| 70 | TokenPlanStatusFormatting | 剩余时长按时分拆分 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `durationSplitsHoursAndMinutes` |
| 71 | TokenPlanStatusFormatting | 不足一分钟按秒展示 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `durationFallsBackToSeconds` |
| 72 | TokenPlanStatusFormatting | 剩余时间非正时无时长分量 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `nonPositiveRemainingHasNoDuration` |
| 73 | TokenPlanStatusFormatting | 重置时间分量含绝对与相对两段 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `resetTimeHasAbsoluteAndRelative` |
| 74 | TokenPlanStatusFormatting | 重置时间缺失时无分量 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `resetTimeMissingHasNoComponents` |
| 75 | TokenPlanStatusFormatting | 未知状态码回落为不可用文案 key | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `unknownStatusFallsBackToQuotaUnavailable` |
| 76 | TokenPlanStatusFormatting | 已知状态码映射到正常/耗尽 key | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `knownStatusMapsToLabelKeys` |
| 77 | TokenPlanStatusFormatting | model_name 映射到展示配置 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `modelDisplayConfigMapping` |
| 78 | TokenPlanStatusFormatting | 时间戳非法时显示占位符 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `invalidTimestampShowsPlaceholder` |
| 79 | TokenPlanTimeFormatting | 时段起止时间以破折号连接 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `intervalTimeRangeJoinsBothEnds` |
| 80 | TokenPlanTimeFormatting | 本周起止时间以破折号连接 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `weeklyTimeRangeJoinsBothEnds` |
| 81 | TokenPlanTimeFormatting | 时间戳缺失时范围显示占位符 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `missingTimestampsShowPlaceholder` |
| 82 | TokenPlanTimeFormatting | 时段重置时间分量含绝对与相对两段 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `intervalRemainsComponents` |
| 83 | TokenPlanTimeFormatting | 本周重置时间分量含绝对与相对两段 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `weeklyRemainsComponents` |
| 84 | TokenPlanTimeFormatting | 剩余时间为 0 时没有重置分量 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `zeroRemainingHasNoComponents` |
| 85 | TokenPlanTimeFormatting | 重置时间文本含绝对时间与相对时长 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `resetTimeTextContainsBothParts` |
| 86 | TokenPlanTimeFormatting | 天与小时拼接 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `durationJoinsDaysAndHours` |
| 87 | TokenPlanTimeFormatting | 分钟与秒拼接 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `durationJoinsMinutesAndSeconds` |
| 88 | TokenPlanTimeFormatting | 空时长的拼接结果为空串 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `emptyDurationProducesEmptyText` |
| 89 | TokenPlanTimeFormatting | 非零单位按从大到小排列 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `unitsAreOrderedDescending` |
| 90 | TokenPlanToolbarRegistration | onBoot 把配额 chip 注册到 chat toolbar trailing | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `registersToolbarItemOnTrailing` |
| 91 | TokenPlanToolbarRegistration | 注册 id 全局唯一且带插件命名空间 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `toolbarItemIDIsNamespaced` |
| 92 | TokenPlanToolbarRegistration | 注册顺序排在其它工具栏项之后 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `registersWithLargerOrderThanOtherPlugins` |
| 93 | TokenPlanToolbarRegistration | chip 视图可构建且门控默认关闭 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `chipViewIsBuildableAndGatedOffByDefault` |
| 94 | TokenPlanToolbarRegistration | onShutdown 摘除工具栏项 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `shutdownRemovesToolbarItem` |
| 95 | TokenPlanToolbarRegistration | 重复 onShutdown 幂等 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `repeatedShutdownIsIdempotent` |
| 96 | TokenPlanToolbarRegistration | 未 boot 直接 shutdown 不抛错 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `shutdownWithoutBootDoesNotThrow` |
| 97 | TokenPlanToolbarRegistration | 缺少 ChatSectionProviding 时不影响供应商注册 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `missingChatSectionStillRegistersProvider` |
| 98 | TokenPlanToolbarRegistration | 缺少 LLM 管理器时不注册任何工具栏项 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `missingManagerRegistersNothing` |
| 99 | TokenPlanViewModel | 初始为加载中且没有 chip 文案 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `startsLoadingWithoutChipText` |
| 100 | TokenPlanViewModel | 非成功状态都不产生 chip 文案 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `nonSuccessStatesHaveNoChipText` |
| 101 | TokenPlanViewModel | 刷新后写入状态并递增 revision | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `refreshAppliesStatusAndBumpsRevision` |
| 102 | TokenPlanViewModel | 请求失败时状态收敛为对应错误而非崩溃 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `refreshFailureConvergesToErrorState` |
| 103 | TokenPlanViewModel | 空 Key 时短路为 authError 且不发请求 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `refreshWithoutAPIKeyShortCircuits` |
| 104 | TokenPlanViewModel | TTL 内重复调用 refreshIfNeeded 不再发请求 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `ttlSuppressesDuplicateRequests` |
| 105 | TokenPlanViewModel | 显式 refresh 绕过 TTL 强制请求 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `explicitRefreshBypassesTTL` |
| 106 | TokenPlanViewModel | 连续 refresh 只保留最后一次结果 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `consecutiveRefreshKeepsLatestResult` |
| 107 | TokenPlanViewModel | cancelPendingFetch 后迟到的响应不写入状态 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `cancelledFetchDoesNotApplyLateResult` |
| 108 | TokenPlanViewModel | 取消后仍可重新拉取 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `canRefreshAgainAfterCancel` |

> 说明：全部 **108 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 9 / 9
- P1: 已覆盖 81 / 81
- P2: 已覆盖 18 / 18
- **合计: 108 / 108**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（9 条）
- **P1**: 其余功能性用例（81 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（18 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 108 条用例位于 `Tests/`，需在目标平台执行 `swift test`

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
