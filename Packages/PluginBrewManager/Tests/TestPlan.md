# TestPlan — PluginBrewManager

## 包概述

BrewManagerPlugin Homebrew package management plugin for Lumi. Provides a developer tool view for inspecting installed packages, checking updates, searching packages, and running install, uninstall, or upgrade actions through BrewKit.

平台: macOS 14+, iOS 17+
测试文件: 9 个，用例总数: 55

核心组件（源码目录）:
- `Models/`
- `Services/`
- `ViewModels/`
- `Views/`

## 公开 API

包内主要类型（按声明顺序抽取，供定位被测对象）:

- `BrewManagerPluginSupport`
- `BrewPackage`
- `BrewError`
- `BrewManagerServicing`
- `AboutView`
- `BrewManagerEmptyView`
- `BrewManagerErrorView`
- `BrewManagerManualView`
- `BrewManagerView`

## 关键行为契约（实现约定，非协议要求）

按测试模块归纳，改动对应模块时须保持既有断言成立:

- **综合**（19 条）：由 `pluginMetadataIsStable`、`decodesHomebrewFormulaAndCaskInstalledValues`、`decodesCaskInstalledStringIntoVersion` 等用例锁定；改动该模块时优先跑对应测试文件。
- **Cask 安装版本**（#212）：`brew info` 的 cask `installed` 是版本字符串（formula 是数组），`BrewPackageInfo` 解码须归一化为 `[InstalledVersion]`，不得丢弃；`listInstalled`/`getInfo` 不得用最新 `version` 冒充安装版本，且须保留 `outdated` 标记。（`getOutdated` 改用 `BrewOutdated`，见 #847。）
- **错误重试**（#330，6 条）：错误视图的「重试」必须重跑最近失败的操作（环境检测/刷新/搜索/安装/卸载/更新/批量更新），而不是仅清除 `errorMessage`；重试仍失败时错误须显式保留，不得伪装成正常空列表或「全部已最新」。由 `BrewManagerRetryTests` 锁定。
- **批量更新单飞**（#409，3 条）：连点 Update All 不得并发跑同一批包，进行中标志须挡住后续点击；唯一一轮结束后 `isLoading` 落下且标志复位，允许再次批量更新。由 `BrewManagerUpgradeAllTests` 锁定。
- **搜索配额**（#654，4 条）：`search` 的 Formula 与 Cask 须各自独立限额（各 10 个），不得用共享配额 `10 - formulaLimit.count` 让 Formula 满额时把 Cask 挤成 0、整类应用被丢弃；仅一类匹配时另一类为空仍须正常返回。由 `BrewSearchCaskQuotaTests` 锁定。
- **Formula 全名**（#655，5 条）：`listInstalled`/`getInfo` 构造 Formula 须用 `full_name ?? name` 作为身份，不得丢弃 Homebrew 已返回的 `full_name`；Tap 与 Core 同名时两者 `id` 不得碰撞，安装/更新/卸载命令须落在用户选中的 Tap 包；无 `full_name` 时回退短 `name`。`getOutdated` 的 outdated schema 无 `full_name`，`name` 本身已含 tap 前缀，直接用 `name` 即保留 Tap 身份。由 `BrewFormulaFullNameTests` 锁定。
- **输出截断**（#408，7 条）：brew 的 JSON 输出可能远超 KitShell 默认 64 KiB 上限；`runBrewCommand` 须把上限提到 16 MiB 容纳完整文档并捕获 `stdoutTruncated`，`execute` 在 exitCode==0 但 stdout 被截断时必须抛 `outputTruncated`，绝不能把残缺尾部当成功解析；未截断的完整 JSON 仍正常解析，非零退出码优先报 `commandFailed`。由 `BrewOutputTruncationTests` 锁定。
- **卸载确认**（#656，4 条）：卸载是破坏性操作，内置手册要求先确认并警告可能影响依赖包。行内 Uninstall 按钮只能调用 `requestUninstall(package:)` 登记 `packagePendingUninstall`，不得直接执行卸载；视图须用 `confirmationDialog` 展示目标包名与依赖警告，仅「卸载」确认按钮调用 `confirmUninstall(package:)` 才真正执行，取消调用 `cancelUninstall()` 清空待确认包。由 `BrewManagerUninstallConfirmationTests` 锁定；改动卸载入口或确认流程时优先跑对应测试文件。
- **Outdated 版本模型**（#847，7 条）：`getOutdated` 必须用 `BrewOutdated`（`current_version` 目标版本、`installed_versions` 数组已装版本、`name` 身份）解码 `brew outdated --json=v2`，不得复用 `brew info` 的 `BrewInfo` 去猜 `versions`/`version`，否则 Updates 页目标版本全部退化成 "unknown"；Formula 多 keg 取 `installed_versions` 首个，Cask `name` 即 token。由 `BrewOutdatedVersionTests` 锁定；改动 `getOutdated` 或 outdated 模型时优先跑该文件。

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | 综合 | pluginMetadataIsStable | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `pluginMetadataIsStable` |
| 2 | 综合 | v2IdentifiersRemainStable | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `v2IdentifiersRemainStable` |
| 3 | 综合 | decodesHomebrewFormulaAndCaskInstalledValues | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `decodesHomebrewFormulaAndCaskInstalledValues` |
| 4 | 综合 | decodesFormulaNameStringAndCaskNameArray | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `decodesFormulaNameStringAndCaskNameArray` |
| 5 | 综合 | activatingPluginHidesChatSectionAndDeactivatingRestoresIt | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `activatingPluginHidesChatSectionAndDeactivatingRestoresIt` |
| 6 | 综合 | clearingSearchIgnoresInFlightResults | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `clearingSearchIgnoresInFlightResults` |
| 7 | 综合 | editingSearchTextAfterSubmitStopsLoadingWhenStaleResultReturns | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `editingSearchTextAfterSubmitStopsLoadingWhenStaleResultReturns` |
| 8 | 综合 | BrewError 各 case 携带命令详情文案 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `brewErrorDescriptionsCarryCommandDetail` |
| 9 | 综合 | 安装失败时向用户展示命令错误详情 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `installFailureShowsCommandDetailToUser` |
| 10 | 综合 | 安装成功后同步搜索结果的安装状态 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `installSuccessReconcilesSearchResults` |
| 11 | 综合 | 卸载成功后同步搜索结果的安装状态 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `uninstallSuccessReconcilesSearchResults` |
| 12 | 综合 | cask 的字符串 installed 必须解码为安装版本，不得丢失 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `decodesCaskInstalledStringIntoVersion` |
| 13 | 综合 | cask 的 installed 为 null 时解码为未安装 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `decodesCaskInstalledNullAsNotInstalled` |
| 14 | 综合 | formula 的数组 installed 解码保持不变（无回归） | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `decodesFormulaInstalledArrayUnchanged` |
| 15 | 综合 | getInfo(cask) 必须保留真实安装版本与 outdated 状态 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `getInfoCaskPreservesInstalledVersionAndOutdated` |
| 16 | 综合 | getInfo(cask) 未安装时安装版本为 nil | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `getInfoCaskNotInstalledShowsNil` |
| 17 | 综合 | listInstalled 的 cask 不得把最新版本当作安装版本 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `listInstalledCaskUsesRealInstalledVersionNotLatest` |
| 18 | 综合 | getOutdated 的 cask 保留真实安装版本 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `getOutdatedCaskPreservesInstalledVersion` |
| 19 | 综合 | getInfo(formula) 保留 outdated 标记 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `getInfoFormulaPreservesOutdatedFlag` |
| 20 | 错误重试 | 环境缺失时重试必须再次检测环境，仍失败则保留错误 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `retryRechecksEnvironmentWhenBrewMissing` |
| 21 | 错误重试 | 环境恢复后重试检测成功并自动刷新 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `retryEnvironmentSucceedsAfterBrewInstalled` |
| 22 | 错误重试 | 刷新失败后重试必须重跑刷新并恢复列表 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `retryRerunsFailedRefresh` |
| 23 | 错误重试 | 刷新重试仍失败时错误必须显式保留 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `retryKeepsErrorWhenRefreshStillFails` |
| 24 | 错误重试 | 安装失败后重试针对同一包再次安装 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `retryRerunsFailedInstallWithSamePackage` |
| 25 | 错误重试 | 搜索失败后重试重跑搜索并返回结果 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `retryRerunsFailedSearch` |
| 26 | 批量更新单飞 | 连点 Update All 不得并发重复升级同一批包 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `concurrentUpgradeAllRunsSingleFlight` |
| 27 | 批量更新单飞 | 批量更新须升级每个可更新包 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `upgradeAllUpgradesEveryOutdatedPackage` |
| 28 | 批量更新单飞 | 上一轮结束后标志复位允许再次批量更新 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `upgradeAllCanBeRunAgainAfterCompletion` |
| 29 | 搜索配额 | Formula 满额时 Cask 不得被整类丢弃 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `casksSurviveWhenFormulaeFillQuota` |
| 30 | 搜索配额 | Formula 与 Cask 各自独立限额 10 个 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `eachCategoryIsCappedIndependently` |
| 31 | 搜索配额 | 只有 Cask 匹配时仍返回 Cask | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `caskOnlySearchReturnsCasks` |
| 32 | 搜索配额 | 只有 Formula 匹配时仍返回 Formula | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `formulaOnlySearchReturnsFormulae` |
| 33 | Formula 全名 | getInfo 的 Formula 必须保留 full_name 作为身份 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `getInfoFormulaKeepsFullName` |
| 34 | Formula 全名 | 同名 Tap 与 Core Formula 的 id 不得碰撞 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `getInfoDistinguishesTapAndCoreIds` |
| 35 | Formula 全名 | listInstalled 的 Formula 保留 full_name | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `listInstalledFormulaKeepsFullName` |
| 36 | Formula 全名 | getOutdated 的 Formula 保留 Tap 全名身份（outdated 的 name 即全名） | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `getOutdatedFormulaKeepsFullName` |
| 37 | Formula 全名 | 没有 full_name 的 Formula 回退到短 name（无回归） | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `formulaWithoutFullNameFallsBackToName` |
| 38 | 输出截断 | listInstalled 遇到截断的 stdout 必须抛 outputTruncated | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `listInstalledThrowsWhenStdoutTruncated` |
| 39 | 输出截断 | getInfo 遇到截断的 stdout 必须抛 outputTruncated | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `getInfoThrowsWhenStdoutTruncated` |
| 40 | 输出截断 | 未截断的完整 JSON 仍正常解析 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `listInstalledParsesCompleteJSONWhenNotTruncated` |
| 41 | 输出截断 | 非零退出码优先报 commandFailed，而不是截断错误 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `nonZeroExitWithTruncationThrowsCommandFailed` |
| 42 | 输出截断 | outputTruncated 暴露错误描述 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `outputTruncatedErrorHasDescription` |
| 43 | 输出截断 | runBrewCommand 保留超过旧 64 KiB 上限的完整输出 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `runBrewCommandRetainsOutputAboveLegacyLimit` |
| 44 | 输出截断 | runBrewCommand 对超过新上限的输出标记截断 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `runBrewCommandFlagsTruncationAboveLimit` |

### 卸载确认（回归 #656）

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 45 | 卸载确认 | 单击 Uninstall 只登记待确认包，不得立即执行卸载（回归 #656） | 假服务记录卸载调用 | `requestUninstall(package:)` 后让出主线程 | `packagePendingUninstall == package`，`uninstallCalls == 0` | P0 | ✅ 已覆盖 | `requestUninstallDoesNotExecuteUninstall` |
| 46 | 卸载确认 | 确认后才执行一次卸载并清空待确认包（回归 #656） | 同上 | `requestUninstall` 后 `confirmUninstall(package:)` | `uninstallCalls == 1`、`uninstalledNames == ["node"]`、待确认包为 nil | P0 | ✅ 已覆盖 | `confirmUninstallExecutesOnceAndClearsPending` |
| 47 | 卸载确认 | 取消确认不执行卸载并清空待确认包（回归 #656） | 同上 | `requestUninstall` 后 `cancelUninstall()` | 待确认包为 nil，`uninstallCalls == 0` | P0 | ✅ 已覆盖 | `cancelUninstallDoesNotExecuteUninstall` |
| 48 | 卸载确认 | 连续请求不同包时待确认包替换为最后一个，仍未执行卸载 | 同上 | 先后 `requestUninstall(node)`、`requestUninstall(wget)` | 待确认包为 wget，`uninstallCalls == 0` | P1 | ✅ 已覆盖 | `requestUninstallReplacesPendingPackage` |

### Brew Outdated 版本（回归 #847）

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 49 | Outdated 版本 | getOutdated 的 Formula 目标版本必须是 current_version，不得为 unknown | 注入真实 outdated schema 的假命令输出 | 调用 getOutdated | version == current_version、非 unknown，outdated 为真、isCask 为假 | P0 | ✅ 已覆盖 | `outdatedFormulaTargetVersionIsCurrentVersion` |
| 50 | Outdated 版本 | getOutdated 的 Cask 目标版本必须是 current_version，不得为 unknown | 同上（cask 条目） | 调用 getOutdated | version == current_version、非 unknown，isCask 为真 | P0 | ✅ 已覆盖 | `outdatedCaskTargetVersionIsCurrentVersion` |
| 51 | Outdated 版本 | getOutdated 的 Formula 已装版本取 installed_versions 首个（多 keg） | installed_versions 含两个版本 | 调用 getOutdated | installedVersion 为首个 | P1 | ✅ 已覆盖 | `outdatedFormulaInstalledVersionUsesFirstKeg` |
| 52 | Outdated 版本 | getOutdated 的 Cask 已装版本来自 installed_versions，不得丢失 | cask installed_versions 数组 | 调用 getOutdated | installedVersion 为真实已装版本 | P0 | ✅ 已覆盖 | `outdatedCaskInstalledVersionIsReal` |
| 53 | Outdated 版本 | getOutdated 的 Cask name 即 token，作为包身份 | cask name 为 token 字符串 | 调用 getOutdated | name/id 为该 token | P1 | ✅ 已覆盖 | `outdatedCaskNameIsToken` |
| 54 | Outdated 版本 | BrewOutdated 模型按真实 schema 解码 formula 与 cask | 含 pinned/pinned_version 的真实 JSON | 直接解码 BrewOutdated | name/current_version/installed_versions/pinned/pinned_version 均正确 | P1 | ✅ 已覆盖 | `outdatedModelDecodesRealSchema` |
| 55 | Outdated 版本 | getOutdated 空列表返回空数组 | formulae/casks 均为空 | 调用 getOutdated | 返回空数组 | P2 | ✅ 已覆盖 | `outdatedEmptyListsReturnNoPackages` |

> 说明：全部 **55 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。
>
> 变异验证（#330）：M1 将 `retry()` 的 `.environment` 分支改为 `break` → `retryRechecksEnvironmentWhenBrewMissing`、`retryEnvironmentSucceedsAfterBrewInstalled` 转红；M2 将 `.refresh` 分支改为 `break` → `retryRerunsFailedRefresh`、`retryKeepsErrorWhenRefreshStillFails` 转红；M3 删除安装失败处的 `lastFailedOperation = .install(package)` → `retryRerunsFailedInstallWithSamePackage` 转红。三处变异均单独施加并确认转红后还原，最终 25 条全绿。
>
> 变异验证（#409）：M1 删除 `upgradeAll()` 开头的 `guard !isUpgradingAll else { return }` → `concurrentUpgradeAllRunsSingleFlight` 转红（连点跑两轮，upgradeCalls=4）；M2 删除 `defer { isUpgradingAll = false }` → `upgradeAllCanBeRunAgainAfterCompletion` 转红（标志不复位，第二轮被挡，upgradeCalls=2）。两处变异均单独施加并确认转红后还原，最终 28 条全绿。
>
> 变异验证（#654）：M1 将 Cask 配额还原为共享 `caskNames.prefix(max(0, 10 - formulaLimit.count))` → `casksSurviveWhenFormulaeFillQuota`、`eachCategoryIsCappedIndependently` 转红（Formula 满 10 时 Cask 归零）；M2 将 Cask 限额改为 `prefix(5)` → `eachCategoryIsCappedIndependently` 转红（Cask 仅 5 个）；M3 将 Formula 限额改为 `prefix(20)` → `eachCategoryIsCappedIndependently`、`formulaOnlySearchReturnsFormulae`、`casksSurviveWhenFormulaeFillQuota` 转红（Formula 超过 10）。三处变异均单独施加并确认转红后还原，最终 32 条全绿。
>
> 变异验证（#655）：M1 将 `getInfo` 的 Formula 构造还原为 `f.name` → `getInfoFormulaKeepsFullName`、`getInfoDistinguishesTapAndCoreIds` 转红（full_name 丢失、id 碰撞）；M2 将 `listInstalled` 还原为 `f.name` → `listInstalledFormulaKeepsFullName` 转红；M3 将 `getOutdated` 还原为 `f.name` → `getOutdatedFormulaKeepsFullName` 转红。三处变异均单独施加并确认转红后还原，最终 37 条全绿。
>
> 变异验证（#408）：M1 删除 `execute` 中 `if result.stdoutTruncated { throw .outputTruncated }` 守卫 → `listInstalledThrowsWhenStdoutTruncated` 转红（残缺尾部被当 JSON 解析，抛 parsingError 而非 outputTruncated）；M2 将 `maxOutputBytes` 还原为 `64 * 1024` → `runBrewCommandRetainsOutputAboveLegacyLimit` 转红（200 KiB 输出被截成 64 KiB 尾部）；M3 将守卫改为 `if true` → `listInstalledParsesCompleteJSONWhenNotTruncated` 转红（完整 JSON 也被误判截断）；M4 将 `runBrewCommand` 的 `stdoutTruncated: result.stdoutTruncated` 改为 `false` → `runBrewCommandFlagsTruncationAboveLimit` 转红（超 16 MiB 仍不标记截断）。四处变异均单独施加并确认转红后还原，最终 44 条全绿。
>
> 变异验证（#656）：行内 Uninstall 原先直接 `Task { await viewModel.uninstall(package:) }`，单击即执行破坏性卸载。修复为 `requestUninstall` 只登记 `packagePendingUninstall`，视图经 `confirmationDialog` 确认后由 `confirmUninstall(package:)` 才调用服务。M1 让 `requestUninstall` 重新派发 `Task { await uninstall(package:) }`（原 bug）→ `requestUninstallDoesNotExecuteUninstall` 转红（让出主线程后 uninstallCalls≠0）、`confirmUninstallExecutesOnceAndClearsPending` 转红（请求与确认各卸载一次，共 2 次）。变异施加并确认转红后还原，最终 48 条全绿。
>
> 变异验证（#847）：M1 将 `getOutdated` 的 Formula `version: f.current_version` 改回 `"unknown"`（原 bug）→ `outdatedFormulaTargetVersionIsCurrentVersion` 转红；M2 将 Cask `version: c.current_version` 改回 `"unknown"` → `outdatedCaskTargetVersionIsCurrentVersion`、`getOutdatedCaskPreservesInstalledVersion` 转红；M3 将 Formula `installed_versions.first` 改为 `.last` → `outdatedFormulaInstalledVersionUsesFirstKeg` 转红；M4 将 Cask `installed_versions.first` 改为 `nil` → `outdatedCaskInstalledVersionIsReal`、`getOutdatedCaskPreservesInstalledVersion` 转红；M5 将 Cask `name: c.name` 改为 `"cask"` → `outdatedCaskNameIsToken` 转红。五处变异均单独施加并确认转红后还原，最终 55 条全绿。
>
> #847 同时校正两条既有 `getOutdated` 用例的 fixture：原 `getOutdatedCaskPreservesInstalledVersion`/`getOutdatedFormulaKeepsFullName` 用的是 `brew info` 形状（cask `name` 数组 + `token` + `version` + `installed` 字符串、formula `full_name` + `versions`），与 `brew outdated --json=v2` 真实 schema 不符，等于把 bug 固化进测试；现改为真实 outdated schema（`name` 字符串、`installed_versions` 数组、`current_version`），断言契约（保留真实安装版本、保留 Tap 身份）不变。

## 覆盖率统计

- P0: 已覆盖 22 / 22
- P1: 已覆盖 29 / 29
- P2: 已覆盖 4 / 4
- **合计: 55 / 55**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（22 条）
- **P1**: 其余功能性用例（29 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（4 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 55 条用例位于 `Tests/`，需在目标平台执行 `swift test`

## 测试执行

```bash
cd Packages/PluginBrewManager
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例，再写实现
2. **Bug 修复** → 追加回归用例，标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan，标记 ✅ 并填写测试方法名
5. **改名同步** → 重命名 `@Test` 函数后必须同步本表，否则 `Scripts/verify-testplan.py` 会报「登记方法在源码不存在」
