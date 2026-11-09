# TestPlan — KitPrototype

## 包概述

KitPrototype 的实现包，包含 6 个主要类型；当前测试覆盖 42 条用例。

平台: macOS 14+, iOS 17+
测试文件: 1 个，用例总数: 42

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

- **综合**（36 条）：由 `devicePresetsAreUniqueAndConsistent`、`hotspotParsingReadsLinksAndLabels`、`hotspotParsingHandlesSingleQuotesAndNoLabel` 等用例锁定；改动该模块时优先跑对应测试文件。

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
| 35 | 设备尺寸边界 | 超大尺寸被识别为不可渲染且像素值不 trap（**回归 #1000**） | `width = 1e20` | 读取 `hasRenderableMetrics` / `pixelWidth` / `logicalWidthInt` | 判定为 false，数值夹到 `Int.max` 而非崩溃 | P0 | ✅ 已覆盖 | `oversizedDimensionsAreRejectedAndNeverTrap` |
| 36 | 设备尺寸边界 | 非有限、非正或乘积溢出的尺寸被拒绝（**回归 #1000**） | NaN / ∞ / 0 / scale 0 / 乘积溢出 | 读取 `hasRenderableMetrics` | 全部为 false | P0 | ✅ 已覆盖 | `nonFiniteOrNonPositiveMetricsAreRejected` |
| 37 | 设备尺寸边界 | 正常预设尺寸保持有效 | iPhone 15 Pro 393×852 @3x | 读取 `hasRenderableMetrics` 与像素尺寸 | true，且 1179×2556 | P1 | ✅ 已覆盖 | `normalPresetMetricsStayValid` |
| 38 | 综合 | inline SVG 的 XML namespace 不算远程资源（**回归 #1085**） | — | lint 含 `<svg xmlns="http://www.w3.org/2000/svg">` 的合法文档 | 无 `remote_resource`，报告有效 | P1 | ✅ 已覆盖 | `linterAcceptsInlineSVGNamespace` |
| 39 | 综合 | 只拒绝资源加载位置的远程 URL（**回归 #1085**） | — | 分别 lint 远程 `src`、协议相对 `src`、远程 `href`、CSS `url(...)` 与纯文本 URL | 前四者报 `remote_resource`；纯文本不报 | P0 | ✅ 已覆盖 | `linterOnlyRejectsRemoteResourcesInLoadingPositions` |
| 40 | 综合 | CSS `url(...)` 引用的缺失资源被报 `missing_asset`（**回归 #1084**） | 屏幕目录与缺失的 `../assets/does-not-exist.png` | lint 含 CSS `background-image: url(...)` 的文档 | 产生 error 级 `missing_asset` | P0 | ✅ 已覆盖 | `linterReportsMissingCSSURLAsset` |
| 41 | 综合 | 替换 HTML 时缺失的 CSS 背景图阻止保存（**回归 #1084**） | 项目/screen 已创建，CSS 引用不存在资源 | 调用 `replaceScreenHTML` | 抛出 `PrototypeStoreError` | P0 | ✅ 已覆盖 | `replaceScreenHTMLRejectsMissingCSSURLAsset` |
| 42 | 综合 | 已存在的 CSS 背景图、data URI 与片段引用不误报 | `assets/bg.png` 存在 | lint 含 `url("../assets/bg.png")`、`url(data:...)`、`url(#fallback)` 的文档 | 无 `missing_asset` / `unsafe_asset_path` | P1 | ✅ 已覆盖 | `linterAcceptsExistingAndNonLocalCSSURLAssets` |

> 说明：全部 **42 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 14 / 14
- P1: 已覆盖 21 / 21
- P2: 已覆盖 7 / 7
- **合计: 42 / 42**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（14 条）
- **P1**: 其余功能性用例（21 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（7 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 39 条用例位于 `Tests/`，需在目标平台执行 `swift test`

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

