# TestPlan — PluginAppStoreConnect

## 包概述

PluginAppStoreConnect Current `KernelCore` implementation of the App Store Connect integration. - Product/module: `PluginAppStoreConnect` - Plugin id: `com.coffic.lumi.plugin.app-store-connect` - Rail tab: `app-store-connect.sidebar` - Enable policy: disabled by default The plugin provides App Store Connect account, app/version, localization, screenshot, release, and Xcode Cloud management through the workbench and the `app_store_connect_*` Agent tools.

平台: macOS 14+, iOS 17+
测试文件: 12 个，用例总数: 69

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
- **ConnectCacheInvalidator**（14 条）：由 `ageRatingPatchInvalidatesDeclarationRead`、`versionPatchInvalidatesDetailAndList`、`buildAssignmentPatchInvalidatesRelationshipRead` 等用例锁定；改动写操作后的缓存失效策略或缓存 key 结构时优先跑对应测试文件。
- **ASC Chat Toolbar binding**（8 条）：由 `appConfigurationProvidesAppID`、`bundleIDIsDetectedFromXcodeProject` 等用例锁定；改动聊天工具栏的项目绑定解析时优先跑对应测试文件。
- **StubClientCapability**（5 条）：由 `appIDBindingLoadsVersions`、`switchingProjectsClearsState` 等用例锁定；改动聊天工具栏 ViewModel 的项目切换与绑定时优先跑对应测试文件。
- **VMBusy**（3 条）：由 `nestedRunBusyIsReentrant`、`fastOperationSkipsOverlay`、`slowOperationShowsOverlay` 等用例锁定；改动该模块时优先跑对应测试文件。
- **VM App 切换**（4 条）：由 `loadingAnotherAppIsNotSkipped`、`lateVersionsFromPreviousAppAreDiscarded`、`currentVersionsAreApplied`、`lateAppsFromPreviousAccountAreDiscarded` 等用例锁定；改动 App 选择、账号切换、版本加载或代次校验时优先跑对应测试文件。
- **SetAppStoreConnectAgeRatingTool**（4 条）：由 `schemaExposesMissingAttributes`、`explicitFalseIsSent`、`absentAttributesAreOmitted`、`decodesNewAttributes` 锁定；改动年龄分级参数或 Apple 字段映射时优先跑对应测试文件。
- **工具失败语义**（3 条）：由 `missingRequiredArgumentsThrow`、`blankArgumentsThrow`、`invalidIsEnabledThrows` 锁定；改动工具参数校验或失败处理时优先跑对应测试文件。
- **ConnectClient 构建出口合规声明**（2 条）：由 `alreadySetDeclarationIsTreatedAsNoop`、`otherFailuresStillThrow` 锁定；改动 `updateBuildEncryption` 或 HTTP 409 错误分类时优先跑对应测试文件。

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
| 13 | ASCSubmissionTimeline | 提交审核工具缺少 versionID 时抛出 `ToolExecutionError` | — | 执行该用例 | 断言抛出工具错误，不再返回 `isError` 字符串结果 | P1 | ✅ 已覆盖 | `submitToolWithoutVersionIDThrows` |
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
| 53 | VM 截图刷新 | 强制刷新截图时绕过内存字典 | 字典里有旧列表 | `reloadScreenshotsForSelectedDisplayType(forceRefresh: true)` | 真的发起请求（无传输时上报错误），不再静默返回旧列表 | P0 | ✅ 已覆盖 | `forceRefreshBypassesScreenshotDictionary` |
| 54 | VM 截图刷新 | 普通切换展示类型时复用内存字典 | 字典里有当前展示类型的列表 | `reloadScreenshotsForSelectedDisplayType()` | 不发起请求、无错误，直接展示字典内容 | P1 | ✅ 已覆盖 | `regularReloadReusesScreenshotDictionary` |
| 55 | VM App 切换 | 切到别的 App 时，加载不会被上一 App 的进行中请求挡住 | 上一 App 的加载标记仍在 | 切到 App B 后调用 `loadVersions()` | 真正发起 B 的加载并清理自己的标记 | P0 | ✅ 已覆盖 | `loadingAnotherAppIsNotSkipped` |
| 56 | VM App 切换 | 上一 App 迟到的版本结果不会写入当前选择 | 已从 App A 切到 App B | 用 A 的代次调用 `applyLoadedVersions` | 返回 false，`versions` 与 `selectedVersion` 保持为空 | P0 | ✅ 已覆盖 | `lateVersionsFromPreviousAppAreDiscarded` |
| 57 | VM App 切换 | 当前 App 与代次的版本结果正常写入 | 已选中 App A | 用当前代次调用 `applyLoadedVersions` | 返回 true，写入版本并选中第一个 | P1 | ✅ 已覆盖 | `currentVersionsAreApplied` |
| 58 | SetAppStoreConnectAgeRatingTool | schema 暴露此前缺失的布尔与枚举分级字段 | — | 读取 `inputSchema` | `socialMedia` 等 9 个布尔字段类型为 boolean，5 个枚举字段类型为 string | P1 | ✅ 已覆盖 | `schemaExposesMissingAttributes` |
| 59 | SetAppStoreConnectAgeRatingTool | 显式 false 不被丢弃，仍进入 PATCH 属性 | — | 传入 `socialMedia=false` 等参数 | 属性中包含 `socialMedia: false` 等值 | P1 | ✅ 已覆盖 | `explicitFalseIsSent` |
| 60 | SetAppStoreConnectAgeRatingTool | 未提供的字段不进入 PATCH 属性 | — | 只传 `socialMedia` | 属性键集合只有 `socialMedia` | P2 | ✅ 已覆盖 | `absentAttributesAreOmitted` |
| 61 | SetAppStoreConnectAgeRatingTool | Apple 返回的新分级字段可被解码 | — | 解码含新增字段的声明 JSON | 新增字段值正确读出 | P1 | ✅ 已覆盖 | `decodesNewAttributes` |
| 62 | 工具失败语义 | 缺少必填参数时抛出 `ToolExecutionError` | 无 | 依次调用 22 个需要必填参数的工具并传空参数 | 每次均抛出 `ToolExecutionError`，不再返回 `Missing or empty ...` 字符串 | P1 | ✅ 已覆盖 | `missingRequiredArgumentsThrow` |
| 63 | 工具失败语义 | 空白参数等同于缺失并抛出 | 无 | 传入只含空白的 appID / versionID | 均抛出 `ToolExecutionError` | P1 | ✅ 已覆盖 | `blankArgumentsThrow` |
| 64 | 工具失败语义 | isEnabled 非法时抛出而不是退回默认值 | 合法 workflowID | 传入 `isEnabled: maybe` | 抛出 `ToolExecutionError` | P1 | ✅ 已覆盖 | `invalidIsEnabledThrows` |
| 65 | ConnectCacheInvalidator | 关联 build 后失效该版本的关系读取缓存 | 关系读取已缓存为 `{"data": null}` | `PATCH /v1/appStoreVersions/{id}/relationships/build` | 该版本的关系读取缓存被清除，后续读取不再返回关联前的空值 | P0 | ✅ 已覆盖 | `buildAssignmentPatchInvalidatesRelationshipRead` |
| 66 | ConnectCacheInvalidator | 关联 build 不影响其它版本的关系读取缓存 | 另一版本的关系读取已缓存 | 关联 version-1 的 build | version-2 的关系读取缓存保留 | P1 | ✅ 已覆盖 | `buildAssignmentPatchKeepsOtherVersions` |
| 67 | ConnectClient 构建出口合规声明 | 声明值已相同时视为已达成，不抛错 | PATCH /v1/builds/{id} 返回 409 `ENTITY_ERROR.ATTRIBUTE.INVALID` | 调用 `updateBuildEncryption` | 返回 false，不抛错，关联流程可继续 | P0 | ✅ 已覆盖 | `alreadySetDeclarationIsTreatedAsNoop` |
| 68 | ConnectClient 构建出口合规声明 | 声明写入的其它失败仍然抛出 | PATCH /v1/builds/{id} 返回 500 | 调用 `updateBuildEncryption` | 抛出 `AppStoreConnectClientError` | P1 | ✅ 已覆盖 | `otherFailuresStillThrow` |
| 69 | VM App 切换 | 账号切换后旧账号的 App 列表不得写入当前列表 | 已用旧账号写入一次 App 列表 | 切换 `credentials` 后用旧账号结果再次写入 | 写入被拒绝，列表仍是旧账号那次的结果 | P1 | ✅ 已覆盖 | `lateAppsFromPreviousAccountAreDiscarded` |

> 说明：全部 **69 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 16 / 16
- P1: 已覆盖 48 / 48
- P2: 已覆盖 5 / 5
- **合计: 69 / 69**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（16 条）
- **P1**: 其余功能性用例（48 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（5 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 69 条用例位于 `Tests/`，需在目标平台执行 `swift test`

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
