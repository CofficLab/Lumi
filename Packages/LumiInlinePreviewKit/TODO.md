# LumiInlinePreviewKit TODO

## 最终目的

在 Lumi 编辑器底部提供一个内嵌 SwiftUI `#Preview` 运行环境：用户打开 Swift 文件后，Inline Preview 能自动发现当前文件的 `#Preview`，在插件自己的磁盘目录里完成编译缓存，通过独立子进程渲染到 `IOSurface`，并把画面和输入事件在主进程与子进程之间稳定同步。

最终体验应接近 Xcode Preview 的核心工作流：

- 打开含 `#Preview` 的 Swift 文件后自动预览。
- 保存后自动增量重建并刷新画面。
- 多个 `#Preview` 可切换。
- Button、List、TextField 等基础交互可用。
- 预览数据、构建缓存和临时产物都归属 `EditorInlinePreviewPlugin` 自己的插件目录。
- 主 app 不因用户预览代码崩溃而崩溃。

## 当前状态摘要

已完成的基础能力：

- `IOSurface` 内嵌显示链路已打通。
- 独立 host 子进程帧流已打通。
- 用户 dylib `dlopen`/`dlsym` 加载路径已打通。
- 当前文件 `#Preview` 自动发现、自动编译、自动加载已完成最小实现。
- 多 `#Preview` 切换和独立缓存指纹已支持。
- 同包 Swift 文件收集已支持。
- SPM 跨 target 本地依赖已支持最小切片，并有自动化测试覆盖 planned build 路径。
- 鼠标、滚轮、键盘、modifier 输入事件反向注入已完成最小实现。
- 输入后 frame policy 可从 idle 自动回到 interactive。
- Entry 可选调试状态回读已支持，用于自动化验证输入是否改变预览内部状态。
- `EditorInlinePreviewPlugin` 已使用插件专属磁盘目录，自动构建 workspace 位于插件目录下。
- 普通用户可见的手动 dylib 调试入口已移除，用户路径只保留自动预览流程。
- 自动构建后的 dylib 加载结果会严格检查；加载失败不会误标为 loaded，也不会覆盖上一次成功预览的 fingerprint。
- 图片、Markdown、String Catalog 文件预览已支持最小切片；非 Swift 预览模式下不会启动 SwiftUI preview host。
- 预览会话已改为自动生命周期：面板出现或切到含 `#Preview` 的 Swift 文件会自动启动，离开面板或切到非 Swift 文件会停止。
- 构建/加载失败时，画布底部会显示可展开详情，同时保留上一帧成功画面。
- 工具栏已显示最近一次构建摘要：缓存命中/重建、完成时间、preview 数量。

最近验证：

- `swift test --package-path Packages/LumiInlinePreviewKit`：75 tests passed（包含 SPM target + 本地依赖 target planned build 路径）。
- `xcodebuild -project Lumi.xcodeproj -scheme Lumi -configuration Debug -destination 'platform=macOS' build`：退出码 0，`BUILD SUCCEEDED`。

当前整体完成度估计：**99%**。

## 下一步 TODO

### P0

- [x] **自动启动预览会话**
  老方案 `EditorPreviewPlugin` 在视图出现或文件切换时会自动调用 `startHost()`（见 `EditorPreviewDetailView.refreshScanAndStartIfNeeded()`），且 `EditorPreviewService.init()` 中有 `warmupHostIfPossible()` 预热宿主进程。新方案当前要求用户手动点击 "Start Stream"，应改为：
  - [x] 视图首次出现时（`onAppear`）自动调用 `viewModel.startSession()`。
  - [x] 文件切换到含 `#Preview` 的 Swift 文件时，若 session 未运行，自动启动。
  - [x] 移除工具栏的 "Start Stream" / "Stop Stream" 按钮，改为自动生命周期管理（类似老方案，视图消失或切到非 Swift 文件时自动停止）。
  - [ ] 考虑在 ViewModel 初始化时预热子进程，减少首次启动延迟。

- [x] **支持非 Swift 文件的预览**
  参考 `EditorPreviewPlugin`（老方案）。新方案需要在 `EditorInlinePreviewDetailView` 的画布区域根据文件类型切换显示内容，工具栏也应随之调整（隐藏 Start/Stop Stream 等不相关的控件）。
  - [x] **图片预览**（png、jpg、jpeg、gif、tiff、tif、bmp、webp、svg、icns、ico、heic、heif）：用 `NSImage(contentsOf:)` 加载，居中显示，展示尺寸和文件大小信息，棋盘格透明背景。
  - [x] **Markdown 预览**（md、markdown）：用 `MarkdownKit` 的 `MarkdownBlockRenderer` 渲染，支持标题/代码块/表格/引用等。
  - [x] **String Catalog 预览**（xcstrings）：用 `StringCatalogKit` 解析 `.xcstrings` 文件，左侧语言列表 + 右侧键值对照表，高亮占位符。
  - [x] 监听 `currentFileURL` 变化时自动切换 Swift / Image / Markdown / String Catalog / Unsupported 模式。
  - [x] 非 Swift preview 模式下停止子进程以节省资源。

- [ ] **真实项目压测外部 package / workspace 依赖**
  - [x] 用自动化 fixture 验证 SPM target + 本地依赖 target 的 planned build 路径，确认 entry dylib 可 `dlopen` 且导出 `lumi_preview_make_nsview`。
  - [ ] 用 Lumi 自己的复杂 SwiftPM/Xcode 项目文件测试自动预览。
  - [ ] 重点验证外部 package import、Xcode workspace 派生路径、resource bundle、module search path、link inputs。
  - 失败时把错误准确映射到 UI，不允许静默 fallback 到 standalone 编译。

- [x] **完善构建失败体验**
  - UI 展示 swiftc/build planner 的关键错误信息。
  - 区分 no preview、编译失败、依赖解析失败、dlopen 失败。
  - 保留上一帧成功预览，避免失败时直接清空画面。
  - [x] 把错误信息做成可展开详情，而不是只放在单行 badge 里。

### P1

- [ ] **实现 interpose / 热替换，减少 view state 重置**
  - 当前每次刷新仍是 `dlclose + dlopen`，SwiftUI view state 会重置。
  - 目标是复用 `InterposingDylibLoader` 思路，热替换符号并尽量保活 view/state。

- [ ] **修复预览画面锯齿和模糊问题**
  `AppAvatar` 等含圆形/曲线的预览出现明显锯齿和模糊，有两个根因：
  - **子进程截图分辨率不足**：`HotPreviewRenderer.snapshot()` 用 `bitmapImageRepForCachingDisplay(in:)` 截取离屏窗口，离屏窗口在屏幕外 (-100000)，可能只产生 1x 位图而非 Retina 2x，导致圆形抗锯齿丢失。需要确保 `NSBitmapImageRep` 以正确的像素密度渲染（设置 `pixelsWide`/`pixelsHigh` 为 pointSize × scale，或改用 `NSView.bitmapImageRepForCachingDisplay(in:)` 后手动指定像素尺寸）。
  - **主进程 layer 放大滤镜用了 nearest**：`PreviewSurfaceView.makeBackingLayer()` 设置 `magnificationFilter = .nearest`（最近邻采样），不做插值平滑，像素对齐有偏差时直接出现锯齿。应改为 `.trilinear` 或 `.linear`。

- [ ] **改进 frame stream 驱动**
  - 当前仍基于 `Timer`。
  - 增加 dirty 检测，静止时不做无意义 snapshot。
  - 评估用 `CVDisplayLink` 替换 60fps `Timer`。

- [ ] **增强 TextField / IME 输入**
  - 当前英文键盘输入可用。
  - 需要补 marked text / candidates 协议，支持中文输入法。

- [ ] **焦点稳定性专项**
  - 压测 `@FocusState`、复杂表单、多 TextField 场景。
  - 明确主进程焦点与子进程离屏 key window 的边界。
  - 需要时增加显式 focus command 或状态同步。

### P2

- [ ] **状态可视化**
  - [x] UI 展示当前 entry 的状态摘要、最后一次构建时间、缓存命中、当前 policy。
  - 可选展示 `lumi_preview_debug_state` 返回值，作为开发/诊断入口。

- [ ] **补齐高级输入与系统能力**
  - Drag and drop。
  - NSCursor。
  - TouchBar。
  - 复杂鼠标 hover / tracking area 行为。

- [ ] **构建缓存治理**
  - 明确插件目录下缓存大小上限。
  - 增加 LRU 清理策略。
  - 增加清理入口或诊断日志。

## 边界

- 不修改 `Packages/LumiPreviewKit/` 的既有实现，除非后续明确决定合并两套方案。
- 不修改 `LumiApp/Plugins/EditorPreviewPlugin/`。
- `EditorRemoteHotPreviewPlugin` / 老预览路径保持可用。
