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

<!-- T2 及后续任务完成后在此追加 -->
