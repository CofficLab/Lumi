# TestPlan — PluginAppStoreConnect

## 包概述

PluginAppStoreConnect Current `KernelCore` implementation of the App Store Connect integration. - Product/module: `PluginAppStoreConnect` - Plugin id: `com.coffic.lumi.plugin.app-store-connect` - Rail tab: `app-store-connect.sidebar` - Enable policy: disabled by default The plugin provides App Store Connect account, app/version, localization, screenshot, release, and Xcode Cloud management through the workbench and the `app_store_connect_*` Agent tools.

平台: macOS 14+, iOS 17+
测试文件: 5 个，用例总数: 52

核心组件（源码目录）:
- `Sources/`

## 公开 API

包内主要类型（按声明顺序抽取，供定位被测对象）:

- `AppStoreConnectLocalization`
- `AppStoreConnectPlugin`
- `AppStoreConnectRuleContributor`
- `AppStoreConnectSkillContributor`
- `ASCSubmissionStage`
- `ASCSubmissionTimelineContext`
- `AppStoreApp`
- `AppStoreConnectListResponse`
- `AppStoreConnectCredentials`
- `ScreenshotSet`
- `VersionCreateValidationError`
- `AppStoreVersion`
- `AppStoreVersionLocalization`
- `CiProduct`

## 关键行为契约（实现约定，非协议要求）

按测试模块归纳，改动对应模块时须保持既有断言成立:

- **ASCSubmissionTimeline**（13 条）：由 `submissionPreviewBuildLabel`、`submissionPreviewSummaries`、`submissionPreviewCodableRoundTrip` 等用例锁定；改动该模块时优先跑对应测试文件。
- **AppStoreConnectPlugin**（9 条）：由 `pluginMetadata`、`settingsEntry`、`activationKeepsChatToolbarCategoryVisible` 等用例锁定；改动该模块时优先跑对应测试文件。
- **AppStoreConnectRuleContributor**（1 条）：由 `loadsReleaseSafetyRuleFromResource` 等用例锁定；改动该模块时优先跑对应测试文件。
- **ConnectCacheInvalidator**（12 条）：由 `ageRatingPatchInvalidatesDeclarationRead`、`versionPatchInvalidatesDetailAndList` 等用例锁定；改动写操作后的缓存失效策略或缓存 key 结构时优先跑对应测试文件。
- **ASC Chat Toolbar binding**（8 条）：由 `appConfigurationProvidesAppID`、`bundleIDIsDetectedFromXcodeProject` 等用例锁定；改动聊天工具栏的项目绑定解析时优先跑对应测试文件。
- **StubClientCapability**（5 条）：由 `appIDBindingLoadsVersions`、`switchingProjectsClearsState` 等用例锁定；改动聊天工具栏 ViewModel 的项目切换与绑定时优先跑对应测试文件。
- **VMBusy**（3 条）：由 `nestedRunBusyIsReentrant`、`fastOperationSkipsOverlay`、`slowOperationShowsOverlay` 等用例锁定；改动该模块时优先跑对应测试文件。

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | ASCSubmissionTimeline | 提交快照的 Build 展示标签拼接预发布版本号与构建号 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `submissionPreviewBuildLabel` |
| 2 | ASCSubmissionTimeline | 提交快照汇总本地化区域码并标记风险提示 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `submissionPreviewSummaries` |
| 3 | ASCSubmissionTimeline | 提交快照经过 JSON 编解码后保持一致 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `submissionPreviewCodableRoundTrip` |
| 4 | ASCSubmissionTimeline | 提交时间线消息携带专属渲染类型与渲染器 ID | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `submissionTimelineMessageShape` |
| 5 | ASCSubmissionTimeline | 提交时间线消息的正文摘要区分提交前与提交后 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `submissionTimelineSummaryText` |
| 6 | ASCSubmissionTimeline | 提交时间线消息的结构化载荷可从 metadata 还原 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `submissionTimelinePayloadRoundTrip` |
| 7 | ASCSubmissionTimeline | 提交时间线消息的载荷缺失时返回 nil 而不是崩溃 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `submissionTimelinePayloadMissing` |
| 8 | ASCSubmissionTimeline | 提交时间线消息被判定为时间线事件，不回流 LLM | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `submissionTimelineIsExcludedFromLLMContext` |
| 9 | ASCSubmissionTimeline | 普通系统消息不会被误判为提交时间线事件 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `regularMessageIsNotSubmissionTimelineEvent` |
| 10 | ASCSubmissionTimeline | 提交审核渲染器可以接管提交时间线消息 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `submissionRendererMatchesSubmissionMessage` |
| 11 | ASCSubmissionTimeline | 提交审核渲染器的优先级高于通用兜底渲染器 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `submissionRendererOrderBeatsDefault` |
| 12 | ASCSubmissionTimeline | 插件启动时注册提交审核渲染器，关闭时注销 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `pluginRegistersSubmissionRenderer` |
| 13 | ASCSubmissionTimeline | 提交审核工具在缺少会话上下文时不产生时间线消息 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `submitToolWithoutContextProducesNoTimelineMessage` |
| 14 | AppStoreConnectPlugin | plugin metadata follows the current integration conventions | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `pluginMetadata` |
| 15 | AppStoreConnectPlugin | plugin contributes its API configuration to Settings | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `settingsEntry` |
| 16 | AppStoreConnectPlugin | activating the plugin keeps chat toolbar items visible | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `activationKeepsChatToolbarCategoryVisible` |
| 17 | AppStoreConnectPlugin | plugin loads its App Store Connect skill from bundled resources | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `appStoreConnectSkill` |
| 18 | AppStoreConnectPlugin | all restored agent tools use unique current names | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `toolNamesUseCurrentConvention` |
| 19 | AppStoreConnectPlugin | schemas expose object roots | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `toolSchemasAreObjects` |
| 20 | AppStoreConnectPlugin | delete version tool is a high-risk single-id operation | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `deleteVersionToolShape` |
| 21 | AppStoreConnectPlugin | update version exposes earliestReleaseDate alongside existing fields | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `updateVersionSchemaIncludesEarliestReleaseDate` |
| 22 | AppStoreConnectPlugin | credentials require all App Store Connect signing fields | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `credentialsCompleteness` |
| 23 | AppStoreConnectRuleContributor | App Store Connect 插件从 Markdown 资源贡献 Agent Rule | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `loadsReleaseSafetyRuleFromResource` |
| 24 | VMBusy | nested runBusy keeps one continuous loading overlay | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `nestedRunBusyIsReentrant` |
| 25 | VMBusy | a fast operation never shows the overlay | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `fastOperationSkipsOverlay` |
| 26 | VMBusy | a slow operation shows and then hides the overlay | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `slowOperationShowsOverlay` |
| 27 | ConnectCacheInvalidator | 年龄分级 PATCH 后失效 appInfo 声明读取缓存 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `ageRatingPatchInvalidatesDeclarationRead` |
| 28 | ConnectCacheInvalidator | 年龄分级 PATCH 不影响无关的缓存条目 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `ageRatingPatchKeepsUnrelatedEntries` |
| 29 | ConnectCacheInvalidator | 版本 PATCH 后失效版本详情与版本列表缓存 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `versionPatchInvalidatesDetailAndList` |
| 30 | ConnectCacheInvalidator | 版本 PATCH 不影响其它版本的详情 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `versionPatchKeepsOtherVersions` |
| 31 | ConnectCacheInvalidator | 截图预约上传后失效截图列表缓存 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `screenshotReserveInvalidatesLists` |
| 32 | ConnectCacheInvalidator | 截图上传完成后失效截图列表缓存 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `screenshotCompletionInvalidatesLists` |
| 33 | ConnectCacheInvalidator | 截图删除后失效截图列表缓存 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `screenshotDeleteInvalidatesLists` |
| 34 | ConnectCacheInvalidator | 创建审核提交后失效提交列表缓存 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `submissionCreateInvalidatesList` |
| 35 | ConnectCacheInvalidator | 触发提交后失效提交项缓存 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `submissionTriggerInvalidatesItems` |
| 36 | ConnectCacheInvalidator | 撤回提交后失效提交列表缓存 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `submissionWithdrawInvalidatesList` |
| 37 | ConnectCacheInvalidator | accountKey 含分隔符时内存缓存同样被失效 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `memoryCacheIsInvalidatedWhenAccountKeyContainsSeparator` |
| 38 | ConnectCacheInvalidator | 内存缓存失效不影响其它账户的条目 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `memoryInvalidationIsScopedToAccount` |
| 39 | ASC Chat Toolbar binding | 应用配置提供 App ID | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `appConfigurationProvidesAppID` |
| 40 | ASC Chat Toolbar binding | 应用配置提供 Bundle ID | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `appConfigurationProvidesBundleID` |
| 41 | ASC Chat Toolbar binding | 空白值被当作缺省处理 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `blankValuesAreTreatedAsAbsent` |
| 42 | ASC Chat Toolbar binding | 从 Xcode 工程解析出 Bundle ID | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `bundleIDIsDetectedFromXcodeProject` |
| 43 | ASC Chat Toolbar binding | 仅含占位符的工程解析不出 Bundle ID | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `pbxprojParsingReturnsNilForPlaceholdersOnly` |
| 44 | ASC Chat Toolbar binding | 工程解析跳过占位符 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `pbxprojParsingSkipsPlaceholders` |
| 45 | ASC Chat Toolbar binding | Swift Package 检测不出 Bundle ID | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `bundleIDDetectionReturnsNilForSwiftPackage` |
| 46 | ASC Chat Toolbar binding | 缺少配置时不产生绑定 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `missingConfigurationYieldsNoBinding` |
| 47 | StubClientCapability | App ID 绑定后加载版本列表 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `appIDBindingLoadsVersions` |
| 48 | StubClientCapability | Bundle ID 绑定后解析出应用 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `bundleIDBindingResolvesApp` |
| 49 | StubClientCapability | 切换项目后清空状态 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `switchingProjectsClearsState` |
| 50 | StubClientCapability | 未匹配的 Bundle ID 报告错误 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `unmatchedBundleIDReportsError` |
| 51 | StubClientCapability | 无绑定的项目报告无绑定 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `projectWithoutBindingReportsNoBinding` |
| 52 | TestStorageProvider | 聊天工具栏入口已注册 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `chatToolbarEntryIsRegistered` |

> 说明：全部 **52 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 11 / 11
- P1: 已覆盖 37 / 37
- P2: 已覆盖 4 / 4
- **合计: 52 / 52**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（11 条）
- **P1**: 其余功能性用例（37 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（4 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 52 条用例位于 `Tests/`，需在目标平台执行 `swift test`

## 测试执行

```bash
cd Packages/PluginAppStoreConnect
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例，再写实现
2. **Bug 修复** → 追加回归用例，标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan，标记 ✅ 并填写测试方法名
5. **改名同步** → 重命名 `@Test` 函数后必须同步本表，否则 `Scripts/verify-testplan.py` 会报「登记方法在源码不存在」
