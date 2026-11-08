# TestPlan — KitResume

## 包概述

KitResume 的实现包，包含 6 个主要类型；当前测试覆盖 54 条用例。

平台: macOS 14+, iOS 17+
测试文件: 3 个，用例总数: 54

## 公开 API

包内主要类型（按声明顺序抽取，供定位被测对象）:

- `ResumeImportedAsset`
- `ResumeStoreError`
- `ResumeExportError`
- `ResumeLintSeverity`
- `ResumePaperKind`
- `ResumeTemplateFactory`

## 关键行为契约（实现约定，非协议要求）

按测试模块归纳，改动对应模块时须保持既有断言成立:

- **综合**（12 条）：由 `paperPresetsMapCssPixelsToPdfPoints`、`pixelSizeScalesWithDpi`、`builtInTemplatesPassLintForEveryPaperAndTemplate` 等用例锁定；改动该模块时优先跑对应测试文件。
- **ResumeAssetImporter**（9 条）：由 `importsImageSuccessfully`、`sanitizesPreferredFileName`、`avoidsOverwritingExistingFile` 等用例锁定。
- **Resume models**（6 条）：由 `paperPresetDerivedSizes`、`documentCodableRoundTrip`、`resolvedDocumentDerivedURLs` 等用例锁定。
- **ResumeHTMLLinter**（11 条）：由 `reportSplitsErrorsAndWarnings`、`rejectsOversizedHTML`、`rejectsMissingPageRule` 等用例锁定。
- **ResumeDocumentStore**（6 条）：由 `fullLifecycle`、`fallsBackToSlugForEmptyTitle`、`pathAllowListChecks` 等用例锁定。
- **ResumeExportError**（2 条）：由 `exportErrorDescriptions`、`inspectionSummarizesPages` 锁定。
- **ResumeExporter**（8 条）：由 `exportPNGsRendersEveryPage`、`pngDataMatchesSinglePageExport`、`exportPNGRejectsOutOfRangePageIndex` 等用例锁定。

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | 综合 | paperPresetsMapCssPixelsToPdfPoints | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `paperPresetsMapCssPixelsToPdfPoints` |
| 2 | 综合 | pixelSizeScalesWithDpi | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `pixelSizeScalesWithDpi` |
| 3 | 综合 | builtInTemplatesPassLintForEveryPaperAndTemplate | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `builtInTemplatesPassLintForEveryPaperAndTemplate` |
| 4 | 综合 | linterRejectsScriptsAndRemoteResources | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `linterRejectsScriptsAndRemoteResources` |
| 5 | 综合 | linterRejectsMissingResumePage | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `linterRejectsMissingResumePage` |
| 6 | 综合 | linterRejectsUnsafeAssetPaths | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `linterRejectsUnsafeAssetPaths` |
| 7 | 综合 | storeCreateReadPatchRoundTrip | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `storeCreateReadPatchRoundTrip` |
| 8 | 综合 | storeRejectsInvalidSlugAndDuplicates | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `storeRejectsInvalidSlugAndDuplicates` |
| 9 | 综合 | exportPDFProducesExactPaperSizedVectorPages | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `exportPDFProducesExactPaperSizedVectorPages` |
| 10 | 综合 | exportPNGMatchesDpiPixelSize | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `exportPNGMatchesDpiPixelSize` |
| 11 | 综合 | overflowingPageIsReported | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `overflowingPageIsReported` |
| 12 | 综合 | wrongPageSizeIsRejectedOnExport | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `wrongPageSizeIsRejectedOnExport` |
| 13 | ResumeHTMLExporterTimeout | PDF 捕获状态只会完成一次 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `pdfCaptureStateCompletesOnce` |
| 14 | ResumeHTMLExporterTimeout | PDF 捕获状态在未挂接 continuation 时也能安全完成 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `pdfCaptureStateFinishesWithoutContinuation` |
| 15 | ResumeHTMLExporterTimeout | PDF 捕获超时错误有可读描述 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `pdfCaptureTimedOutDescription` |
| 16 | ResumeHTMLExporterTimeout | 既有错误描述保持不变 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `existingErrorDescriptionsPreserved` |
| 17 | ResumeAssetImporter | 源文件不存在时抛出 sourceNotFound | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `throwsWhenSourceIsMissing` |
| 18 | ResumeAssetImporter | 超过 50MB 上限时抛出 fileTooLarge | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `throwsWhenFileIsTooLarge` |
| 19 | ResumeAssetImporter | 非图片文件抛出 unsupportedImage | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `throwsForUnsupportedImage` |
| 20 | ResumeAssetImporter | 导入图片后返回相对路径与像素尺寸，并在目标目录创建副本 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `importsImageSuccessfully` |
| 21 | ResumeAssetImporter | 指定文件名时按规则净化，非法字符替换为连字符 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `sanitizesPreferredFileName` |
| 22 | ResumeAssetImporter | 文件名净化后只剩非法字符时替换为连字符 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `replacesFullyIllegalFileName` |
| 23 | ResumeAssetImporter | 目标文件已存在时自动追加序号避免覆盖 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `avoidsOverwritingExistingFile` |
| 24 | ResumeAssetImporter | ResumeAssetError 的错误描述覆盖全部 case | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `assetErrorDescriptions` |
| 25 | ResumeAssetImporter | ResumeImportedAsset 保持值语义 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `importedAssetIsEquatable` |
| 26 | Resume models | 纸张枚举暴露 id 与展示名 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `paperKindMetadata` |
| 27 | Resume models | 纸张预设派生 CSS 尺寸、PDF 点尺寸与 DPI 像素尺寸 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `paperPresetDerivedSizes` |
| 28 | Resume models | 模板枚举暴露 id 与展示名 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `templateKindMetadata` |
| 29 | Resume models | 导出分辨率枚举暴露 id、原始值与展示名 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `exportResolutionMetadata` |
| 30 | Resume models | 简历文档可编码解码往返 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `documentCodableRoundTrip` |
| 31 | Resume models | 已解析文档推导 HTML 与资产目录地址 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `resolvedDocumentDerivedURLs` |
| 32 | ResumeHTMLLinter | 报告把问题按严重级别分流 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `reportSplitsErrorsAndWarnings` |
| 33 | ResumeHTMLLinter | 超出字节上限时报 html_too_large | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `rejectsOversizedHTML` |
| 34 | ResumeHTMLLinter | 缺少 doctype 或 html 标签时报 incomplete_document | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `rejectsIncompleteDocument` |
| 35 | ResumeHTMLLinter | 缺少 viewport 元标签时报 missing_viewport | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `rejectsMissingViewport` |
| 36 | ResumeHTMLLinter | 出现 iframe 时报 iframe_forbidden | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `rejectsIframe` |
| 37 | ResumeHTMLLinter | 出现 CSS @import 时报 css_import_forbidden | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `rejectsCSSImport` |
| 38 | ResumeHTMLLinter | 出现动画或过渡时给出 motion_disabled 警告 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `warnsAboutMotion` |
| 39 | ResumeHTMLLinter | .resume-page 规则缺少宽高时报 resume_page_missing_size | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `rejectsPageWithoutSize` |
| 40 | ResumeHTMLLinter | 完全没有 .resume-page CSS 规则时同样报 resume_page_missing_size | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `rejectsMissingPageRule` |
| 41 | ResumeHTMLLinter | 引用不存在的本地资产时报 missing_asset | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `reportsMissingAsset` |
| 42 | ResumeHTMLLinter | 合法模板不产生任何错误 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `acceptsValidHTML` |
| 43 | ResumeDocumentStore | create/list/read/lint/assets/delete 全链路 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `fullLifecycle` |
| 44 | ResumeDocumentStore | 删除不存在的简历抛出 notFound | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `throwsWhenDeletingMissingResume` |
| 45 | ResumeDocumentStore | 空标题回退到 slug | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `fallsBackToSlugForEmptyTitle` |
| 46 | ResumeDocumentStore | 路径白名单判定覆盖相等、前缀与越界三种情况 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `pathAllowListChecks` |
| 47 | ResumeDocumentStore | slug 校验会修剪空白并转小写 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `validatedSlugNormalizes` |
| 48 | ResumeDocumentStore | ResumeStoreError 的错误描述覆盖全部 case | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `storeErrorDescriptions` |
| 49 | ResumeExportError | 错误描述覆盖全部 case | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `exportErrorDescriptions` |
| 50 | ResumeExportError | 页面检查结果汇总页数与溢出页 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `inspectionSummarizesPages` |
| 51 | ResumeExporter | 多页 HTML 逐页导出 PNG | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `exportPNGsRendersEveryPage` |
| 52 | ResumeExporter | PNG 数据与单页导出结果一致 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `pngDataMatchesSinglePageExport` |
| 53 | ResumeExporter | 页码越界时抛出 noPages | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `exportPNGRejectsOutOfRangePageIndex` |
| 54 | ResumeExporter | 页面检查拒绝没有 .resume-page 的 HTML | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `inspectPagesRejectsHTMLWithoutResumePage` |

> 说明：全部 **54 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 6 / 6
- P1: 已覆盖 37 / 37
- P2: 已覆盖 11 / 11
- **合计: 54 / 54**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（6 条）
- **P1**: 其余功能性用例（37 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（11 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 54 条用例位于 `Tests/`，需在目标平台执行 `swift test`

## 测试执行

```bash
cd Packages/KitResume
swift test
```

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例，再写实现
2. **Bug 修复** → 追加回归用例，标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan，标记 ✅ 并填写测试方法名
5. **改名同步** → 重命名 `@Test` 函数后必须同步本表，否则 `Scripts/verify-testplan.py` 会报「登记方法在源码不存在」
