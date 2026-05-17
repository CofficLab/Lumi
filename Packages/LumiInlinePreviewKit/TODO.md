# LumiInlinePreviewKit TODO

> 内嵌预览方案的全新实现：IOSurface 帧流 + 反向事件注入。
> 与 `LumiPreviewKit` 并行存在，不修改老代码。
> 总体设计参考 `Packages/LumiPreviewKit/TODO-EmbeddedPreview.md`（理论文档），本文件记录此包的阶段实现进度。

---

## Phase 1 — 内嵌显示通路（已完成）

目标：**只验证 IOSurface 显示路径在 Lumi 面板内可用**，不涉及子进程、渲染管线、事件转发。

- [x] `Package.swift`：库 + 子进程 executable + 测试 target
- [x] `LumiInlinePreviewFacade`：命名空间外壳
- [x] `IOSurfaceFrame`：跨进程帧描述符（surfaceID / 尺寸 / scale / seq）
- [x] `PreviewSurfaceView`：`NSView` + `CALayer.contents = IOSurface`
- [x] `PreviewSurfaceCanvas`：SwiftUI `NSViewRepresentable` 包装
- [x] `DemoSurfaceFactory`：主进程内 BGRA `IOSurface` 生成器（带 retain pool）
- [x] `LumiInlinePreviewHostApp/main.swift`：占位 stub（Phase 2 填充）
- [x] 单元测试：`IOSurfaceFrameTests` / `DemoSurfaceFactoryTests` / `PreviewSurfaceViewTests`（7/7 通过）
- [x] 插件 `EditorInlinePreviewPlugin`：底部面板 tab + Detail View + ViewModel
- [ ] **手动**：在 Xcode 里把此包加为 LumiApp 的 SPM 依赖（见下方）
- [ ] **手动**：在 Xcode 里把 `LumiApp/Plugins/EditorInlinePreviewPlugin/` 加入 LumiApp target

### 验收

进入 Editor，底部面板出现新 tab "Inline Preview"。点击 "Render Demo Frame"，
面板内显示一张彩色条纹 + 帧序号位图块，每次点击图像变化。

---

## Phase 2 — 子进程帧流（已完成最小切片）

> 当前阶段：**子进程渲染一段写死的 SwiftUI 动画 → 主进程持续接收 IOSurface 帧 → 在 Lumi 面板内显示**。
> 不接入 dlopen / 用户代码 / 编译管线 —— 那些是 Phase 2.5。

### 已实现

- [x] `Host/FrameStreamPolicy.swift`：`stopped / idle / interactive / animating`
- [x] `Host/HostMessages.swift`：`HostCommand` / `HostRequest` / `HostResponse` / `HostEvent` / `HostOutbound` envelope
- [x] `Host/InlineHostExecutableResolver.swift`：环境变量 / 主 bundle / SPM `.build` 三级查找
- [x] `Host/InlineHostConnection.swift`：协议 + `ProcessInlineHostConnection` 实现（按行解析 envelope，response/event 双通道）
- [x] `Engine/InlinePreviewSession.swift`：高层会话 API（start / startFrameStream / resize / setPolicy / stop）
- [x] 子进程 `HotPreviewRenderer.swift`：离屏 NSWindow + NSHostingView，BGRA `IOSurface` 快照（含 8 帧 retain pool）
- [x] 子进程 `HotPreviewRenderLoop.swift`：基于 `Timer` 的简易帧循环（idle 1fps / interactive 60fps）
- [x] 子进程 `HotPreviewDemoView.swift`：`TimelineView(.animation)` 写死动画
- [x] 子进程 `HotStdioPreviewHost.swift`：stdin 行解析、命令派发、stdout envelope 写出
- [x] 子进程 `main.swift`：`NSApp.setActivationPolicy(.accessory)` + run loop
- [x] 单元测试：`HostMessagesTests`（9 case）
- [x] **端到端集成测试** `InlineHostConnectionIntegrationTests`：spawn 真实子进程 → ping → startFrameStream → 收 ≥3 帧 → `IOSurfaceLookup` 跨进程解析 → 优雅关闭。**1.1s 内通过**。
- [x] 插件 ViewModel `EditorInlinePreviewViewModel`：组合 session + canvas resize 自动 forward 给 host
- [x] 插件 Detail View：`Demo Frame` / `Start Stream` / `Stop Stream` 三按钮 + 状态徽标

### 接入手册（在 Xcode 里完成的一次性步骤）

1. **加 SPM 依赖**：File → Add Package Dependencies → Add Local… → 选 `Packages/LumiInlinePreviewKit` → 把 product `LumiInlinePreviewKit` 加到 `Lumi` target。
2. **加插件源码**：右键 `LumiApp/Plugins` → Add Files… → 选 `EditorInlinePreviewPlugin/` 整个文件夹 → 加到 `Lumi` target。
3. **嵌入子进程二进制**（让生产构建能找到 host）：
   - 复制 `scripts/embed-editor-hot-preview-host.sh` 为 `scripts/embed-inline-preview-host.sh`，改三处：
     - `PRODUCT_NAME` → `LumiInlinePreviewHostApp`
     - 输入产物路径 → `Packages/LumiInlinePreviewKit/.build/.../LumiInlinePreviewHostApp`
     - 嵌入目标 → `Lumi.app/Contents/MacOS/LumiInlinePreviewHostApp`
   - 在 `Lumi` target 添加一条 Run Script Build Phase 调用此脚本，确保它在 "Copy Bundle Resources" 之后执行。
4. **开发期跳过嵌入**：直接在 scheme 的 Run → Arguments → Environment Variables 设置
   `LUMI_INLINE_PREVIEW_HOST_PATH = /<repo>/Packages/LumiInlinePreviewKit/.build/arm64-apple-macosx/debug/LumiInlinePreviewHostApp`
   `InlineHostExecutableResolver` 会优先采纳此变量。

### 验收（Phase 2）

1. 进入 Editor，底部面板 "Inline Preview"。
2. 点 **Demo Frame**：显示静态测试图（Phase 1 路径仍工作）。
3. 点 **Start Stream**：
   - 右上角徽标显示 `running · interactive`
   - 面板内出现持续动的渐变 + 浮动圆 + "Lumi Inline Preview / Phase 2 demo · subprocess SwiftUI"
   - 帧序号每秒 +60 左右
4. 调整窗口大小：surface 像素尺寸自动跟随，无明显模糊。
5. 点 **Stop Stream**：徽标回到 idle，最后一帧保留。
6. 关闭整个 Lumi：子进程随之退出（stdin EOF）。

---

## Phase 2.5 — 接入用户代码（手动 dylib 路径已完成，自动编译待开始）

目标：把"渲染写死 demo"换成"渲染当前文件的 `#Preview`"。
策略：先打通**任何 dylib 都能加载渲染**的运行时路径（2.5a），再接编译管线（2.5b）。

### 已实现 — 2.5a 运行时加载（已完成）

- [x] `HostCommand.loadDylib(path: String, symbolName: String)` / `unloadDylib`
- [x] `HostEvent.entryLoaded(success: Bool, message: String?)`
- [x] 子进程 `HotPreviewRenderer.loadDylib(path:symbolName:)`：`dlopen RTLD_NOW|RTLD_LOCAL` → `dlsym` → 调用 → `Unmanaged.fromOpaque().takeRetainedValue()` → `installView()`，老 dylib 延迟 1s 后再 `dlclose`（让旧 view 析构跑完，避开访问已 unmap 段）。
- [x] `HotStdioPreviewHost`：派发新命令；成功失败都推一条 `entryLoaded` 事件。
- [x] `InlinePreviewSession.loadDylib(path:symbolName:)` / `unloadDylib()` 高层 API；默认 symbol 用 `lumi_preview_make_nsview`，与老 `LumiPreviewKit.PreviewEntryBuilder.viewSymbolName` **完全一致**——Phase 2.5b 直接复用其编译产物零成本。
- [x] `EditorInlinePreviewViewModel`：`EntryStatus` 状态机（demo / loading / loaded / failed）+ `loadDylib(at: URL)` / `unloadDylib()`。
- [x] `EditorInlinePreviewDetailView`：`Load Dylib…` 文件选择器 + `Reset Demo` 按钮 + entry 状态徽标。
- [x] `Tests/Fixtures/PreviewDylibFixture.swift`：最小可加载 dylib 源（青色背景 + 绕圈黄圆 + `TimelineView` 动画）。
- [x] **新增 4 条单元测试**：`loadDylib` / `unloadDylib` 命令编解码、`entryLoaded` 事件成功失败两种 round-trip。
- [x] **新增 1 条端到端集成测试** `test_loadDylib_fixture_loadsAndProducesFrames`：测试运行时 `xcrun swiftc` 编译 fixture → spawn 子进程 → `loadDylib` → 收到 `entryLoaded(success: true)` + 至少一帧产出（**~2s 内通过**，无 swiftc 时 `XCTSkip`）。
- [x] **新增 1 条端到端集成测试** `test_loadDylib_missingFile_returnsErrorEvent`：错误路径同步 `success=false` + 异步 `entryLoaded(success: false)` + 子进程不挂、后续 ping 通。

### 验收（2.5a，手动）

1. `Start Stream` → 看到 demo 动画。
2. 终端编译 fixture：

   ```bash
   SDK=$(xcrun --show-sdk-path --sdk macosx)
   swiftc -emit-library -O -module-name PreviewDylibFixture \
     -sdk "$SDK" -target arm64-apple-macosx14.0 \
     -o /tmp/PreviewDylibFixture.dylib \
     Packages/LumiInlinePreviewKit/Tests/Fixtures/PreviewDylibFixture.swift
   ```
3. 点 **Load Dylib…** → 选 `/tmp/PreviewDylibFixture.dylib`：
   - 顶栏出现绿色 `entry · PreviewDylibFixture.dylib`
   - 画面切到青色背景 + 绕圈黄圆
4. 点 **Reset Demo**：恢复原 demo 动画，徽标消失。
5. 重复 3、4 多次：不应崩溃；老 dylib 延迟 dlclose 策略保证 view 析构完成。

### 已实现 — 2.5b 自动编译管线（已完成最小切片）

> 目标：用户打开 `.swift` 文件 + Cmd+S → 自动 build + 子进程加载用户 `#Preview`。

- [x] **SwiftPM 依赖**：`LumiInlinePreviewKit` 新增 `.package(path: "../LumiPreviewKit")` 本地依赖。仅 read-only 消费 `PreviewScanner` + `PreviewDiscovery`，**不修改老代码**。
- [x] `Build/InlinePreviewEntryGenerator.swift`：纯函数 `generate(for: PreviewDiscovery) -> String`，把 `bodySource` 包成 `@_cdecl("lumi_preview_make_nsview")` 导出函数。符号名与老 `PreviewEntryBuilder.viewSymbolName` 完全一致。
- [x] `Build/InlinePreviewBuilder.swift`：`actor`，流水线 scan → 选第 1 条 `PreviewDiscovery` → 生成 entry → 把"用户源 + entry"两个文件喂给 `xcrun swiftc -emit-library` → 缓存 (SHA256(path|source) → dylib URL，LRU = 8)。
- [x] `EditorInlinePreviewViewModel`：
  - `setActiveFile(_:sourceText:)` / `applySaveRevision(sourceText:)` / `updateBufferText(_:)` 三入口
  - `manualDylibActive` 标记：用户点 `Load Dylib…` 后冻结自动流程，避免被保存触发覆盖
  - `EntryStatus` 增加 `.building(file:)` 与 `.loaded(path: title:)`，UI 能区分编译中/加载中/已加载
  - `lastLoadedFingerprint` 去重，相同源不重复 dlopen
  - `startSession` 成功后回放 `autoBuildIfPossible()`，让先开 panel 再 Start Stream 的场景也能自动加载
- [x] `EditorInlinePreviewDetailView`：
  - `@EnvironmentObject var editorVM: EditorVM`
  - `.onAppear` / `.onChange(of: currentFileURL)` 推 `setActiveFile`
  - `.onChange(of: saveRevision)` 推 `applySaveRevision`（Xcode 风格保存触发）
  - `.onChange(of: contentRevision)` 推 `updateBufferText`（仅 stash，不重建）
  - 状态徽标 `building` 显示带 `ProgressView` 的橙色文本
- [x] **新增单元测试** `InlinePreviewEntryGeneratorTests`：3 case，覆盖符号名、缩进、空 body 兜底。
- [x] **新增端到端测试** `InlinePreviewBuilderTests.test_build_thenLoadDylib_endToEnd`（**1.7s 通过**）：写源文件 → builder.build → 缓存命中验证 → spawn 子进程 → loadDylib → 收到 `entryLoaded(success: true)` + 至少一帧。
- [x] **新增错误路径测试** `test_build_throwsNoPreviewFound_whenSourceHasNoPreview`：无 `#Preview` 时显式抛 `BuildError.noPreviewFound`。

### 验收（2.5b，手动）

1. Lumi 中打开任意 `.swift` 文件（含 `#Preview { ... }`）；进入 Inline Preview 面板。
2. 点 **Start Stream** —— 子进程起来后自动 build 当前文件，徽标依次显示 `building xxx.swift` →（编译完）`loading … .dylib` →（dlopen 完）`entry · Preview 1`，画面切到用户的预览。
3. 改 `#Preview` 体内代码（例如 `Text("Hello")` 改 `Text("World")`），按 `⌘S`：徽标走一遍 `building → loading → entry · Preview 1`，画面更新。
4. 反复保存相同内容：徽标只闪一下 `building`，秒回 `entry · …`（fingerprint 命中缓存，跳过 swiftc）。
5. 切到非 Swift 文件：自动卸载 dylib，回到内置 demo。
6. 点 **Load Dylib…** 手选一个 .dylib：进入 manual 模式，后续保存不再触发自动 build；点 **Reset Demo** 退出 manual 模式。

### 当前局限（已知，留 2.5c+ 处理）

- **不导入工程模块**：生成的 entry 只 import AppKit/Foundation/SwiftUI；`#Preview` 体内若引用工程内别的文件类型，目前必须把那些类型也写在同一个 `.swift` 文件里。Phase 2.5c 计划接入 `LumiPreviewKit.BuildPlanner` 解析模块路径与依赖文件后，可移除此限制。
- **swiftc 冷启 ~1s**：目前每个新指纹都跑一遍 `swiftc -O`；后续可改 `-Onone` + 模块缓存优化到 ~300ms。
- **首条 `#Preview` only**：扫到多个 `#Preview` 时仅取第一个；UI 切换不同 preview 待后续做。
- **interposeDylib 未做**：现在每次都 dlclose+dlopen，view state 重置；Phase 2.5c 用 `InterposingDylibLoader` 思路做"热替换符号、保活 view"。

---

## Phase 3 — 反向事件转发（已完成最小切片）

> 目标：**Live 模式可交互**——点 SwiftUI Button、滚 List、TextField 输入英文。
> 最小切片专注"路径打通 + 端到端不崩"，UI 体验微调（policy 自适应、TextField IME）留 3.5+。

### 已实现

- [x] `Models/PreviewInputEvent.swift`：跨进程事件 envelope（`.mouse / .scrollWheel / .key / .flagsChanged`），含独立 `ModifierFlags` OptionSet 与 `ScrollWheelEvent.Phase` 枚举，避免直接序列化 AppKit 类型。
- [x] `Models/PreviewInputEvent+AppKit.swift`：`ModifierFlags ↔ NSEvent.ModifierFlags`、`ScrollWheelEvent.Phase ↔ NSEvent.Phase` 双向 bridging（kit 内统一定义，host app 与主进程都可用）。
- [x] `Host/HostMessages.swift`：新增 `case forwardInputEvent(PreviewInputEvent)`。
- [x] 子进程 `HotPreviewEventDispatcher.swift`：把 envelope 合成 `NSEvent`（鼠标走 `NSEvent.mouseEvent`，滚轮走 `CGEvent(scrollWheelEvent2Source:)` + `NSEvent(cgEvent:)`，键盘走 `NSEvent.keyEvent`），调用 `window.sendEvent(_:)` 注入。
- [x] 子进程 `HotPreviewRenderer`：
  - 用 `InvisibleHostWindow: NSWindow` 子类，强制 `canBecomeKey/canBecomeMain == true`，让 keyDown 注入找得到 key window
  - `acceptsMouseMovedEvents = true` + `ignoresMouseEvents = false`
  - 启动时 `makeKeyAndOrderFront`；每次 `installView` 后 `makeFirstResponder(view)`，让键盘事件直达 SwiftUI 控件
- [x] 子进程 `HotStdioPreviewHost`：派发新命令到 `HotPreviewEventDispatcher`。
- [x] 主进程 `PreviewSurfaceView`：
  - `isInteractive: Bool` 总开关 + `onInputEvent: (PreviewInputEvent) -> Void` 回调
  - 全部覆写：`mouseDown/Up/Dragged/Moved` × {left,right,other} + `scrollWheel` + `keyDown/Up` + `flagsChanged`
  - `acceptsFirstResponder` / `acceptsFirstMouse` 跟随 `isInteractive`；点击时自动 `makeFirstResponder(self)` 拿键盘焦点
  - 用 `convert(event.locationInWindow, from: nil)` 把窗口坐标转成 view-local（与子进程 hosting view 同 point 尺寸，无须缩放）
- [x] 主进程 `PreviewSurfaceCanvas`：透传 `isInteractive` + `onInputEvent` 给底层 NSView。
- [x] 主进程 `InlinePreviewSession`：
  - `forwardInputEvent(_:) async throws -> HostResponse` 高层 API
  - `sendInputEventBestEffort(_:)` fire-and-forget 版本，给 mouseMoved / 高频事件用
- [x] `EditorInlinePreviewViewModel`：
  - `forwardInputEvent(_:)` 走 best-effort 转发
  - `isInteractive: Bool` 计算属性：`status == .running && entryStatus ∈ {building, loading, loaded}`
- [x] `EditorInlinePreviewDetailView`：把 `viewModel.isInteractive` + `viewModel.forwardInputEvent` 接到 `PreviewSurfaceCanvas`。
- [x] **新增 7 条单元测试** `PreviewInputEventTests`：mouse/scroll/key/flagsChanged Codable round-trip、ModifierFlags 与 ScrollWheelEvent.Phase 的 AppKit 互转、`forwardInputEvent` HostCommand 编解码。
- [x] **新增 1 条端到端集成测试** `InputForwardingIntegrationTests.test_forwardInputEvent_acceptsAllShapes_andKeepsSubprocessAlive`（**0.2s 通过**）：spawn 子进程 → startFrameStream → 连发 9 种事件（mouseDown/Up/Moved/Dragged + scrollWheel + keyDown/Up + flagsChanged ×2）→ 全部 `success == true` + 无 error 事件 + 后续 ping 仍通。

### 验收（手动）

1. 用 Phase 2.5b 的方式打开一个含 `#Preview { ... }` 的 .swift 文件，里面写带 `Button { count += 1 }` 的 SwiftUI 视图；保存。
2. 点 **Start Stream**，等到 `entry · Preview 1` 徽标变绿。
3. 点击 inline 面板里的 Button：计数应自增（每次保存后看到画面更新；后续 3.5 阶段做"无须保存即可看到 state 更新"的实时回流）。
4. 在 `List(...) { ... }` 上滚轮：列表滚动跟手。
5. 在 `TextField(text: $text)` 里点击 → 英文键盘输入：字符出现在文本框。

### 已知局限（留 3.5+ 处理）

- **Frame stream policy 没自适应**：当前一直跑 60fps；理想做法是收到输入事件触发 `.interactive`，N 秒静止后回 `.idle`。
- **TextField IME（中文输入）**：跨进程的 marked text / candidates 协议未实现，目前仅英文输入工作。
- **键盘焦点抢占**：子进程 `makeKeyAndOrderFront` 会让离屏窗口自认为 key window，但实际 OS 焦点仍在 Lumi 主窗口；多数情况 SwiftUI 的 firstResponder 链路能转发，但极端场景（含 `@FocusState` 的复杂表单）可能需要进一步调试。
- **Drag-and-drop / NSCursor / TouchBar**：未覆盖。
- **状态可视化未做**：没有 entry 内部 state 的回读，所以集成测试只验证"路径不崩"，不验证"事件改变了画面"——后者需要 entry 暴露状态读取符号。

---

## 不动的边界

- 不修改 `Packages/LumiPreviewKit/` 中任何文件。
- 不修改 `LumiApp/Plugins/EditorPreviewPlugin/` 中任何文件。
- 老路径 `EditorRemoteHotPreviewPlugin` 保持原样运行；用户可在底部面板里自由在两个 tab 之间切换比较体验。
