# BookletMaker iOS 重构实施记录（T0–T9 滚动更新）

> 对应实施计划：`docs/plans/2026-09-07-booklet-maker-ios-redesign.md`
> 本文件按任务滚动记录环境、验证命令、结果、截图与未解决问题。每个任务完成后更新对应章节。

---

## T0. 基线（2026-09-07）

### 环境

| 项目 | 值 |
|---|---|
| 主机 | macOS（Apple Silicon, arm64） |
| Xcode | 26.6（Build 17F113） |
| Swift | 6.3.3（swiftlang-6.3.3.1.3） |
| 模拟器运行时 | iOS 26.5（已启动 iPhone 17 Pro） |
| 最低部署目标 | iOS 17.0（xcconfig `IPHONEOS_DEPLOYMENT_TARGET = 17.0`） |
| 分支 | dev，基线 commit `e16969ca0` |

### 测试基线

在仓库根目录执行：

```bash
swift test --package-path Packages/PluginBookletMaker
swift test --package-path Packages/FactoryBookletMaker
```

结果：

- **PluginBookletMaker**：31 个 XCTest + 2 个 Swift Testing（`BookletMakerPluginTests`），0 失败。
- **FactoryBookletMaker**：6 个测试（KernelFactory / Default Factories），0 失败。

### 构建基线

```bash
xcodebuild -project Lumi.xcodeproj -scheme BookletMaker \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /tmp/bookletmaker-t0-ios-build \
  -disableAutomaticPackageResolution CODE_SIGNING_ALLOWED=NO build
```

- 首次尝试因远程 Swift 包（mysql-nio）下载中途网络中断（`curl 18 / early EOF`）失败，属环境瞬时问题。
- 后续多次重试仍在其他远程包（约 5156 objects 的依赖）下载时中断；已配置 git `http.version=HTTP/1.1`、`http.postBuffer`、`http.lowSpeedLimit/Time` 后继续重试。**iOS Simulator 构建结果：待更新**（远程依赖下载受限，尚未获得完整构建结论）。
- macOS 侧 `swift build --package-path Packages/PluginBookletMaker`：**BUILD SUCCEEDED**（T1 改动后验证）。

### 基线测试文件

生成于 `docs/plans/artifacts/2026-09-07-ios-redesign/`：

| 文件 | 用途 |
|---|---|
| `baseline-8pages.pdf` | 8 页：折叠装订 → 2 张纸 / 4 打印面，页序 [8,1]/[2,7]/[6,3]/[4,5] |
| `baseline-5pages.pdf` | 5 页：折叠装订 → 补 3 页空白，2 张纸 / 4 面 |
| `baseline-24pages.pdf` | 24 页：拆分 8、16 → 1–8 / 9–16 / 17–24 |
| `baseline-1page.pdf` | 1 页：拆分入口解释场景 |
| `baseline-100pages.pdf` | 100 页：性能与懒加载场景 |

生成方式：CoreGraphics 逐页填充纯色块（`swift /tmp/make_baseline_pdfs.swift`），非真实文字内容，仅用于几何/页序基线。

### 源码风险核验（对照计划 §2.3）

以下为只读代码核验结论，未启动模拟器复现运行表现：

- **P0-导出未接线**：`BookletMakerIOSApp` 仅调用 `loadPDF`、`makeContentView`、`makeSettingsView`；`feature.export()`、`selectedTool` 切换无 UI 入口。已确认。
- **P0-importer 忽略失败**：App 侧 `fileImporter` 回调 `guard case .success` 后直接 `loadPDF`，无失败处理路径。已确认。
- **P0-isWorking 定义**：`BookletMakerMobileFeature.isWorking` 只看 `viewModel.isRendering`，而共享 `isBusy` 包含 `isPreparingPreview`。已确认。
- **P0-renderer 非 throwing 流**：`BookletRenderer.render` 返回 `AsyncStream<Double>`，错误只写日志；VM 以 `fileExists` 推断成功。已确认。
- **P0-splitter detached 取消传播**：`PDFSplitter.split` 在 `Task.detached` 内执行，外层 `splitTask?.cancel()` 只取消等待方，detached worker 靠 `Task.isCancelled` 自检（可传播，但取消后清理依赖抛出路径）；外层无显式 handler。需 T1 测试覆盖。
- **P0-SharePresenter 全局窗口**：`SharePresenter` 通过 `UIApplication.shared.connectedScenes` 查找 keyWindow，无 popover 锚点。已确认。
- **P1-预览示意**：`SheetPreviewView` 为左右分栏 + 非滚动 VStack 纸张列表，窄屏长文档有溢出风险（未运行复现）。已确认代码结构。
- **P1-渲染内存**：`BookletRenderer` 将完整输出写入 `NSMutableData`。已确认。

---

## T1. 修复共享导出结果与取消协议（2026-09-07）

### 改动

- 新建 `Sources/Models/PDFExportJob.swift`：`PDFExportJob`（作业 ID、文档 ID、源 URL、booklet 设置 / split 输出快照、输出目录）与 `PDFExportResult`（作业 ID + 实际结果 URL 数组）。
- `Sources/Services/BookletRenderer.swift`：新增 `BookletRendering` 协议；`render` 从非 throwing `AsyncStream<Double>` 改为 `async throws -> URL` + 进度回调；外层取消通过 `withTaskCancellationHandler` 显式传播到 detached worker；写入失败删除半成品并抛 `RenderError`。
- `Sources/Services/PDFSplitter.swift`：新增 `PDFSplitting` 协议；同样的显式取消传播；每页复制与写入前检查取消；失败/取消时清理已完成部分。
- `Sources/ViewModels/BookletMakerViewModel.swift`：init 支持注入 renderer/splitter（测试替身）；新增 `activeExportJobID` 作业隔离与 `isCancelling`；`export`/`exportSplit` 成功只能来自服务明确返回；旧任务晚完成/晚失败不能覆盖新任务状态；`loadPDF`/`clear` 使旧作业失效；缩略图准备与导出成功分离，缩略图失败不推翻成功；`cancel()` 区分用户取消与内部切换。
- 测试：`BookletMakerViewModelTests` 增加 `ControlledRenderer`/`ControlledSplitter` 替身与 5 个新用例（晚完成不覆盖、取消无成功、失败传递、拆分取消后新任务干净完成）；`BookletRendererIntegrationTests` 适配新签名并新增取消无残留、写入失败抛错；`PDFSplitterTests` 新增取消清理部分输出、写失败清理已完成文件。

### 验证

- `swift test --package-path Packages/PluginBookletMaker`：**39 XCTest + 2 Swift Testing，0 失败**。
- `swift build --package-path Packages/PluginBookletMaker`（macOS）：**BUILD SUCCEEDED**。
- 既有 macOS 调用路径（`BookletMakerPlugin.presentSavePanel` / `presentSplitDirectoryPanel`）签名未变，无需修改。
- 未做：整仓 iOS Simulator 构建（受远程依赖下载网络问题阻塞，见 T0）。

### 验收对照（计划 T1 验收）

- 正常导出正确：通过（既有 + 新增测试）。
- 取消后无成功跳转、无旧结果污染、无持续写入：通过（VM 作业隔离 + 服务取消传播测试）。
- macOS 回归：包测试与构建通过。

---

## T2. 移动会话与可靠导入（2026-09-07）

### 改动

- 新建 `Sources/Mobile/MobileDocumentStore.swift`（@MainActor）：每个会话一个唯一目录（`Caches/BookletMakerMobile/<uuid>/`，inbox 与 output 子目录）；`importPDF` = 打开安全作用域 → 后台 detached 复制到 `inbox/.candidate` → inspector 检查 → 成功 move 为原文件名（保留用户文件名）→ 失败删除 candidate 且不触碰旧文档；`clearSession()` / `cleanupStaleSessions(keeping:)`。
- 新建 `Sources/Mobile/MobileWorkspaceState.swift`：`Phase`（welcome/importing/ready/generating/cancelling/resultReady/failed）、`Tool` 路由、单一 `Presentation` 枚举（bookletOptions/splitBatchInput/splitRename/splitRename(PDFSplitSegment)/help/shareBooklet(URL)/shareSplit([URL])/saveBooklet(URL)/saveSplit([URL])）。
- 测试：`MobileDocumentStoreTests`（5 用例，含 corrupt/missing 文件断言失败无残留、文件名保留）与 `MobileWorkspaceStateTests`（7 用例）。

### 验证

- `swift test --package-path Packages/PluginBookletMaker`：51 个测试全过。
- 提交：`d021aec3b`。

---

## T3. 新根导航、欢迎页与文档概览（2026-09-07）

### 改动

- `Sources/Mobile/BookletMakerMobileFeature.swift` 重写为 public @MainActor ObservableObject：public `Tool` 枚举（split/booklet，title/systemImage）、viewModel/workspace/documentStore、观察者驱动 objectWillChange、`sessionErrorMessage`；`openSampleDocument` / `importDocument(from:)` / `closeDocument` / `dismissSessionError`；`exportBooklet` 导出到临时目录后分享，`exportSplit` 导出到 `outputDirectory/split-<uuid>` 后分享（T7 改为结果页驱动）。
- 新建 `BookletMakerMobileRootView.swift`（唯一 NavigationStack + 根级 `fileImporter(.pdf)`）、`BookletWelcomeView.swift`（ContentUnavailableView + Open PDF / Use Sample PDF + session 错误 banner）、`PDFDocumentOverviewView.swift`（文件信息 + 首页缩略图 + 两个工具 NavigationLink + 工具栏菜单）。
- App 入口瘦身：`BookletMakerIOSApp.swift` 仅 `FactoryBookletMakerIOS.makeMobileRootView()`；Factory 新增 `makeMobileRootView()`。RootView 因被 Factory 引用改为 public。
- 修过一轮：`public var selectedTool` 直接暴露 workspace 内部类型报 internal 类型错误，改为 get/set 双 switch 桥接。

### 验证

- PluginBookletMaker 与 FactoryBookletMakerIOS 的 xcodebuild iOS Simulator 构建均 `BUILD SUCCEEDED`。
- macOS 51 测试过。
- 提交：`604d6ad8f`。

---

## T4. 拼版预览与原稿阅读（2026-09-07）

### 改动

- 新建 `Sources/Models/BookletStage.swift`（printLayout/paperSelection/cuttingMarks/bindingEffect/review/export，stepNumber 1–6）+ 测试 `BookletStageTests.swift`。
- `BookletLayoutEngine.swift` 新增共享显示度量（paperDisplaySize/landscapePaperDisplaySize/displayUnit），macOS `SheetPreviewView` 复用。
- 新建 `BookletPreviewStageView.swift`（第一版：stageIndicator、summaryCard、paperPickerCard、outputSideCard 网格 + sideBadge 前后标 + pairCaption）与 `SourcePDFReadingView.swift`（真页只读、MagnificationGesture 1–5x 缩放 + 双方向 pan、页导航 + confirmationDialog 跳页）。
- `BookletPreviewMobileView.swift` 重建：layout/source 分段 + 底部 summary/Make Booklet/Cancel 栏（isBusy 时 ProgressView(value:)+Cancel，isCancelling 文案）。

### 验证

- 包 iOS 构建成功；macOS 51+3 测试过。
- 提交：`5f4440f27`。

---

## T5. 拆分浏览、输入与命名（2026-09-07）

### 改动

- `PDFSplitSegment` 增加 `rangeLabel`（单页 "Page %lld"，多页 "Pages %lld–%lld"）。
- 新建 `PDFSplitPlanEditorView.swift`：批量分隔输入卡片（TextField 绑定 splitCutPointsText）、页序卡片（≤10 页缩略图网格 3 列点击 toggleSplit + 剪刀角标；>10 页紧凑行列表）、命名卡片（每段 rangeLabel + TextField 绑定 stem）。
- `PDFSplitMobileView.swift` 重建：plan/source 分段 + 底部 summary（"Add at least one split" / "%lld pages → %lld files"）+ Split/Cancel 栏。
- 测试新增：`testDuplicateSplitFileNamesAreRejected`、`testSplitSegmentRangeLabel`。

### 验证

- macOS 56 测试全过；iOS 构建成功。
- 提交：`d5903789f`。

---

## T6. 原生参数、装订效果与帮助（2026-09-07）

### 改动

- 新建 `BookletParameterPanelView.swift`：Output（Paper Picker/Layout Picker）、Spacing（Margin/Gutter Slider 0–30 步进 1，值 "%lld mm"）、Print Options（Add cut marks / Pad with blank page Toggle，bookletFold 时 pad 禁用）。
- 新建 `BookletBindingEffectView.swift`：bookletFold 时 rotation3DEffect 折叠动画（foldAngle 0–180 Slider + Play fold 按钮 1.6s linear 动画，left 页绕 trailing 轴转 -foldAngle，right 页固定宽 100；PDFDocumentPageView 100×140）；simplePair 并排示意；说明文案按 layout 切换。
- 新建 `BookletHelpMobileView.swift`：List 四 Section（Make a Booklet / Split a PDF / Privacy / About，About 含 CFBundleShortVersionString/CFBundleVersion）。
- `BookletPreviewStageView.swift` 重写为六阶段导航（横向 ScrollView + step 按钮 + switch 分发）：.printLayout 原拼版网格；.paperSelection/.cuttingMarks 参数面板；.bindingEffect 装订效果；.review/.export 参数 reviewRow 列表 + summaryCard + Make Booklet（onExport）。init 改为 `(viewModel:onExport:)`。
- `BookletPreviewMobileView.swift` 传 onExport 给 StageView；帮助入口接入欢迎页与文档菜单。

### 验证

- 包 iOS 构建 `BUILD SUCCEEDED`；macOS 56 测试过。
- 提交：`0c6973408`。

---

## T7. 完整结果页、保存与分享（2026-09-07）

### 改动

- Feature 增加导出结果状态机 `exportOutcome`（.success(urls) / .failure(message)）；导出完成后结果页在根视图以 sheet 呈现；取消导出不显示结果页。
- 新建 `BookletExportResultMobileView.swift`：成功展示每个产物（PDFDocumentPageView 缩略图、文件名、ByteCountFormatter 大小、页数）+ Share / Save to Files / Done；失败展示原因 + Done。
- `SharePresenter` 重构：新增 SwiftUI 可嵌入多文件 `ShareSheet`（UIViewControllerRepresentable，经 `.sheet` 呈现，不再查找前台窗口）；旧窗口查找路径与旧 iOS 插件分支在 T9 一并移除。
- 单文件保存走系统 `fileExporter`（保留输出文件名），多文件保存走 ShareSheet（系统含"存储到文件"）。

### 验证

- 包 iOS 构建 `BUILD SUCCEEDED`；macOS 56 测试过。
- 提交：`e5dcb985e`。

---

## T8. iPad、性能、本地化与无障碍（2026-09-07）

### 改动

- iPad 宽屏：RootView 在 regular 尺寸类且处于文档阶段时用 `NavigationSplitView`（侧栏 = 文档信息 + 两个工具按钮，详情 = 工具页）；折叠/展开只影响外观，feature 唯一，不复制路径或 VM。工具切换用显式两行 Button（规避 `List(selection:)` + ForEach 的类型推断问题）。
- 拼版网格列数随尺寸类自适应（iPad 3 列）。
- 本地化：为 65 个新增字符串补 en/zh-Hans/zh-HK/zh-TW 翻译（xcstrings 224 keys）；归一化与既有 key 符号冲突的条目（`BookletMaker`→既有 `Booklet Maker`、`Cut marks`→`Cut Marks`、`Pages %lld + %lld`→`Pages %lld and %lld`、`%lld°`→`%lld degrees`）。
- 无障碍：图标控件补 accessibilityLabel；动态字体与对比度沿用系统默认。

### 验证

- 包 iOS 构建 `BUILD SUCCEEDED`（修复 xcstrings 符号冲突与 ForEach 推断问题后）；Factory iOS 构建 `BUILD SUCCEEDED`；macOS 56 测试过。
- 提交：`eeaeee0e3`。

---

## T9. 集成测试、清理与交付（2026-09-07）

### 改动

- 清理：`BookletMakerPlugin` 的旧 iOS 分支（presentSavePanel/presentSplitDirectoryPanel 的 `#else` 分享面板路径）移除，方法仅保留 macOS 实现；`SharePresenter.share(fileURL:)`（窗口查找路径）移除；`BookletMakerMobileFeature.makeSettingsView()` 与 `BookletMakerMobileSettingsView.swift`（旧控件路径，无引用）删除。
- 新增 iOS UI 测试 target：`BookletMakerUITests`（`com.apple.product-type.bundle.ui-testing`，TEST_TARGET_NAME=BookletMaker，bundle id `com.coffic.bookletmaker.uitests`，SWIFT_VERSION 6.0，部署目标 17.0）；`BookletMaker.xcscheme` TestAction 挂载该测试（此前为空）；`BookletMakerUITests/BookletMakerIOSFlowTests.swift` 覆盖：欢迎页 → Use Sample PDF → 概览工具入口、拼版预览六阶段导航。
- 整仓 iOS Simulator App 构建此前多轮因远程 SwiftPM 依赖下载中断失败；T9 重试已成功：**`BUILD SUCCEEDED`**（`/tmp/ios-build-t9.log`），环境网络问题已恢复，不作为代码结论。

### 验证

- macOS：`swift test --package-path Packages/PluginBookletMaker` **56 tests, 0 failures**。
- 包级 iOS 构建：PluginBookletMaker 与 FactoryBookletMakerIOS 均 `BUILD SUCCEEDED`。
- 整仓 App iOS Simulator 构建：`BUILD SUCCEEDED`（`EXIT=0`）。
- UI 测试（新增 `BookletMakerUITests` target，scheme TestAction 挂载）：
  - `testSamplePDFOpensOverviewWithTools` **passed**（8.6s）：欢迎页 → Use Sample PDF → 概览两个工具入口。
  - `testBookletPreviewStagesNavigable` **passed**（14.2s）：进入拼版 → 六阶段导航 → 纸张阶段原生参数面板 → 返回打印布局。
  - 环境故障记录：首次运行因 CoreSimulator 设备克隆卡死（`Failed to clone device ... stuck in creation state`）失败，属模拟器服务状态问题；`shutdown all` + 重启 CoreSimulatorService + scheme `parallelizable=NO`（禁用并行设备克隆）后通过。
  - 断言全部基于稳定 accessibilityIdentifier（`welcome.useSample` / `overview.bookletTool` / `overview.splitTool` / `stage.1…6`），不依赖文本语言与截图坐标。
- 手工验收（系统 UI，不做自动化伪装）：文件选择器（fileImporter）、第三方 File Provider、系统分享面板目标选择、实体打印效果。

### 提交

- `e16969ca0`（计划 baseline）→ `3c6c368e9`（T0）→ `8acdd835d`（T1）→ `d021aec3b`（T2）→ `604d6ad8f`（T3）→ `5f4440f27`（T4）→ `d5903789f`（T5）→ `0c6973408`（T6）→ `e5dcb985e`（T7）→ `eeaeee0e3`（T8）→ T9（本文档提交时）。

