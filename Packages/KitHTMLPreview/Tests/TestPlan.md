# TestPlan — KitHTMLPreview

## 包概述

KitHTMLPreview A SwiftUI-based HTML preview component powered by `WKWebView`. ## Overview `KitHTMLPreview` provides a ready-to-use `HTMLPreviewView` that renders HTML content inside a SwiftUI view hierarchy. It supports two loading modes: - **File-based loading** — pass a `fileURL` to load a local `.html`/`.htm` file. Relative resources (CSS, JS, images) are resolved against the file's directory. - **String-based loading** — pass an `htmlText` string directly. When a `fileURL` is also provided, relative resources are resolved against the file's parent directory as the base URL. The view automatically detects whether the in-memory HTML string is still in sync with the on-disk file and loads

平台: macOS 14+, iOS 17+
测试文件: 8 个，用例总数: 39

## 公开 API

包内主要类型（按声明顺序抽取，供定位被测对象）:

- `HTMLPreviewContextMenuRequest`
- `HTMLPreviewElementBridgeScript`
- `HTMLPreviewElementContextMenuItem`
- `HTMLPreviewElementReference`
- `HTMLPreviewLoadPlanner`
- `HTMLPreviewView`
- `HTMLScreenshotter`
- `KitHTMLPreviewLocalization`
- `PreviewBoardGrid`
- `PromoBlockSelection`

## 关键行为契约（实现约定，非协议要求）

按测试模块归纳，改动对应模块时须保持既有断言成立:

- **HTMLPreviewContextMenuRequest**（7 条）：由 `decodesValidRequest`、`rejectsUnsupportedVersion`、`rejectsUnknownAction` 等用例锁定；改动该模块时优先跑对应测试文件。
- **HTMLPreviewElementBridge**（4 条）：由 `resolvesInteractiveTargetAndParent`、`buildsUniqueSelectors`、`boundsHTMLAndIsolatesOverlay` 等用例锁定；改动该模块时优先跑对应测试文件。
- **HTMLPreviewElementContextMenu**（7 条）：由 `ordersCandidates`、`distinguishesRepeatedLabels`、`truncatesLabels` 等用例锁定；改动该模块时优先跑对应测试文件。
- **HTMLPreviewLegacyCompatibility**（3 条）：由 `legacyInitializerRemainsAvailable`、`legacyMessageDecoding`、`newInitializerKeepsLegacyDisabled` 等用例锁定；改动该模块时优先跑对应测试文件。
- **HTMLPreviewLoadPlanner**（9 条）：由 `rawHTMLWithoutFileURL`、`matchingUTF8FileLoadsFileURL`、`matchingUTF16FileLoadsFileURL` 等用例锁定；改动该模块时优先跑对应测试文件。
- **HTMLScreenshotterCapture**（2 条）：由 `capturesFullPage`、`throwsForEmptyDocument` 等用例锁定；改动该模块时优先跑对应测试文件。
- **HTMLScreenshotterError**（1 条）：由 `errorDescriptions` 等用例锁定；改动该模块时优先跑对应测试文件。

## 测试用例清单

| ID | 类别 | 描述 | 前置条件 | 操作步骤 | 预期结果 | 优先级 | 状态 | 测试方法 |
|----|------|------|----------|----------|----------|------|------|----------|
| 1 | HTMLPreviewContextMenuRequest | decodes and normalizes a valid request | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `decodesValidRequest` |
| 2 | HTMLPreviewContextMenuRequest | rejects an unsupported schema version | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `rejectsUnsupportedVersion` |
| 3 | HTMLPreviewContextMenuRequest | rejects an unknown action | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `rejectsUnknownAction` |
| 4 | HTMLPreviewContextMenuRequest | rejects empty and oversized candidate lists | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `rejectsCandidateCount` |
| 5 | HTMLPreviewContextMenuRequest | rejects invalid coordinates | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `rejectsInvalidCoordinates` |
| 6 | HTMLPreviewContextMenuRequest | rejects oversized selectors labels and HTML | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `rejectsOversizedFields` |
| 7 | HTMLPreviewContextMenuRequest | removes control characters from labels | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `normalizesControlCharacters` |
| 8 | HTMLPreviewElementBridge | normalizes a decorative child to its button and includes its block parent | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `resolvesInteractiveTargetAndParent` |
| 9 | HTMLPreviewElementBridge | prefers unique block selectors and falls back when block IDs repeat | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `buildsUniqueSelectors` |
| 10 | HTMLPreviewElementBridge | bounds HTML and never serializes bridge markup | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `boundsHTMLAndIsolatesOverlay` |
| 11 | HTMLPreviewElementBridge | reinjection is idempotent and disposal removes the overlay | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `reinjectionAndDisposal` |
| 12 | HTMLPreviewElementContextMenu | orders the target before its ancestors | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `ordersCandidates` |
| 13 | HTMLPreviewElementContextMenu | distinguishes repeated labels | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `distinguishesRepeatedLabels` |
| 14 | HTMLPreviewElementContextMenu | truncates titles by user-perceived characters | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `truncatesLabels` |
| 15 | HTMLPreviewElementContextMenu | disables every action when conversation is unavailable | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `disablesUnavailableActions` |
| 16 | HTMLPreviewElementContextMenu | keeps the selection callback alive until menu tracking finishes | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `selectionSurvivesMenuClose` |
| 17 | HTMLPreviewElementContextMenu | cancelling menu tracking finishes exactly once | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `cancellationFinishesOnce` |
| 18 | HTMLPreviewElementContextMenu | uses the native orientation of flipped web views | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `flippedPresentationPoint` |
| 19 | HTMLPreviewLegacyCompatibility | legacy block callback remains independent from element references | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `legacyInitializerRemainsAvailable` |
| 20 | HTMLPreviewLegacyCompatibility | legacy message decoding preserves defaults | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `legacyMessageDecoding` |
| 21 | HTMLPreviewLegacyCompatibility | new element callback does not enable the legacy bridge | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `newInitializerKeepsLegacyDisabled` |
| 22 | HTMLPreviewLoadPlanner | loads raw HTML string without a base URL when no file URL is supplied | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `rawHTMLWithoutFileURL` |
| 23 | HTMLPreviewLoadPlanner | loads the file directly when in-memory UTF-8 HTML exactly matches the file | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `matchingUTF8FileLoadsFileURL` |
| 24 | HTMLPreviewLoadPlanner | loads the file directly when in-memory HTML matches a UTF-16 encoded file | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `matchingUTF16FileLoadsFileURL` |
| 25 | HTMLPreviewLoadPlanner | loads HTML string with the file parent directory as base URL when file content is different | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `mismatchedFileLoadsHTMLWithBaseURL` |
| 26 | HTMLPreviewLoadPlanner | loads HTML string with a base URL when reading the file fails | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `unreadableFileLoadsHTMLWithBaseURL` |
| 27 | HTMLPreviewLoadPlanner | loads HTML string with a base URL when file data is not decodable as supported text | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `undecodableFileLoadsHTMLWithBaseURL` |
| 28 | HTMLPreviewLoadPlanner | default file reader reads real files from disk and detects sync | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `defaultFileReaderUsesFileSystem` |
| 29 | HTMLPreviewLoadPlanner | absoluteDirectoryURL always has a trailing slash | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `absoluteDirectoryURLAddsTrailingSlash` |
| 30 | HTMLPreviewLoadPlanner | absoluteDirectoryURL preserves an existing trailing slash | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `absoluteDirectoryURLPreservesTrailingSlash` |
| 31 | HTMLScreenshotterCapture | captures a rendered web page into a non-empty image spanning all content | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `capturesFullPage` |
| 32 | HTMLScreenshotterCapture | throws an error for a web view with no rendered content | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `throwsForEmptyDocument` |
| 33 | HTMLScreenshotterError | error descriptions are stable and user-readable | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `errorDescriptions` |
| 34 | HTMLScreenshotterCapture | capture times out instead of hanging when the render never completes | 游离 WKWebView（不挂窗口） | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `captureTimesOutInsteadOfHanging` |
| 35 | HTMLScreenshotterCapture | capture throws renderTimedOut when the render never completes | 游离 WKWebView（不挂窗口） | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `captureThrowsRenderTimedOut` |
| 36 | HTMLScreenshotterTimeout | PDF 请求状态只会完成一次 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `pdfRequestStateCompletesOnce` |
| 37 | HTMLScreenshotterTimeout | PDF 请求状态在未挂接 continuation 时也能安全完成 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `pdfRequestStateFinishesWithoutContinuation` |
| 38 | HTMLScreenshotterTimeout | render timed out error has a readable description | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `renderTimedOutDescription` |
| 39 | HTMLScreenshotterTimeout | existing error descriptions are preserved | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `existingErrorDescriptionsPreserved` |

> 说明：全部 **39 条场景**已在本包 `swift test` 中实跑通过。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。

## 覆盖率统计

- P0: 已覆盖 10 / 10
- P1: 已覆盖 21 / 21
- P2: 已覆盖 8 / 8
- **合计: 39 / 39**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（10 条）
- **P1**: 其余功能性用例（21 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（8 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 39 条用例位于 `Tests/`，需在目标平台执行 `swift test`

## 测试执行

```bash
cd Packages/KitHTMLPreview
swift test
```

### 运行前提

WebKit 渲染类用例（`HTMLScreenshotter capture`）依赖真实的 WebKit 渲染进程：

- 需要**已登录的图形会话**（Aqua session）。无 GUI 会话时 WebKit 不推进渲染，
  `createPDF` 的完成回调不会送达。
- 渲染回调本身不保证送达，因此 `HTMLScreenshotter.capture` 带超时保护
  （默认 30s，超时抛 `HTMLError.renderTimedOut`）。在无 GUI 会话或 WebKit 状态异常的
  环境下，渲染用例会**以 `renderTimedOut` 失败**而不是永久挂起 —— 这是预期行为。
- 若整包运行时出现 `renderTimedOut`，先确认当前环境有图形会话，再重跑；
  机器负载过高时 WebKit 回调也会显著延迟。

## 维护规则

1. **新增公开 API** → 先在 TestPlan 登记测试用例，再写实现
2. **Bug 修复** → 追加回归用例，标注触发条件
3. **删除用例** → 在 commit message 说明理由
4. **状态同步** → 实现后更新 TestPlan，标记 ✅ 并填写测试方法名
5. **改名同步** → 重命名 `@Test` 函数后必须同步本表，否则 `Scripts/verify-testplan.py` 会报「登记方法在源码不存在」
