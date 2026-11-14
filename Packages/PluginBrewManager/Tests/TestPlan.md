# TestPlan — PluginBrewManager

## 包概述

BrewManagerPlugin Homebrew package management plugin for Lumi. Provides a developer tool view for inspecting installed packages, checking updates, searching packages, and running install, uninstall, or upgrade actions through BrewKit.

平台: macOS 14+, iOS 17+
测试文件: 3 个，用例总数: 25

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
- **Cask 安装版本**（#212）：Homebrew cask 的 `installed` 是版本字符串（formula 是数组），解码须归一化为 `[InstalledVersion]`，不得丢弃；`listInstalled`/`getOutdated`/`getInfo` 不得用最新 `version` 冒充安装版本，且须保留 `outdated` 标记。
- **错误重试**（#330，6 条）：错误视图的「重试」必须重跑最近失败的操作（环境检测/刷新/搜索/安装/卸载/更新/批量更新），而不是仅清除 `errorMessage`；重试仍失败时错误须显式保留，不得伪装成正常空列表或「全部已最新」。由 `BrewManagerRetryTests` 锁定。

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

> 说明：全部 **25 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。
>
> 变异验证（#330）：M1 将 `retry()` 的 `.environment` 分支改为 `break` → `retryRechecksEnvironmentWhenBrewMissing`、`retryEnvironmentSucceedsAfterBrewInstalled` 转红；M2 将 `.refresh` 分支改为 `break` → `retryRerunsFailedRefresh`、`retryKeepsErrorWhenRefreshStillFails` 转红；M3 删除安装失败处的 `lastFailedOperation = .install(package)` → `retryRerunsFailedInstallWithSamePackage` 转红。三处变异均单独施加并确认转红后还原，最终 25 条全绿。

## 覆盖率统计

- P0: 已覆盖 7 / 7
- P1: 已覆盖 16 / 16
- P2: 已覆盖 2 / 2
- **合计: 25 / 25**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（7 条）
- **P1**: 其余功能性用例（16 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（2 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 25 条用例位于 `Tests/`，需在目标平台执行 `swift test`

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
