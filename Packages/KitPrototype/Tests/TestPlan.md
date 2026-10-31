# TestPlan — KitPrototype

## 包概述

KitPrototype 的实现包，包含 6 个主要类型；当前测试覆盖 34 条用例。

平台: macOS 14+, iOS 17+
测试文件: 1 个，用例总数: 34

## 公开 API

包内主要类型（按声明顺序抽取，供定位被测对象）:

- `PrototypeImportedAsset`
- `PrototypeStoreError`
- `PrototypeExportError`
- `PrototypeLintSeverity`
- `PrototypeDeviceKind`
- `PrototypeTemplateFactory`

## 关键行为契约（实现约定，非协议要求）

按测试模块归纳，改动对应模块时须保持既有断言成立:

- **综合**（34 条）：由 `devicePresetsAreUniqueAndConsistent`、`hotspotParsingReadsLinksAndLabels`、`hotspotParsingHandlesSingleQuotesAndNoLabel` 等用例锁定；改动该模块时优先跑对应测试文件。

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | 综合 | devicePresetsAreUniqueAndConsistent | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `devicePresetsAreUniqueAndConsistent` |
| 2 | 综合 | hotspotParsingReadsLinksAndLabels | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `hotspotParsingReadsLinksAndLabels` |
| 3 | 综合 | hotspotParsingHandlesSingleQuotesAndNoLabel | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `hotspotParsingHandlesSingleQuotesAndNoLabel` |
| 4 | 综合 | linterRejectsScriptsRemoteResourcesAndIncompleteDocuments | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `linterRejectsScriptsRemoteResourcesAndIncompleteDocuments` |
| 5 | 综合 | linterAllowsMotionButWarns | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `linterAllowsMotionButWarns` |
| 6 | 综合 | linterWarnsAboutUnstableBlockAnnotations | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `linterWarnsAboutUnstableBlockAnnotations` |
| 7 | 综合 | linterAcceptsUniqueLabeledBlocks | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `linterAcceptsUniqueLabeledBlocks` |
| 8 | 综合 | linterReportsUnknownJumpTarget | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `linterReportsUnknownJumpTarget` |
| 9 | 综合 | linterSkipsJumpValidationWhenScreenSetUnknown | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `linterSkipsJumpValidationWhenScreenSetUnknown` |
| 10 | 综合 | linterRejectsEscapingAssetPaths | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `linterRejectsEscapingAssetPaths` |
| 11 | 综合 | linterRejectsAbsoluteAssetPaths | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `linterRejectsAbsoluteAssetPaths` |
| 12 | 综合 | sharedAssetPathIsAcceptedWhileEscapesAreRejected | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `sharedAssetPathIsAcceptedWhileEscapesAreRejected` |
| 13 | 综合 | linterWarnsAboutEscapedScriptMarkup | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `linterWarnsAboutEscapedScriptMarkup` |
| 14 | 综合 | templatesProduceValidDocumentsForBothStyles | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `templatesProduceValidDocumentsForBothStyles` |
| 15 | 综合 | templatesEscapeInjectedTitle | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `templatesEscapeInjectedTitle` |
| 16 | 综合 | storeCreatesProjectAddsScreensAndPersists | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `storeCreatesProjectAddsScreensAndPersists` |
| 17 | 综合 | storeRejectsDuplicateAndReservedSlugs | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `storeRejectsDuplicateAndReservedSlugs` |
| 18 | 综合 | storePatchesAtomicallyAndRefreshesHotspots | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `storePatchesAtomicallyAndRefreshesHotspots` |
| 19 | 综合 | patchBatchFailsWhenAnyMatchIsMissingOrAmbiguous | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `patchBatchFailsWhenAnyMatchIsMissingOrAmbiguous` |
| 20 | 综合 | replaceScreenHTMLRejectsInvalidDocument | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `replaceScreenHTMLRejectsInvalidDocument` |
| 21 | 综合 | replaceScreenHTMLRejectsUnknownJumpTarget | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `replaceScreenHTMLRejectsUnknownJumpTarget` |
| 22 | 综合 | replaceScreenHTMLAcceptsValidJumpBetweenScreens | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `replaceScreenHTMLAcceptsValidJumpBetweenScreens` |
| 23 | 综合 | duplicateScreenCopiesHTML | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `duplicateScreenCopiesHTML` |
| 24 | 综合 | deleteScreenReindexesAndRepointsStartScreen | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `deleteScreenReindexesAndRepointsStartScreen` |
| 25 | 综合 | deleteScreenRefreshesDanglingHotspotsWithoutThrowing | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `deleteScreenRefreshesDanglingHotspotsWithoutThrowing` |
| 26 | 综合 | reorderScreensRequiresCompleteUniqueList | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `reorderScreensRequiresCompleteUniqueList` |
| 27 | 综合 | setStartScreenValidatesExistence | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `setStartScreenValidatesExistence` |
| 28 | 综合 | listProjectsSortsByRecencyAndReadsDefaults | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `listProjectsSortsByRecencyAndReadsDefaults` |
| 29 | 综合 | lintProjectReportsEveryScreen | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `lintProjectReportsEveryScreen` |
| 30 | 综合 | storeRequiresNonEmptyStoragePath | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `storeRequiresNonEmptyStoragePath` |
| 31 | 综合 | projectNotFoundThrows | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `projectNotFoundThrows` |
| 32 | 综合 | importerCopiesImageAndReturnsSharedRelativePath | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `importerCopiesImageAndReturnsSharedRelativePath` |
| 33 | 综合 | importerRejectsUnsupportedImage | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `importerRejectsUnsupportedImage` |
| 34 | 综合 | importerRejectsMissingSource | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `importerRejectsMissingSource` |

> 说明：全部 **34 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 9 / 9
- P1: 已覆盖 18 / 18
- P2: 已覆盖 7 / 7
- **合计: 34 / 34**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（9 条）
- **P1**: 其余功能性用例（18 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（7 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 34 条用例位于 `Tests/`，需在目标平台执行 `swift test`

## 测试执行

```bash
cd Packages/KitPrototype
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例，再写实现
2. **Bug 修复** → 追加回归用例，标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan，标记 ✅ 并填写测试方法名
5. **改名同步** → 重命名 `@Test` 函数后必须同步本表，否则 `Scripts/verify-testplan.py` 会报「登记方法在源码不存在」
