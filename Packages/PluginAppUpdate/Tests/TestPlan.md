# TestPlan — PluginAppUpdate

## 包概述

PluginAppUpdate 的实现包，包含 9 个主要类型；当前测试覆盖 36 条用例。

平台: macOS 14+, iOS 17+
测试文件: 6 个，用例总数: 36

核心组件（源码目录）:
- `Events/`
- `Observers/`
- `Services/`
- `Views/`

## 公开 API

包内主要类型（按声明顺序抽取，供定位被测对象）:

- `AppUpdateBootstrap`
- `UpdateRequestObserver`
- `AppUpdateRuntimeEnvironment`
- `FeedURLDetector`
- `FeedURLReachabilityChecker`
- `UpdateFeedURLProvider`
- `UpdateService`
- `UpdateLifecycleState`
- `AppUpdateAboutView`

## 关键行为契约（实现约定，非协议要求）

按测试模块归纳，改动对应模块时须保持既有断言成立:

- **AppUpdatePlugin**（4 条）：由 `keepsNotificationName`、`keepsFeedPaths`、`keepsFeedHosts` 等用例锁定；改动该模块时优先跑对应测试文件。
- **UpdateRequestObserver**（1 条）：由 `forwardsAndCancelsNotifications` 等用例锁定；改动该模块时优先跑对应测试文件。
- **UpdateService**（3 条）：由 `updateStateTransitions`、`detectsAndCachesReachableFeed`、`ignoresProbeForPreviousFeedConfiguration` 等用例锁定；改动该模块时优先跑对应测试文件。
- **AppUpdatePluginLocalStore**（6 条）：由 `defaultsToStableChannel`、`roundTripsPreviewChannel`、`fallsBackToStableOnCorruptedFile` 等用例锁定。
- **AppUpdateRuntime**（2 条）：由 `usesInjectedDirectory`、`resetClearsInjectedDirectory` 锁定。
- **AppUpdateNotification**（4 条）：由 `keepsNotificationNames`、`postsCheckForUpdates`、`postsInstallPrepared` 等用例锁定。
- **UpdateFeedURLProvider**（4 条）：由 `stableChannelURLs`、`previewChannelPrimary`、`previewChannelFallback` 等用例锁定。
- **ProviderNetworkReachabilityChecker**（3 条）：由 `treats200AsReachable`、`treatsNon200AsUnreachable`、`treatsErrorAsUnreachable` 锁定。
- **AppUpdateRuntimeEnvironment**（1 条）：由 `fallsBackToBundleIdentifier` 锁定。
- **AppUpdateBootstrap**（8 条）：由 `registersChannelProvider`、`unregistersChannelProviderOnStop`、`importsLegacyChannel` 等用例锁定。

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | AppUpdatePlugin | retains the legacy check-for-updates notification name | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `keepsNotificationName` |
| 2 | AppUpdatePlugin | preserves architecture-specific feed paths | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `keepsFeedPaths` |
| 3 | AppUpdatePlugin | uses the domestic primary feed and preserves GitHub fallback | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `keepsFeedHosts` |
| 4 | AppUpdatePlugin | keeps preview feeds isolated from stable feeds | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `keepsPreviewFeedsIsolated` |
| 5 | UpdateRequestObserver | forwards both update commands and stops after cancellation | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `forwardsAndCancelsNotifications` |
| 6 | UpdateService | tracks update lifecycle and clears the ready version on reset | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `updateStateTransitions` |
| 7 | UpdateService | falls back, caches detection, reprobes at expiry, and resets on feed changes | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `detectsAndCachesReachableFeed` |
| 8 | UpdateService | does not let an old in-flight probe overwrite a newly selected feed | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `ignoresProbeForPreviousFeedConfiguration` |
| 9 | AppUpdatePluginLocalStore | new instances default to the stable channel | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `defaultsToStableChannel` |
| 10 | AppUpdatePluginLocalStore | preview channel round-trips through storage | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `roundTripsPreviewChannel` |
| 11 | AppUpdatePluginLocalStore | writes settings.plist into the settings directory | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `writesSettingsPlist` |
| 12 | AppUpdatePluginLocalStore | corrupted storage falls back to stable | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `fallsBackToStableOnCorruptedFile` |
| 13 | AppUpdatePluginLocalStore | unknown channel value falls back to stable | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `fallsBackToStableOnUnknownChannel` |
| 14 | AppUpdatePluginLocalStore | a missing settings directory is created automatically | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `createsMissingDirectory` |
| 15 | AppUpdateRuntime | returns the injected settings directory | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `usesInjectedDirectory` |
| 16 | AppUpdateRuntime | reset clears the injected directory instead of falling back to the real data directory | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `resetClearsInjectedDirectory` |
| 17 | AppUpdateNotification | keeps the legacy notification name strings | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `keepsNotificationNames` |
| 18 | AppUpdateNotification | postCheckForUpdates broadcasts the matching notification | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `postsCheckForUpdates` |
| 19 | AppUpdateNotification | postAppUpdateReadyToInstall carries the version | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `postsReadyToInstallWithVersion` |
| 20 | AppUpdateNotification | postInstallPreparedAppUpdate broadcasts the matching notification | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `postsInstallPrepared` |
| 21 | UpdateFeedURLProvider | stable primary and fallback point at their own hosts | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `stableChannelURLs` |
| 22 | UpdateFeedURLProvider | preview primary uses the pre directory | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `previewChannelPrimary` |
| 23 | UpdateFeedURLProvider | preview fallback uses raw.githubusercontent pre directory | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `previewChannelFallback` |
| 24 | UpdateFeedURLProvider | no-argument entry points equal stable channel plus current architecture | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `noArgumentEntryPoints` |
| 25 | ProviderNetworkReachabilityChecker | 200 is reachable and the probe uses HEAD with the given timeout | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `treats200AsReachable` |
| 26 | ProviderNetworkReachabilityChecker | non-200 is unreachable | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `treatsNon200AsUnreachable` |
| 27 | ProviderNetworkReachabilityChecker | a thrown request is unreachable | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `treatsErrorAsUnreachable` |
| 28 | AppUpdateRuntimeEnvironment | falls back to bundleIdentifier when no Info.plist switch exists | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `fallsBackToBundleIdentifier` |
| 29 | AppUpdateBootstrap | registers the update channel provider on start | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `registersChannelProvider` |
| 30 | AppUpdateBootstrap | injects the storage directory into the runtime configuration | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `injectsStorageDirectory` |
| 31 | AppUpdateBootstrap | unregisters the channel provider on stop | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `unregistersChannelProviderOnStop` |
| 32 | AppUpdateBootstrap | repeated start on the same kernel keeps a single provider | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `repeatedStartKeepsSingleProvider` |
| 33 | AppUpdateBootstrap | registering a network provider injects it into the update service | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `configuresNetworkProvider` |
| 34 | AppUpdateBootstrap | imports the legacy UserDefaults channel when plugin storage is empty | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `importsLegacyChannel` |
| 35 | AppUpdateBootstrap | keeps the plugin channel over the legacy value when a record exists | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `keepsExistingChannelOverLegacy` |
| 36 | AppUpdateBootstrap | stopping without starting is safe | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `stopWithoutStartIsSafe` |

> 说明：全部 **36 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 0 / 0
- P1: 已覆盖 31 / 31
- P2: 已覆盖 5 / 5
- **合计: 36 / 36**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（0 条）
- **P1**: 其余功能性用例（31 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（5 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 36 条用例位于 `Tests/`，需在目标平台执行 `swift test`

## 测试执行

```bash
cd Packages/PluginAppUpdate
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例，再写实现
2. **Bug 修复** → 追加回归用例，标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan，标记 ✅ 并填写测试方法名
5. **改名同步** → 重命名 `@Test` 函数后必须同步本表，否则 `Scripts/verify-testplan.py` 会报「登记方法在源码不存在」
