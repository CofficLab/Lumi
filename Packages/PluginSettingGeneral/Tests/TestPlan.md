# TestPlan — PluginSettingGeneral

## 包概述

PluginSettingGeneral 的实现包，包含 14 个主要类型；当前测试覆盖 29 条用例。

平台: macOS 14+, iOS 17+
测试文件: 6 个，用例总数: 29

核心组件（源码目录）:
- `Capabilities/`
- `Observers/`
- `Support/`
- `ViewModels/`
- `Views/`

## 公开 API

包内主要类型（按声明顺序抽取，供定位被测对象）:

- `AppVersion`
- `SettingGeneralPlugin`
- `CapabilityError`
- `GeneralSettingsCapabilityError`
- `GeneralSettingsDiagnosticsCapability`
- `GeneralSettingsDocsCapability`
- `GeneralSettingsStorageCapability`
- `GeneralSettingsUninstallCapability`
- `GeneralSettingsUpdateChannelCapability`
- `GeneralSettingsObserver`
- `CLIInstallViewModel`
- `GeneralSettingsViewModel`
- `CLIInstallDetailView`
- `GeneralSettingsDetailView`

## 关键行为契约（实现约定，非协议要求）

按测试模块归纳，改动对应模块时须保持既有断言成立:

- **CLIInstallViewModel**（10 条）：由 `initialStatusIsNotInstalled`、`installedStatusWhenOnPath`、`installedNotOnPathStatusCarriesDirectory` 等用例锁定；改动该模块时优先跑对应测试文件。
- **GeneralSettingsCLISection**（2 条）：由 `generalSettingsRendersCLISection`、`clisectionWorksWithoutOptionalProviders` 等用例锁定；改动该模块时优先跑对应测试文件。
- **综合**（5 条）：由 `onBootRegistersGeneralEntry`、`onBootAppendsToExistingEntries`、`onBootNoOpsWithoutSettingView` 等用例锁定；改动该模块时优先跑对应测试文件。
- **UninstallSummary**（5 条）：由 `defaultsKeepEveryTarget`、`bothTogglesOffLeavesOnlyOwnedData`、`everythingExcludedYieldsEmptySummary` 等用例锁定；改动该模块时优先跑对应测试文件。
- **卸载扫描代次**（4 条）：由 `staleScanCannotOverwriteNewerResult`、`staleScanCannotClearNewerLoadingState`、`cancellingInvalidatesInFlightScan` 等用例锁定；改动卸载扫描生命周期时优先跑对应测试文件。

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | CLIInstallViewModel | 未安装时状态为 notInstalled | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `initialStatusIsNotInstalled` |
| 2 | CLIInstallViewModel | 已安装且在 PATH 中时状态为 installed | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `installedStatusWhenOnPath` |
| 3 | CLIInstallViewModel | 已安装但不在 PATH 中时状态带目录提示 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `installedNotOnPathStatusCarriesDirectory` |
| 4 | CLIInstallViewModel | 状态检查完成前处于 checking 状态 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `statusIsCheckingWhileResolving` |
| 5 | CLIInstallViewModel | install 成功后刷新为已安装状态 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `installSucceedsThenRefreshesStatus` |
| 6 | CLIInstallViewModel | 安装失败时记录错误且不改变安装状态 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `installFailureRecordsError` |
| 7 | CLIInstallViewModel | 安装到不在 PATH 的目录时仍算已安装 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `installButNotOnPathStillInstalled` |
| 8 | CLIInstallViewModel | uninstall 成功后刷新为未安装状态 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `uninstallSucceedsThenRefreshesStatus` |
| 9 | CLIInstallViewModel | 卸载失败时记录错误 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `uninstallFailureRecordsError` |
| 10 | CLIInstallViewModel | 忙碌标志在操作结束后复位 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `busyFlagResetsAfterOperation` |
| 11 | GeneralSettingsCLISection | 通用设置详情视图可渲染命令行工具分区 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `generalSettingsRendersCLISection` |
| 12 | GeneralSettingsCLISection | 命令行工具分区不要求内核 Provider 即可工作 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `clisectionWorksWithoutOptionalProviders` |
| 13 | 综合 | onBoot 在设置视图中注册「通用」入口 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `onBootRegistersGeneralEntry` |
| 14 | 综合 | onBoot 追加语义不覆盖已有入口 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `onBootAppendsToExistingEntries` |
| 15 | 综合 | 设置视图未注册时 onBoot 优雅降级 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `onBootNoOpsWithoutSettingView` |
| 16 | 综合 | 插件可经 kernel.start 启动并注册入口 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `startViaKernelBootsPlugin` |
| 17 | 综合 | AppVersion 可从 Info.plist 读取或返回 nil | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `appVersionReadsBundle` |
| 18 | 诊断导出 | 覆盖失败时保留原有文件（**回归 #997**） | 目标位置已有旧 zip，源 archive 不可读导致复制失败 | 调用 `installDiagnosticsArchive` | 抛错且目标内容不变，目录中无临时/备份残留 | P0 | ✅ 已覆盖 | `failedOverwriteKeepsExistingFile` |
| 19 | 诊断导出 | 覆盖成功替换目标且不留残留 | 目标位置已有旧 zip | 调用 `installDiagnosticsArchive` | 目标内容更新，目录中只剩目标文件 | P1 | ✅ 已覆盖 | `successfulOverwriteReplacesDestinationWithoutLeftovers` |
| 20 | 诊断导出 | 目标不存在时直接安装 | 目标路径为空 | 调用 `installDiagnosticsArchive` | 目标出现且内容正确 | P1 | ✅ 已覆盖 | `installsIntoEmptyDestination` |
| 21 | UninstallSummary | 两个开关都打开时保留全部扫描结果 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `defaultsKeepEveryTarget` |
| 22 | UninstallSummary | 关闭应用开关后不再计入应用及其体积（**回归 #1072**） | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `applicationToggleOffExcludesApplication` |
| 23 | UninstallSummary | 关闭凭据开关后不再计入 Keychain 项目 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `keychainToggleOffExcludesCredentials` |
| 24 | UninstallSummary | 两个开关都关闭时只保留总会清理的 Lumi 数据 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `bothTogglesOffLeavesOnlyOwnedData` |
| 25 | UninstallSummary | 扫描结果全部被排除时汇总为空 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `everythingExcludedYieldsEmptySummary` |
| 26 | 卸载扫描代次 | 回归 #1070：取消并重开弹窗后，旧扫描晚到不能覆盖新扫描结果 | 用手动完成的两轮扫描控制返回顺序 | A 取消后开始 B，B 先完成，再让 A 完成 | 结果保持为 B | P0 | ✅ 已覆盖 | `staleScanCannotOverwriteNewerResult` |
| 27 | 卸载扫描代次 | 回归 #1070：旧扫描先完成不得提前解除新扫描的加载态 | A 取消后开始 B，A 先返回 | 检查 `isScanningUninstall` | B 未完成时仍为 true，结果为空 | P0 | ✅ 已覆盖 | `staleScanCannotClearNewerLoadingState` |
| 28 | 卸载扫描代次 | 取消弹窗使在途扫描失效并复位加载态 | A 正在扫描 | 调用 `cancelUninstallScan()` 后再完成 A | 加载态为 false，结果保持 nil | P1 | ✅ 已覆盖 | `cancellingInvalidatesInFlightScan` |
| 29 | 卸载扫描代次 | 重新打开弹窗会重新扫描并展示最新结果 | 上一轮已取消 | 再次 `beginUninstall()` 并完成 B | 扫描期间加载态为 true、结果 nil；完成后展示 B | P1 | ✅ 已覆盖 | `reopeningStartsFreshScan` |

> 说明：全部 **29 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 3 / 3
- P1: 已覆盖 25 / 25
- P2: 已覆盖 1 / 1
- **合计: 29 / 29**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（3 条）
- **P1**: 其余功能性用例（25 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（1 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 29 条用例位于 `Tests/`，需在目标平台执行 `swift test`

## 测试执行

```bash
cd Packages/PluginSettingGeneral
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例，再写实现
2. **Bug 修复** → 追加回归用例，标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan，标记 ✅ 并填写测试方法名
5. **改名同步** → 重命名 `@Test` 函数后必须同步本表，否则 `Scripts/verify-testplan.py` 会报「登记方法在源码不存在」
