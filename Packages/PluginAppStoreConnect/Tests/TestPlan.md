# TestPlan — PluginAppStoreConnect

## 包概述

PluginAppStoreConnect Current `KernelCore` implementation of the App Store Connect integration. - Product/module: `PluginAppStoreConnect` - Plugin id: `com.coffic.lumi.plugin.app-store-connect` - Rail tab: `app-store-connect.sidebar` - Enable policy: disabled by default The plugin provides App Store Connect account, app/version, localization, screenshot, release, and Xcode Cloud management through the workbench and the `app_store_connect_*` Agent tools.

平台: macOS 14+, iOS 17+
测试文件: 3 个，用例总数: 13

核心组件（源码目录）:
- `Sources/`

## 公开 API

包内主要类型（按声明顺序抽取，供定位被测对象）:

- `AppStoreConnectLocalization`
- `AppStoreConnectPlugin`
- `AppStoreConnectRuleContributor`
- `AppStoreConnectSkillContributor`
- `AppStoreApp`
- `AppStoreConnectListResponse`
- `AppStoreConnectCredentials`
- `ScreenshotSet`
- `VersionCreateValidationError`
- `AppStoreVersion`
- `AppStoreVersionLocalization`
- `CiProduct`
- `ConnectBuild`
- `ExportComplianceChoice`

## 关键行为契约（实现约定，非协议要求）

按测试模块归纳，改动对应模块时须保持既有断言成立:

- **AppStoreConnectPlugin**（9 条）：由 `pluginMetadata`、`settingsEntry`、`activationKeepsChatToolbarCategoryVisible` 等用例锁定；改动该模块时优先跑对应测试文件。
- **AppStoreConnectRuleContributor**（1 条）：由 `loadsReleaseSafetyRuleFromResource` 等用例锁定；改动该模块时优先跑对应测试文件。
- **VMBusy**（3 条）：由 `nestedRunBusyIsReentrant`、`fastOperationSkipsOverlay`、`slowOperationShowsOverlay` 等用例锁定；改动该模块时优先跑对应测试文件。

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | AppStoreConnectPlugin | plugin metadata follows the current integration conventions | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `pluginMetadata` |
| 2 | AppStoreConnectPlugin | plugin contributes its API configuration to Settings | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `settingsEntry` |
| 3 | AppStoreConnectPlugin | activating the plugin keeps chat toolbar items visible | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `activationKeepsChatToolbarCategoryVisible` |
| 4 | AppStoreConnectPlugin | plugin loads its App Store Connect skill from bundled resources | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `appStoreConnectSkill` |
| 5 | AppStoreConnectPlugin | all restored agent tools use unique current names | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `toolNamesUseCurrentConvention` |
| 6 | AppStoreConnectPlugin | schemas expose object roots | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `toolSchemasAreObjects` |
| 7 | AppStoreConnectPlugin | delete version tool is a high-risk single-id operation | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `deleteVersionToolShape` |
| 8 | AppStoreConnectPlugin | update version exposes earliestReleaseDate alongside existing fields | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `updateVersionSchemaIncludesEarliestReleaseDate` |
| 9 | AppStoreConnectPlugin | credentials require all App Store Connect signing fields | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `credentialsCompleteness` |
| 10 | AppStoreConnectRuleContributor | App Store Connect 插件从 Markdown 资源贡献 Agent Rule | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `loadsReleaseSafetyRuleFromResource` |
| 11 | VMBusy | nested runBusy keeps one continuous loading overlay | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `nestedRunBusyIsReentrant` |
| 12 | VMBusy | a fast operation never shows the overlay | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `fastOperationSkipsOverlay` |
| 13 | VMBusy | a slow operation shows and then hides the overlay | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `slowOperationShowsOverlay` |

> 说明：全部 **13 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 1 / 1
- P1: 已覆盖 12 / 12
- P2: 已覆盖 0 / 0
- **合计: 13 / 13**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（1 条）
- **P1**: 其余功能性用例（12 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（0 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 13 条用例位于 `Tests/`，需在目标平台执行 `swift test`

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
