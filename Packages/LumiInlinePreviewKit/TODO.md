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
- SPM 跨 target 本地依赖已支持最小切片。
- 鼠标、滚轮、键盘、modifier 输入事件反向注入已完成最小实现。
- 输入后 frame policy 可从 idle 自动回到 interactive。
- Entry 可选调试状态回读已支持，用于自动化验证输入是否改变预览内部状态。
- `EditorInlinePreviewPlugin` 已使用插件专属磁盘目录，自动构建 workspace 位于插件目录下。

最近验证：

- `swift test --package-path Packages/LumiInlinePreviewKit`：75 tests passed。
- `xcodebuild -project Lumi.xcodeproj -scheme Lumi -configuration Debug -destination 'platform=macOS' build`：退出码 0，`BUILD SUCCEEDED`。

当前整体完成度估计：**92%**。

## 下一步 TODO

### P0

- [ ] **支持非 Swift 文件的预览**
  参考 `EditorPreviewPlugin`（老方案），当前插件只支持 Swift `#Preview` 预览，但老方案还支持以下文件格式。新方案需要在 `EditorInlinePreviewDetailView` 的画布区域根据文件类型切换显示内容，工具栏也应随之调整（隐藏 Start/Stop Stream 等不相关的控件）。
  - **图片预览**（png、jpg、jpeg、gif、tiff、tif、bmp、webp、svg、icns、ico、heic、heif）：用 `NSImage(contentsOf:)` 加载，居中显示，展示尺寸和文件大小信息，棋盘格透明背景。参考 `EditorPreviewImageView.swift`。
  - **Markdown 预览**（md、markdown）：用 `MarkdownKit` 的 `MarkdownBlockRenderer` 渲染，支持标题/代码块/表格/引用等。参考 `EditorPreviewMarkdownView.swift`。
  - **String Catalog 预览**（xcstrings）：用 `StringCatalogKit` 解析 `.xcstrings` 文件，左侧语言列表 + 右侧键值对照表，高亮占位符。参考 `EditorPreviewStringCatalogView.swift`。
  - 需要在 `EditorInlinePreviewViewModel` 中增加文件类型判断逻辑（`isImageMode` / `isMarkdownMode` / `isStringCatalogMode`），监听 `currentFileURL` 变化时自动切换模式。
  - 非预览模式下应停止子进程以节省资源。

- [ ] **移除普通用户可见的手动 dylib 调试入口**
  - 移除 `EditorInlinePreviewDetailView` 里的 `Load Dylib...` / `Reset Demo` 按钮。
  - 清理 `EditorInlinePreviewViewModel` 里的 `manualDylibActive` 手动模式逻辑。
  - 保留必要的测试辅助 API，但不要暴露到普通 UI。

- [ ] **真实项目压测外部 package / workspace 依赖**
  - 用 Lumi 自己的复杂 SwiftPM/Xcode 项目文件测试自动预览。
  - 重点验证外部 package import、Xcode workspace 派生路径、resource bundle、module search path、link inputs。
  - 失败时把错误准确映射到 UI，不允许静默 fallback 到 standalone 编译。

- [ ] **完善构建失败体验**
  - UI 展示 swiftc/build planner 的关键错误信息。
  - 区分 no preview、编译失败、依赖解析失败、dlopen 失败。
  - 保留上一帧成功预览，避免失败时直接清空画面。

### P1

- [ ] **实现 interpose / 热替换，减少 view state 重置**
  - 当前每次刷新仍是 `dlclose + dlopen`，SwiftUI view state 会重置。
  - 目标是复用 `InterposingDylibLoader` 思路，热替换符号并尽量保活 view/state。

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
  - UI 展示当前 entry 的状态摘要、最后一次构建时间、缓存命中、当前 policy。
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
