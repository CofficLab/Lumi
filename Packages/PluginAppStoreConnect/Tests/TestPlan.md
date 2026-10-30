# TestPlan — PluginAppStoreConnect

## 包概述

PluginAppStoreConnect Current `KernelCore` implementation of the App Store Connect integration. - Product/module: `PluginAppStoreConnect` - Plugin id: `com.coffic.lumi.plugin.app-store-connect` - Rail tab: `app-store-connect.sidebar` - Enable policy: disabled by default The plugin provides App Store Connect account, app/version, localization, screenshot, release, and Xcode Cloud management through the workbench and the `app_store_connect_*` Agent tools.

平台: macOS 14+, iOS 17+
测试文件: 4 个，用例总数: 26

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

> 说明：全部 **26 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 2 / 2
- P1: 已覆盖 22 / 22
- P2: 已覆盖 2 / 2
- **合计: 26 / 26**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（2 条）
- **P1**: 其余功能性用例（22 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（2 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 26 条用例位于 `Tests/`，需在目标平台执行 `swift test`

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
