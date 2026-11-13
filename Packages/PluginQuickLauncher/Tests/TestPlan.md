# TestPlan — PluginQuickLauncher

## 包概述

QuickLauncherPlugin Quick launcher plugin for Lumi.

平台: macOS 14+, iOS 17+
测试文件: 1 个，用例总数: 22

核心组件（源码目录）:
- `Observers/`
- `Services/`
- `ViewModels/`
- `Views/`

## 公开 API

包内主要类型（按声明顺序抽取，供定位被测对象）:

- `QuickLauncherPluginSupport`
- `SpotlightGatheringObserver`
- `LauncherAppItem`
- `LauncherFileItem`
- `HotkeyCombo`
- `LauncherCommandItem`
- `QuickLauncherSettingsViewModel`
- `LauncherSettingsView`
- `LauncherView`
- `LauncherPanel`
- `QuickLauncherAboutView`
- `QuickLauncherManualView`

## 关键行为契约（实现约定，非协议要求）

按测试模块归纳，改动对应模块时须保持既有断言成立:

- **综合**（20 条）：由 `hotkeyDefaultCombo`、`hotkeyComboFromEventModifiers`、`hotkeyComboShiftOnlyIsNotFunctionModifier` 等用例锁定；改动该模块时优先跑对应测试文件。
- **应用结果身份**（2 条）：由 `sameBundleIDAppsGetDistinctResultIDs`、`clickingSecondCopyResolvesToItsOwnPath` 锁定（**回归 #300**）：同一 Bundle ID 的多份应用副本（不同路径）必须有唯一的结果身份（`app:\(path)`），SwiftUI 行身份不得碰撞，按结果 ID 反查（`flattenedIndex`）必须落到对应副本自身，点击第二份不得启动第一份。改动 `LauncherResult(app:)` 身份构造或点击反查逻辑时优先跑对应用例。
- **应用扫描根目录**（2 条）：由 `searchDirectoriesIncludeUtilitiesRoots`、`productionRootsDiscoverUtilitiesApp` 锁定（**回归 #299**）：扫描只取各根目录的直接 `.app` 子项、不递归，因此 `/System/Applications/Utilities` 与 `/Applications/Utilities` 必须显式列为扫描根，否则 Terminal/Activity Monitor/Console 等系统自带应用永远扫不到；既有标准根不得丢失。改动 `AppSearchService.searchDirectories` 或 `scanDirectories` 枚举逻辑时优先跑对应用例。

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | 综合 | hotkeyDefaultCombo | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `hotkeyDefaultCombo` |
| 2 | 综合 | hotkeyComboFromEventModifiers | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `hotkeyComboFromEventModifiers` |
| 3 | 综合 | hotkeyComboShiftOnlyIsNotFunctionModifier | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `hotkeyComboShiftOnlyIsNotFunctionModifier` |
| 4 | 综合 | fuzzyMatchBasics | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `fuzzyMatchBasics` |
| 5 | 综合 | appSearchFiltersByName | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `appSearchFiltersByName` |
| 6 | 综合 | launcherResultIDsAreDistinctPerKind | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `launcherResultIDsAreDistinctPerKind` |
| 7 | 综合 | searchModelAIPrefix | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `searchModelAIPrefix` |
| 8 | 综合 | commandSearchUsesKernelAgnosticBridge | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `commandSearchUsesKernelAgnosticBridge` |
| 9 | 综合 | v2PluginPreservesLauncherIdentityAndPolicy | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `v2PluginPreservesLauncherIdentityAndPolicy` |
| 10 | 综合 | 文件打开失败时执行返回 false 并记录错误文案，面板不应关闭 | 注入返回 false 的打开实现 + 一条文件结果 | 调用 `LauncherSearchModel.execute(at:)` | 返回 false，`executionError` 包含文件名 | P0 | ✅ 已覆盖 | `fileOpenFailureIsReportedAndDoesNotCountAsSuccess` |
| 11 | 综合 | 文件打开成功时返回 true、清空错误并按原始路径打开 | 注入返回 true 的打开实现 + 一条文件结果 | 调用 `LauncherSearchModel.execute(at:)` | 返回 true，`executionError` 为 nil，打开 URL 与结果路径一致 | P0 | ✅ 已覆盖 | `fileOpenSuccessUsesExactPathAndAllowsDismiss` |
| 12 | 综合 | 异步文件结果插入后仍选中原条目 | 查询命中应用+命令，选中命令后文件结果插入到中间 | 调用 `rebuildResults()` | `selectedIndex` 指向同一条命令，而非同下标的文件 | P0 | ✅ 已覆盖 | `asyncFileResultsPreserveSelectedItemIdentity` |
| 13 | 综合 | 选中项消失时按既有规则钳制下标 | 两条文件结果，选中最后一条 | 清空文件结果后 `rebuildResults()` | 结果为空且 `selectedIndex` 归 0 | P1 | ✅ 已覆盖 | `disappearingSelectionFallsBackToClampedIndex` |
| 14 | 综合 | 检索达到上限即停止，不对全量集合匹配后截断（**回归 #1218**） | 10 个同前缀应用 | `searchItems(matching:limit:3)` | 返回 3 条且为注册顺序前缀 | P1 | ✅ 已覆盖 | `appSearchStopsOnceLimitIsReached` |
| 15 | 综合 | 全部命中时仍按 limit 截断结果 | 3 个均模糊命中查询的应用 | `searchItems(matching:limit:2)` | 返回 2 条 | P1 | ✅ 已覆盖 | `appSearchRespectsLimitForFullMatchSet` |
| 16 | 综合 | 聚合结果按分组上限截断应用与命令 | 20 个应用 + 20 个命令均命中 | 设置 query 后读取 `results` | 应用与命令分别不超过 appLimit/commandLimit | P1 | ✅ 已覆盖 | `launcherModelCapsAppAndCommandResults` |
| 17 | 综合 | 命令来源变化后索引失效并反映新内容 | 命令组 Provider 先 v1 后 v2 | 更换 Provider 后 `rebuildResults()` | 结果含新命令、不含旧命令 | P1 | ✅ 已覆盖 | `commandIndexRebuildsWhenProviderChanges` |
| 18 | 综合 | 命令执行运行缓存索引中的原始条目 | 一条带可执行闭包的命令 | `execute(at:)` | 返回 true 且闭包被执行 | P1 | ✅ 已覆盖 | `commandExecutionRunsCachedIndexEntry` |
| 19 | 应用结果身份 | 同 Bundle ID 的多份副本结果身份必须唯一，不得碰撞（**回归 #300**） | 两个同 Bundle ID、不同路径的应用条目 | 分别构造 `LauncherResult(app:)` | 两者 id 不同且各含自身路径，app.path 各自保留 | P0 | ✅ 已覆盖 | `sameBundleIDAppsGetDistinctResultIDs` |
| 20 | 应用结果身份 | 按结果 ID 反查必须落到对应副本，点击第二份不得启动第一份（**回归 #300**） | 注入两个同 Bundle ID、不同路径的应用并查询 | 取第二份结果按 id 反查下标（复刻 flattenedIndex） | 反查下标指向第二份副本自身路径 | P0 | ✅ 已覆盖 | `clickingSecondCopyResolvesToItsOwnPath` |
| 21 | 应用扫描根目录 | 扫描根必须显式包含 Utilities 子目录，且既有标准根不得丢失（**回归 #299**） | 读取 `AppSearchService.searchDirectories` | 断言根列表内容 | 含 `/System/Applications/Utilities` 与 `/Applications/Utilities`，且仍含 `/Applications`、`/System/Applications` | P0 | ✅ 已覆盖 | `searchDirectoriesIncludeUtilitiesRoots` |
| 22 | 应用扫描根目录 | 生产扫描根重定位到临时目录后能发现 Utilities 中的 Terminal（非递归扫描，**回归 #299**） | 临时 base 下镜像 `System/Applications/Utilities/Terminal.app`（含 Info.plist） | 把生产根整体重定位到 base 后调用 `scanDirectories` | 结果含该 Terminal.app，name 为 Terminal、bundleId 为 com.apple.Terminal | P1 | ✅ 已覆盖 | `productionRootsDiscoverUtilitiesApp` |

> 说明：全部 **22 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 6 / 6
- P1: 已覆盖 15 / 15
- P2: 已覆盖 1 / 1
- **合计: 22 / 22**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（6 条）
- **P1**: 其余功能性用例（15 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（1 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 22 条用例位于 `Tests/`，需在目标平台执行 `swift test`

## 测试执行

```bash
cd Packages/PluginQuickLauncher
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例，再写实现
2. **Bug 修复** → 追加回归用例，标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan，标记 ✅ 并填写测试方法名
5. **改名同步** → 重命名 `@Test` 函数后必须同步本表，否则 `Scripts/verify-testplan.py` 会报「登记方法在源码不存在」
