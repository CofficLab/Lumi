# TestPlan — PluginAppUpdate

## 包概述

PluginAppUpdate 的实现包，包含 9 个主要类型；当前测试覆盖 48 条用例。

平台: macOS 14+, iOS 17+
测试文件: 6 个，用例总数: 39

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
- **UpdateService**（9 条）：由 `updateStateTransitions`、`detectsAndCachesReachableFeed`、`ignoresProbeForPreviousFeedConfiguration`、`setChannelReprobesNewChannelFeed`（#236）、`setupInitializesUpdaterAfterPreparation`（#234）、`waitingCheckDiscardedAfterChannelSwitch` / `waitingCheckProceedsWhenChannelUnchanged`（#235）、`keepsOldSelectionWhenPersistenceFails` 等用例锁定。
- **AppUpdatePluginLocalStore**（7 条）：由 `defaultsToStableChannel`、`roundTripsPreviewChannel`、`fallsBackToStableOnCorruptedFile` 等用例锁定。
- **AppUpdateRuntime**（2 条）：由 `usesInjectedDirectory`、`resetClearsInjectedDirectory` 锁定。
- **AppUpdateNotification**（4 条）：由 `keepsNotificationNames`、`postsCheckForUpdates`、`postsInstallPrepared` 等用例锁定。
- **UpdateFeedURLProvider**（4 条）：由 `stableChannelURLs`、`previewChannelPrimary`、`previewChannelFallback` 等用例锁定。
- **ProviderNetworkReachabilityChecker**（3 条）：由 `treats200AsReachable`、`treatsNon200AsUnreachable`、`treatsErrorAsUnreachable` 锁定。
- **AppUpdateRuntimeEnvironment**（1 条）：由 `fallsBackToBundleIdentifier` 锁定。
- **AppUpdateBootstrap**（8 条）：由 `registersChannelProvider`、`unregistersChannelProviderOnStop`、`importsLegacyChannel` 等用例锁定。
- **UpdateStagedInstallationInvalidationTests**（5 条）：由 `setChannelRemovesStagedInstallationOfAbandonedChannel`、`lateStagingAfterChannelSwitchIsInvalidated`、`matchingChannelStagedInstallIsKept` 等用例锁定。

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
| 37 | AppUpdatePluginLocalStore | 落盘失败时 setChannel 抛出而非静默吞掉（#524） | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `setChannelThrowsWhenWriteFails` |
| 38 | UpdateService | 持久化失败时保留旧通道，不把未落盘的选择当作生效（#524） | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `keepsOldSelectionWhenPersistenceFails` |
| 39 | UpdateService | 持久化成功后立即应用新通道并落盘 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `appliesNewSelectionAfterSuccessfulPersist` |
| 40 | UpdateService | 切换通道后自动探测新通道主源，不可达时落到备用源（#236） | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `setChannelReprobesNewChannelFeed` |
| 41 | UpdateService | feed 准备完成后自动初始化 updater，无需手动检查（#234） | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `setupInitializesUpdaterAfterPreparation` |
| 42 | UpdateService | 通道切换后，等待旧准备的检查被丢弃，不再驱动 Sparkle 检查（#235） | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `waitingCheckDiscardedAfterChannelSwitch` |
| 43 | UpdateService | 通道未切换时等待的检查正常驱动 Sparkle 检查（#235） | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `waitingCheckProceedsWhenChannelUnchanged` |
| 44 | 暂存安装作废（#522） | 暂存安装目录遵循 Sparkle 2.x 的缓存布局约定 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `stagedInstallationDirectoryFollowsSparkleConvention` |
| 45 | 暂存安装作废（#522） | 切换通道后移除被放弃通道已暂存的安装 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `setChannelRemovesStagedInstallationOfAbandonedChannel` |
| 46 | 暂存安装作废（#522） | 未暂存时切换通道是 no-op，不产生残留目录 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `setChannelIsNoOpWhenNothingStaged` |
| 47 | 暂存安装作废（#522） | 检查发起后暂存才完成、且期间切换了通道：迟到的暂存被作废 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `lateStagingAfterChannelSwitchIsInvalidated` |
| 48 | 暂存安装作废（#522） | 通道一致时暂存安装保持不动，正常静默安装不受影响 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `matchingChannelStagedInstallIsKept` |

> 说明：全部 **48 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。
>
> 回归 #524（更新通道持久化失败必须 surfaced）：`setChannel` 改为 throwing，
> `UpdateService.setChannel` 先落盘再应用、失败时保留旧选择（store 可注入）。
> 变异验证：M1 把落盘改回 `try?` 吞错 → 37/38 红；M3 去掉 catch 里的 `return`
> 让失败后仍应用新通道 → 38 红；还原后全绿。
>
> 回归 #522（通道切换不得安装被放弃通道的暂存更新）：Sparkle 2.10.1 公开 API
> 无法取消已暂存的 quit-安装（取消消息仅内部可达），改为移除其暂存目录
> `<Caches>/<bundleID>/org.sparkle-project.Sparkle/Installation` 使工具 stage-2
> 报错退出。`setChannel` 落盘成功后移除；`willInstallUpdateOnQuit` 依
> `feedURLString` 记录的检查时通道比对，迟到暂存一并作废，通道一致时不动。
> 变异验证：M1 去掉 setChannel 的移除 → 45 红；M2 改为无条件移除 → 48 红；
> M3 迟到校验改空操作 → 47 红；还原后全绿。

## 覆盖率统计

- P0: 已覆盖 6 / 6
- P1: 已覆盖 35 / 35
- P2: 已覆盖 7 / 7
- **合计: 48 / 48**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（6 条）
- **P1**: 其余功能性用例（35 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（7 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 48 条用例位于 `Tests/`，需在目标平台执行 `swift test`

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
