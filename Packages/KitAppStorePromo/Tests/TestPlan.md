# TestPlan — KitAppStorePromo

## 包概述

KitAppStorePromo 的实现包，包含 6 个主要类型；当前测试覆盖 53 条用例。

平台: macOS 14+, iOS 17+
测试文件: 4 个，用例总数: 53

## 公开 API

包内主要类型（按声明顺序抽取，供定位被测对象）:

- `AppStorePromoImportedAsset`
- `AppStorePromoStoreError`
- `AppStorePromoExportError`
- `AppStorePromoLintSeverity`
- `AppStorePromoDeviceFamily`
- `AppStorePromoTemplateFactory`

## 关键行为契约（实现约定，非协议要求）

按测试模块归纳，改动对应模块时须保持既有断言成立:

- **AppStorePromoModelCoverage**（8 条）：由 `familyDisplayTypes`、`presetDerivedProperties`、`localeHelpers` 等用例锁定；改动该模块时优先跑对应测试文件。
- **AppStorePromoStoreCoverage**（15 条）：由 `invalidLocaleDoesNotLeaveTaskDirectoryBehind`、`invalidHTMLDoesNotLeaveImageDirectoryBehind`、`slugValidationRejectsBadInputButTrimsGoodInput` 等用例锁定；改动该模块时优先跑对应测试文件。
- **AssetImporterAndLinter**（16 条）：由 `importsImageAndReportsPixelSize`、`collidingFileNamesGetSuffix`、`missingSourceThrows` 等用例锁定；改动该模块时优先跑对应测试文件。
- **综合**（14 条）：由 `displayPresetsAreUniqueAndValid`、`linterRejectsRemoteAndExecutableHTML`、`storeCreatesPersistsAndAtomicallyPatchesTaskImage` 等用例锁定；改动该模块时优先跑对应测试文件。

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | AppStorePromoModelCoverage | device family display types match presets | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `familyDisplayTypes` |
| 2 | AppStorePromoModelCoverage | preset derived properties | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `presetDerivedProperties` |
| 3 | AppStorePromoModelCoverage | locale helpers | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `localeHelpers` |
| 4 | AppStorePromoModelCoverage | locale normalization edge cases | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `localeNormalizationEdges` |
| 5 | AppStorePromoModelCoverage | device family identifiers and localized names | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `familyIDsAndLocalizedNames` |
| 6 | AppStorePromoModelCoverage | image decoding applies defaults for optional fields | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `imageDecodingAppliesDefaults` |
| 7 | AppStorePromoModelCoverage | asset error descriptions are non-empty | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `assetErrorDescriptions` |
| 8 | AppStorePromoModelCoverage | resolved image exposes assets directory | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `resolvedImageAssetsDirectory` |
| 9 | AppStorePromoStoreCoverage | invalidLocaleDoesNotLeaveTaskDirectoryBehind | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `invalidLocaleDoesNotLeaveTaskDirectoryBehind` |
| 10 | AppStorePromoStoreCoverage | invalidHTMLDoesNotLeaveImageDirectoryBehind | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `invalidHTMLDoesNotLeaveImageDirectoryBehind` |
| 11 | AppStorePromoStoreCoverage | slugValidationRejectsBadInputButTrimsGoodInput | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `slugValidationRejectsBadInputButTrimsGoodInput` |
| 12 | AppStorePromoStoreCoverage | emptyStoragePathThrowsInvalidStoragePath | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `emptyStoragePathThrowsInvalidStoragePath` |
| 13 | AppStorePromoStoreCoverage | duplicateTaskAndImageReportAlreadyExists | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `duplicateTaskAndImageReportAlreadyExists` |
| 14 | AppStorePromoStoreCoverage | missingTaskImageAndLocaleReportNotFound | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `missingTaskImageAndLocaleReportNotFound` |
| 15 | AppStorePromoStoreCoverage | duplicateLocalizationAndAmbiguousPatchAreRejected | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `duplicateLocalizationAndAmbiguousPatchAreRejected` |
| 16 | AppStorePromoStoreCoverage | replaceHTMLRejectsInvalidMarkupWithoutTouchingStoredFile | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `replaceHTMLRejectsInvalidMarkupWithoutTouchingStoredFile` |
| 17 | AppStorePromoStoreCoverage | lintImageReportsStoredMarkupState | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `lintImageReportsStoredMarkupState` |
| 18 | AppStorePromoStoreCoverage | listTasksSortsByMostRecentlyUpdated | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `listTasksSortsByMostRecentlyUpdated` |
| 19 | AppStorePromoStoreCoverage | assetsDirectoryIsCreatedOnDemand | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `assetsDirectoryIsCreatedOnDemand` |
| 20 | AppStorePromoStoreCoverage | pathResolutionAndBoundaries | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `pathResolutionAndBoundaries` |
| 21 | AppStorePromoStoreCoverage | storeErrorDescriptionsAreNonEmpty | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `storeErrorDescriptionsAreNonEmpty` |
| 22 | AppStorePromoStoreCoverage | readImageThrowsWhenHTMLFileIsMissingOnDisk | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `readImageThrowsWhenHTMLFileIsMissingOnDisk` |
| 23 | AppStorePromoStoreCoverage | defaultsAndEscaping | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `defaultsAndEscaping` |
| 24 | AssetImporterAndLinter | importsImageAndReportsPixelSize | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `importsImageAndReportsPixelSize` |
| 25 | AssetImporterAndLinter | collidingFileNamesGetSuffix | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `collidingFileNamesGetSuffix` |
| 26 | AssetImporterAndLinter | missingSourceThrows | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `missingSourceThrows` |
| 27 | AssetImporterAndLinter | nonImageThrowsUnsupported | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `nonImageThrowsUnsupported` |
| 28 | AssetImporterAndLinter | oversizedFileThrowsBeforeDecoding | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `oversizedFileThrowsBeforeDecoding` |
| 29 | AssetImporterAndLinter | usesSourceFileNameWhenPreferredNameOmitted | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `usesSourceFileNameWhenPreferredNameOmitted` |
| 30 | AssetImporterAndLinter | acceptsMinimalDocument | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `acceptsMinimalDocument` |
| 31 | AssetImporterAndLinter | oversizedHTMLFails | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `oversizedHTMLFails` |
| 32 | AssetImporterAndLinter | missingViewportAndDoctypeFail | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `missingViewportAndDoctypeFail` |
| 33 | AssetImporterAndLinter | iframeAndCSSImportFail | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `iframeAndCSSImportFail` |
| 34 | AssetImporterAndLinter | animationAndMissingBackgroundWarn | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `animationAndMissingBackgroundWarn` |
| 35 | AssetImporterAndLinter | absoluteAndParentPathsAreUnsafe | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `absoluteAndParentPathsAreUnsafe` |
| 36 | AssetImporterAndLinter | missingLocalAssetFailsWhenDirectoryProvided | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `missingLocalAssetFailsWhenDirectoryProvided` |
| 37 | AssetImporterAndLinter | dataURIsAreSkipped | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `dataURIsAreSkipped` |
| 38 | AssetImporterAndLinter | percentEncodedAssetPathsAreResolved | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `percentEncodedAssetPathsAreResolved` |
| 39 | AssetImporterAndLinter | fragmentOnlyLinksAreSkipped | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `fragmentOnlyLinksAreSkipped` |
| 40 | 综合 | displayPresetsAreUniqueAndValid | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `displayPresetsAreUniqueAndValid` |
| 41 | 综合 | linterRejectsRemoteAndExecutableHTML | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `linterRejectsRemoteAndExecutableHTML` |
| 42 | 综合 | storeCreatesPersistsAndAtomicallyPatchesTaskImage | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `storeCreatesPersistsAndAtomicallyPatchesTaskImage` |
| 43 | 综合 | patchBatchRollsBackWhenAnyMatchIsMissing | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `patchBatchRollsBackWhenAnyMatchIsMissing` |
| 44 | 综合 | imageLanguageVersionsAreIndependentAndLegacySafe | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `imageLanguageVersionsAreIndependentAndLegacySafe` |
| 45 | 综合 | legacyImageWithoutLocalesUsesTaskLocale | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `legacyImageWithoutLocalesUsesTaskLocale` |
| 46 | 综合 | storeDeletesManagedImagesAndTasks | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `storeDeletesManagedImagesAndTasks` |
| 47 | 综合 | pathAccessUsesDirectoryBoundaries | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `pathAccessUsesDirectoryBoundaries` |
| 48 | 综合 | exporterProducesExactViewportPixels | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `exporterProducesExactViewportPixels` |
| 49 | 综合 | exporterPreservesFeatureSVGs | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `exporterPreservesFeatureSVGs` |
| 50 | 综合 | exporterLoadsFromDiskFileURL | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `exporterLoadsFromDiskFileURL` |
| 51 | 综合 | exporterFailsWhenFileURLIsUnreachable | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `exporterFailsWhenFileURLIsUnreachable` |
| 52 | 综合 | exporterTimesOutWhenImagesNeverLoad | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `exporterTimesOutWhenImagesNeverLoad` |
| 53 | 综合 | exportErrorDescriptionsAreNonEmpty | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `exportErrorDescriptionsAreNonEmpty` |

> 说明：全部 **53 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 8 / 8
- P1: 已覆盖 40 / 40
- P2: 已覆盖 5 / 5
- **合计: 53 / 53**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（8 条）
- **P1**: 其余功能性用例（40 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（5 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 53 条用例位于 `Tests/`，需在目标平台执行 `swift test`

## 测试执行

```bash
cd Packages/KitAppStorePromo
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例，再写实现
2. **Bug 修复** → 追加回归用例，标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan，标记 ✅ 并填写测试方法名
5. **改名同步** → 重命名 `@Test` 函数后必须同步本表，否则 `Scripts/verify-testplan.py` 会报「登记方法在源码不存在」
