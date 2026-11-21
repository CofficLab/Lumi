# TestPlan — KitHTMLPreview

## 包概述

KitHTMLPreview A SwiftUI-based HTML preview component powered by `WKWebView`. ## Overview `KitHTMLPreview` provides a ready-to-use `HTMLPreviewView` that renders HTML content inside a SwiftUI view hierarchy. It supports two loading modes: - **File-based loading** — pass a `fileURL` to load a local `.html`/`.htm` file. Relative resources (CSS, JS, images) are resolved against the file's directory. - **String-based loading** — pass an `htmlText` string directly. When a `fileURL` is also provided, relative resources are resolved against the file's parent directory as the base URL. The view automatically detects whether the in-memory HTML string is still in sync with the on-disk file and loads

平台: macOS 14+, iOS 17+
测试文件: 14 个，用例总数: 79

## 公开 API

包内主要类型（按声明顺序抽取，供定位被测对象）:

- `HTMLPreviewContextMenuRequest`
- `HTMLPreviewElementBridgeScript`
- `HTMLPreviewElementContextMenuItem`
- `HTMLPreviewElementReference`
- `HTMLPreviewLoadPlanner`
- `HTMLPreviewPrototypeLinkRequest`
- `HTMLPreviewPrototypeLinkScript`
- `HTMLPreviewView`
- `HTMLScreenshotter`
- `KitHTMLPreviewLocalization`
- `PreviewBoardGrid`
- `PromoBlockSelection`

## 关键行为契约（实现约定，非协议要求）

按测试模块归纳，改动对应模块时须保持既有断言成立:

- **HTMLPreviewContextMenuRequest**（7 条）：由 `decodesValidRequest`、`rejectsUnsupportedVersion`、`rejectsUnknownAction` 等用例锁定；改动该模块时优先跑对应测试文件。
- **HTMLPreviewContentJavaScript**（3 条）：预览与导出一致地禁用内容 JavaScript，内联事件处理器/script 不得执行，原生注入的选区桥接仍触发（issue #494）；改动预览 WebView 配置时优先跑对应测试文件。
- **HTMLScreenshotterOffMain**（2 条）：由 `rasterizesOffMain`、`rejectsOversizedOffMain` 锁定 PDF 栅格化在主 actor 之外执行且先拒超限；改动快照栅格化路径时优先跑对应测试文件。
- **HTMLPreviewElementBridge**（4 条）：由 `resolvesInteractiveTargetAndParent`、`buildsUniqueSelectors`、`boundsHTMLAndIsolatesOverlay` 等用例锁定；改动该模块时优先跑对应测试文件。
- **HTMLPreviewElementContextMenu**（7 条）：由 `ordersCandidates`、`distinguishesRepeatedLabels`、`truncatesLabels` 等用例锁定；改动该模块时优先跑对应测试文件。
- **HTMLPreviewLegacyCompatibility**（3 条）：由 `legacyInitializerRemainsAvailable`、`legacyMessageDecoding`、`newInitializerKeepsLegacyDisabled` 等用例锁定；改动该模块时优先跑对应测试文件。
- **HTMLPreviewLegacySelectionScript**（2 条）：存量选区桥点击「发给助手」时，回传源码须剔除宿主注入的浮动按钮/描边遮罩、只保留用户原始区块标记（issue #495）；由 `serializedBlockExcludesHostOverlays`、`serializedBlockKeepsOriginalDocumentMarkup` 锁定；改动 `selectionScript` 序列化路径时优先跑对应测试文件。
- **HTMLPreviewPrototypeLinkScript**（7 条）：生产预览必须响应声明的 `data-prototype-link` 热点点击并回传目标屏 ID，装饰性子元素解析到最近热点，空白目标与非热点点击静默忽略，锚点默认导航被阻止（issue #323）；由 `hotspotClickPostsDeclaredTarget` 等用例锁定；改动 `HTMLPreviewPrototypeLinkScript` 或预览注入路径时优先跑对应测试文件。
- **HTMLPreviewPrototypeLinkRequest**（8 条）：回传载荷按 schemaVersion=1 / action=prototypeLink 校验，目标裁剪空白且不超过 256 字符，超限载荷与非法结构被拒绝（issue #323）；由 `decodesValidRequest` 等用例锁定；改动 `HTMLPreviewPrototypeLinkRequestDecoder` 时优先跑对应测试文件。
- **HTMLScreenshotterCancellation**（1 条）：取消快照必须在渲染前中止；改动快照取消路径时优先跑对应测试文件。
- **HTMLPreviewLoadPlanner**（13 条）：由 `rawHTMLWithoutFileURL`、`matchingUTF8FileLoadsFileURL`、`matchingUTF16FileLoadsFileURL`、`emptyHTMLWithReadableFileLoadsFileURL` 等用例锁定；改动该模块时优先跑对应测试文件。
- **HTMLScreenshotterCapture**（5 条）：由 `capturesFullPage`、`throwsForEmptyDocument`、`rejectsOversizedDocument` 等用例锁定；改动该模块时优先跑对应测试文件。
- **HTMLScreenshotterLimits**（6 条）：页数、总像素与单边尺寸的独立上限，在分配位图前拒绝超限文档（issue #1055）；改动快照资源边界时优先跑对应测试文件。
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
| 40 | HTMLPreviewLoadPlanner | 嵌套页面的上级读取根目录被采用（**回归 #1009**） | 文件位于根目录的子目录，首选读取根为祖先目录 | 调用 `loadRequest(html:fileURL:readAccessRootURL:)` | 返回 `.file`，`readAccessURL` 为首选的祖先目录 | P1 | ✅ 已覆盖 | `ancestorReadAccessRootIsHonored` |
| 41 | HTMLPreviewLoadPlanner | 不包含文件的读取根目录回退到文件目录（**#1009 护栏**） | 首选读取根与文件无包含关系 | 调用同一入口 | 返回 `.file`，`readAccessURL` 为文件父目录 | P1 | ✅ 已覆盖 | `unrelatedReadAccessRootFallsBackToParent` |
| 42 | HTMLScreenshotterLimits | 普通页面在标准上限内 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `ordinaryPagesFit` |
| 43 | HTMLScreenshotterLimits | 页数超过上限的文档被拒绝 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `pageCountLimitRejectsEndlessDocument` |
| 44 | HTMLScreenshotterLimits | 单页高度超过单边上限被拒绝 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `tallPageIsRejected` |
| 45 | HTMLScreenshotterLimits | 总像素面积独立受限 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `pixelBudgetRejectsLargeArea` |
| 46 | HTMLScreenshotterLimits | 空几何在分配前被识别 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `emptyGeometryIsDetected` |
| 47 | HTMLScreenshotterLimits | 超限错误说明实际尺寸 | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `oversizeErrorIsDescriptive` |
| 48 | HTMLScreenshotterCapture | 超出配置上限的文档被拒绝 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `rejectsOversizedDocument` |
| 49 | HTMLPreviewLoadPlanner | 空 HTML 但有可读文件时直接加载文件（**回归 #1052**） | 文件可读且非空 | 调用 `loadRequest(html: "", fileURL:)` | 返回 `.file`，`readAccessURL` 为文件父目录 | P1 | ✅ 已覆盖 | `emptyHTMLWithReadableFileLoadsFileURL` |
| 50 | HTMLPreviewLoadPlanner | 空 HTML 且文件不可读时回退为空 HTML 文档 | 读取文件抛错 | 调用同一入口 | 返回 `.html`，base URL 为文件父目录 | P1 | ✅ 已覆盖 | `emptyHTMLWithUnreadableFileFallsBackToHTML` |
| 51 | HTMLPreviewLoadPlanner | 空 HTML 且无文件时保持空 HTML 文档 | — | 调用同一入口 | 返回 `.html(html: "", baseURL: nil)` | P2 | ✅ 已覆盖 | `emptyHTMLWithoutFileURLStaysHTML` |
| 52 | HTMLPreviewView | 仅在既无文本也无文件时显示空状态（**回归 #1052**） | — | 调用 `hasNoContent(htmlText:fileURL:)` | 仅 `("", nil)` 为真，其余组合为假 | P1 | ✅ 已覆盖 | `viewEmptyStateRequiresNoTextAndNoFile` |
| 53 | HTMLPreviewContentJavaScript | 预览配置禁用内容 JavaScript（**回归 #494**） | — | 调用 `HTMLPreviewWebViewFactory.makeConfiguration` | `allowsContentJavaScript == false` | P1 | ✅ 已覆盖 | `configurationDisablesContentJavaScript` |
| 54 | HTMLPreviewContentJavaScript | 内联事件处理器与 script 标签不得执行（**回归 #494**） | 用生产配置工厂构造 WebView | 加载含 onload / script 的 HTML | 两者均未执行 | P0 | ✅ 已覆盖 | `inlineHandlersAndScriptTagsDoNotRun` |
| 55 | HTMLPreviewContentJavaScript | 原生注入的选区桥接监听器仍正常触发（**#494 护栏**） | 内容 JS 已禁用 | 经 evaluateJavaScript 安装监听器并派发事件 | 监听器触发 | P1 | ✅ 已覆盖 | `nativeInjectedBridgeStillWorks` |
| 56 | HTMLPreviewLoadPlanner | 加载键未变化时跳过整文件读取（**回归 #1280**） | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `unchangedLoadKeySkipsFileRead` |
| 57 | HTMLPreviewLoadPlanner | 加载键变化时正常规划加载（**#1280**） | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `changedLoadKeyPlansLoad` |
| 58 | HTMLPreviewLoadPlanner | 加载键未变化时 Canvas 回退也不读盘（**#1280**） | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `unchangedCanvasFallbackSkipsFileRead` |
| 59 | HTMLScreenshotterOffMain | 在主 actor 之外把 PDF 栅格化为尺寸正确的位图 | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `rasterizesOffMain` |
| 60 | HTMLScreenshotterOffMain | 在主 actor 之外分配位图前拒绝超限 PDF | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `rejectsOversizedOffMain` |
| 61 | HTMLPreviewLegacySelectionScript | 发给助手的区块源码剔除宿主浮动按钮与遮罩（**回归 #495**） | 右键命中 data-block 区块后点击浮动按钮 | 捕获真实脚本回传载荷并检查 outerHTML | 不含 data-promo-floating / data-promo-highlight / 按钮文案 | P0 | ✅ 已覆盖 | `serializedBlockExcludesHostOverlays` |
| 62 | HTMLPreviewLegacySelectionScript | 发给助手的区块源码保留用户原始标记（**#495 护栏**） | 同上 | 经 `decodeLegacyMessageBody` 解码后检查 outerHTML | 以 section 标签开头、含 data-block="hero" 与原始 span | P1 | ✅ 已覆盖 | `serializedBlockKeepsOriginalDocumentMarkup` |
| 63 | HTMLScreenshotterCancellation | 取消快照必须在渲染前中止 | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `cancelledCaptureAbortsBeforeRendering` |
| 64 | HTMLPreviewPrototypeLinkScript | 热点点击回传声明的目标屏（**回归 #323**） | 注入原型跳转桥接脚本并桩接消息通道 | 点击 `[data-prototype-link="02-detail"]` | 回传 schemaVersion=1、action=prototypeLink、target=02-detail | P0 | ✅ 已覆盖 | `hotspotClickPostsDeclaredTarget` |
| 65 | HTMLPreviewPrototypeLinkScript | 装饰性子元素的点击解析到最近的热点（**#323**） | 嵌套热点：外层 00-home、内层 02-detail | 点击内层按钮内的 span | target=02-detail（最近祖先获胜） | P1 | ✅ 已覆盖 | `descendantClickResolvesNearestHotspot` |
| 66 | HTMLPreviewPrototypeLinkScript | 空白链接值不回传消息（**#323**） | `data-prototype-link` 为纯空白 | 点击该元素 | 捕获数组为空 | P1 | ✅ 已覆盖 | `blankTargetIgnored` |
| 67 | HTMLPreviewPrototypeLinkScript | 热点之外的点击不回传消息（**#323**） | 无 `data-prototype-link` 的普通区块 | 点击该区块 | 捕获数组为空 | P1 | ✅ 已覆盖 | `clickOutsideHotspotIgnored` |
| 68 | HTMLPreviewPrototypeLinkScript | 目标去除首尾空白并截断到 256 字符（**#323**） | 带 ` 02-detail ` 与 300 字符目标 | 分别点击 | 回传 02-detail 与 256 字符截断值 | P1 | ✅ 已覆盖 | `trimsAndBoundsTarget` |
| 69 | HTMLPreviewPrototypeLinkScript | 热点点击阻止锚点默认导航（**#323**） | `<a href="#fallback">` 热点 | 派发可取消 click 并检查 defaultPrevented | defaultPrevented == true | P1 | ✅ 已覆盖 | `preventsDefaultOnAnchorHotspot` |
| 70 | HTMLPreviewPrototypeLinkScript | dispose 移除监听且重注入保持单次回传（**#323**） | 注入 → dispose → 再注入 | dispose 后点击、再注入后点击 | dispose 后无消息；重注入后恰好 1 条 | P1 | ✅ 已覆盖 | `disposalAndReinjection` |
| 71 | HTMLPreviewPrototypeLinkRequest | 解码合法请求并保留导航代次（**#323**） | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `decodesValidRequest`（PrototypeLinkRequest） |
| 72 | HTMLPreviewPrototypeLinkRequest | 目标首尾空白被裁剪（**#323**） | — | 执行该用例 | 断言成立 | P2 | ✅ 已覆盖 | `trimsTarget` |
| 73 | HTMLPreviewPrototypeLinkRequest | 拒绝不支持的 schema 版本（**#323**） | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `rejectsUnsupportedVersion`（PrototypeLinkRequest） |
| 74 | HTMLPreviewPrototypeLinkRequest | 拒绝未知 action（**#323**） | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `rejectsUnknownAction`（PrototypeLinkRequest） |
| 75 | HTMLPreviewPrototypeLinkRequest | 拒绝空白目标（**#323**） | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `rejectsBlankTarget` |
| 76 | HTMLPreviewPrototypeLinkRequest | 拒绝超长目标（**#323**） | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `rejectsOversizedTarget` |
| 77 | HTMLPreviewPrototypeLinkRequest | 拒绝超限载荷（**#323**） | — | 执行该用例 | 断言成立 | P0 | ✅ 已覆盖 | `rejectsPayloadTooLarge` |
| 78 | HTMLPreviewPrototypeLinkRequest | 拒绝非对象载荷（**#323**） | — | 执行该用例 | 断言成立 | P1 | ✅ 已覆盖 | `rejectsInvalidJSON` |

> 说明：全部 **79 条场景**已在本包 `swift test` 中实跑通过（清单按用例名登记；`renderTimedOutDescription` 在 Capture 与 Timeout 两个套件各有一个同名用例，共表一行）。
> 用例名与描述取自 `Tests/` 下的真实 `@Test` 声明，改动测试时须同步本表。
> 变异验证（#494）：移除 `HTMLPreviewWebViewFactory` 的 `allowsContentJavaScript = false` 后，`configurationDisablesContentJavaScript` 与 `inlineHandlersAndScriptTagsDoNotRun` 转红（内联 onload 重新执行），`nativeInjectedBridgeStillWorks` 保持绿（桥接独立于该开关）；恢复后全绿。
> 变异验证（#495）：M1 把点击回传的 `cleanOuterHTML(el)` 改回 `el.outerHTML` 后，`serializedBlockExcludesHostOverlays` 转红（浮动按钮 `data-promo-floating` 与文案混入源码），`serializedBlockKeepsOriginalDocumentMarkup` 保持绿；M2 把 `cleanOuterHTML` 的返回值由 `clone.outerHTML` 改为 `clone.innerHTML` 后，`serializedBlockKeepsOriginalDocumentMarkup` 转红（丢失 section 外层标签与 `data-block`），`serializedBlockExcludesHostOverlays` 保持绿；两处恢复后全绿。

## 覆盖率统计

- P0: 已覆盖 12 / 12
- P1: 已覆盖 39 / 39
- P2: 已覆盖 11 / 11
- **合计: 62 / 62**（仅表示清单场景，非源码覆盖率）

## 优先级说明

- **P0**: 描述/名称含崩溃、泄漏、截断、丢失、竞态、超时、必须、不得、重试等失效类信号的用例（12 条）
- **P1**: 其余功能性用例（39 条）
- **P2**: 稳定常量、占位、文案、空集合等边界用例（11 条）

## 跨平台说明

- Package 声明: macOS 14+, iOS 17+
- 62 条用例位于 `Tests/`，需在目标平台执行 `swift test`

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
