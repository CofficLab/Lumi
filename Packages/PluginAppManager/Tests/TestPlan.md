# TestPlan — PluginAppManager

## 包概述

AppManagerPlugin Manage installed applications for Lumi.

平台: macOS 14+, iOS 17+
测试文件: 1 个，用例总数: 19

核心组件（源码目录）:
- `Models/`
- `Services/`
- `ViewModels/`
- `Views/`

## 公开 API

包内主要类型（按声明顺序抽取，供定位被测对象）:

- `AppManagerPluginSupport`
- `PluginAppManagerLocalization`
- `AppCacheItem`
- `AppModel`
- `RelatedFile`
- `AppCleanerHelper`
- `AppService`
- `CacheStats`
- `AppManagerServicing`
- `ActionBar`
- `AppManagerAboutView`
- `AppManagerDetailView`
- `AppManagerManualView`
- `AppManagerScanningView`

## 关键行为契约（实现约定，非协议要求）

按测试模块归纳，改动对应模块时须保持既有断言成立:

- **综合**（13 条）：由 `v2PluginStateIsStable`、`activatingPluginHidesChatSectionAndDeactivatingRestoresIt`、`localizationCatalogIsPackaged` 等用例锁定；改动该模块时优先跑对应测试文件。其中关联文件扫描的路径穿越防护（`untrustedBundleNameCannotEscapeApplicationSupport`、`emptyBundleNameDoesNotSelectApplicationSupportRoot`、`pathContainmentRejectsEscapesAndDirectoryItself`、`untrustedBundleIdentifierCannotEscapeLibrary`、`validBundleIdentifierStillMatchesLibraryFiles`）要求：CFBundleName 与 CFBundleIdentifier 都必须是安全单路径分量（`AppModel.isValidPathComponent`），且每个候选路径 standardized 后仍位于对应 Library 子目录内（`AppService.isContained`），越界条目不得返回或删除；合法 Bundle ID 仍须正常命中（**回归 #211**）。
- **卸载归属保护**（4 条）：由 `nameOnlySupportMatchIsNotOwnershipVerified`、`bundleIdSupportMatchIsOwnershipVerified`、`defaultSelectionExcludesUnverifiedNameOnlyMatch`、`defaultSelectionIncludesVerifiedBundleIdMatch` 锁定（**回归 #647**）：仅凭 `CFBundleName` 同名匹配到的 Application Support 目录无法证明归属，`RelatedFile.ownershipVerified` 须为 false，卸载默认勾选不得包含它（避免误删其它厂商数据）；精确 Bundle ID 命中的目录归属确认（true）且仍须默认勾选；App 本体始终确认。改动 `AppService.scanRelatedFiles` 策略 B、`RelatedFile.ownershipVerified` 或 `AppManagerViewModel.scanRelatedFiles` 的默认勾选时优先跑对应测试。
- **无 Bundle ID 仍可卸载**（2 条）：由 `nilBundleIdentifierStillListsAppItselfForUninstall`、`nilBundleIdentifierAppIsSelectedForUninstallByDefault` 锁定（**回归 #794**）：`AppService.scanRelatedFiles` 必须先加入 App 本体再判断 Bundle ID；缺少 Bundle ID 时跳过依赖标识符的 Library 扫描，但仍须返回 App 本体（`type == .app`、`ownershipVerified == true`），使 `AppManagerViewModel` 默认勾选包含它、卸载入口可用（此前早返回 `[]` 导致无 Bundle ID 的应用无法卸载）。改动 `scanRelatedFiles` 的早返回分支或默认勾选时优先跑对应测试。

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | 综合 | v2PluginStateIsStable | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `v2PluginStateIsStable` |
| 2 | 综合 | activatingPluginHidesChatSectionAndDeactivatingRestoresIt | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `activatingPluginHidesChatSectionAndDeactivatingRestoresIt` |
| 3 | 综合 | localizationCatalogIsPackaged | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `localizationCatalogIsPackaged` |
| 4 | 综合 | directoryURLSupportsSpacesAndSpecialCharacters | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `directoryURLSupportsSpacesAndSpecialCharacters` |
| 5 | 综合 | appCleanerReturnsNoRelatedFilesWhenLibraryDirectoryIsUnavailable | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `appCleanerReturnsNoRelatedFilesWhenLibraryDirectoryIsUnavailable` |
| 6 | 综合 | cacheStoreRecoversWhenDatabaseDirectoryIsBlocked | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `cacheStoreRecoversWhenDatabaseDirectoryIsBlocked` |
| 7 | 综合 | cacheManagerReportsPersistenceResults | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `cacheManagerReportsPersistenceResults` |
| 8 | 综合 | cancelledScanDoesNotClearLoadingForNewerScan | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `cancelledScanDoesNotClearLoadingForNewerScan` |
| 9 | 综合 | untrustedBundleNameCannotEscapeApplicationSupport | 临时 home，恶意 CFBundleName 含 `../` | 扫描关联文件 | 不返回 Application Support 之外的路径 | P0 | ✅ 已覆盖 | `untrustedBundleNameCannotEscapeApplicationSupport` |
| 10 | 综合 | emptyBundleNameDoesNotSelectApplicationSupportRoot | 临时 home，CFBundleName 为空 | 扫描关联文件 | 不返回 Application Support 根目录 | P0 | ✅ 已覆盖 | `emptyBundleNameDoesNotSelectApplicationSupportRoot` |
| 11 | 综合 | pathContainmentRejectsEscapesAndDirectoryItself | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `pathContainmentRejectsEscapesAndDirectoryItself` |
| 12 | 综合 | untrustedBundleIdentifierCannotEscapeLibrary（**回归 #211**） | 临时 home，恶意 CFBundleIdentifier 含 `../`，Documents 下放置目录/plist/savedState 无辜目标 | 扫描关联文件 | 不返回任何 Documents 路径，无辜目标不被删除 | P0 | ✅ 已覆盖 | `untrustedBundleIdentifierCannotEscapeLibrary` |
| 13 | 综合 | validBundleIdentifierStillMatchesLibraryFiles（**回归 #211**） | 临时 home，合法 CFBundleIdentifier `com.example.app` | 扫描关联文件 | 仍命中 Application Support 目录、Preferences plist、Saved State | P1 | ✅ 已覆盖 | `validBundleIdentifierStillMatchesLibraryFiles` |

### 卸载归属保护（回归 #647）

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 14 | 卸载归属保护 | 仅同名匹配的 Application Support 目录归属未确认（回归 #647） | 厂商 A 无精确 Bundle ID 目录，存在它厂商同名 `Notes` 目录 | 扫描厂商 A 关联文件 | 同名目录仍列出但 ownershipVerified=false，App 本体为 true | P0 | ✅ 已覆盖 | `nameOnlySupportMatchIsNotOwnershipVerified` |
| 15 | 卸载归属保护 | 精确 Bundle ID 命中的目录归属确认（回归 #647） | 存在 `com.vendor-b.notes` 精确目录与同名 `Notes` 目录 | 扫描厂商 B 关联文件 | 精确目录 ownershipVerified=true，同名目录不再作为关联文件 | P1 | ✅ 已覆盖 | `bundleIdSupportMatchIsOwnershipVerified` |
| 16 | 卸载归属保护 | 默认勾选排除未确认归属的同名目录（回归 #647） | 同 14，注入临时 home 的 AppService | ViewModel 扫描关联文件 | 默认勾选不含同名目录，但含 App 本体 | P0 | ✅ 已覆盖 | `defaultSelectionExcludesUnverifiedNameOnlyMatch` |
| 17 | 卸载归属保护 | 默认勾选仍包含归属确认的精确匹配（回归 #647） | 存在精确 Bundle ID 目录 | ViewModel 扫描关联文件 | 精确匹配目录被默认勾选，过滤不误伤合法关联文件 | P1 | ✅ 已覆盖 | `defaultSelectionIncludesVerifiedBundleIdMatch` |

### 无 Bundle ID 仍可卸载（回归 #794）

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 18 | 无 Bundle ID 卸载 | 无 Bundle ID 仍列出 App 本体（回归 #794） | 临时 home，Info.plist 缺少 CFBundleIdentifier 的应用 | 扫描关联文件 | 必须返回 App 本体（type=.app，ownershipVerified=true），且仅 1 条 | P0 | ✅ 已覆盖 | `nilBundleIdentifierStillListsAppItselfForUninstall` |
| 19 | 无 Bundle ID 卸载 | 无 Bundle ID 的 App 默认勾选可卸载（回归 #794） | 同 18，注入临时 home 的 AppService | ViewModel 扫描关联文件 | 默认勾选包含 App 本体，卸载按钮可用 | P1 | ✅ 已覆盖 | `nilBundleIdentifierAppIsSelectedForUninstallByDefault` |

> 说明：全部 **19 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

> 变异验证（#794）：把 `AppService.scanRelatedFiles` 无 Bundle ID 分支的 `return relatedFiles` 改回 `return []`（恢复缺陷），`nilBundleIdentifierStillListsAppItselfForUninstall`、`nilBundleIdentifierAppIsSelectedForUninstallByDefault` 两条转红（扫描结果为空、拿不到 App 本体），其余 17 条（合法 Bundle ID / 路径穿越 / 归属保护 / 缓存 / 插件状态）保持绿；还原后 19 条全绿。

## 覆盖率统计

- P0: 已覆盖 6 / 6
- P1: 已覆盖 12 / 12
- P2: 已覆盖 1 / 1
- **合计: 19 / 19**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（6 条）
- **P1**: 其余功能性用例（12 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（1 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 19 条用例位于 `Tests/`，需在目标平台执行 `swift test`

## 测试执行

```bash
cd Packages/PluginAppManager
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例，再写实现
2. **Bug 修复** → 追加回归用例，标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan，标记 ✅ 并填写测试方法名
5. **改名同步** → 重命名 `@Test` 函数后必须同步本表，否则 `Scripts/verify-testplan.py` 会报「登记方法在源码不存在」
