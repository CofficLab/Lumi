# 内嵌预览改造 TODO（Embedded Preview Refactor）

> 本文档定义把当前"独立浮动 Live 窗口"改造为"内嵌 IOSurface + 反向事件注入"的完整执行计划。
> 接到此文档的实现者应按 Phase 1 → 2 → 3 → 4 顺序推进，每个 Phase 均能独立合并、独立可用。

---

## 0. 目标与非目标

### 目标

- **保留 Image 模式与 Live 模式两种用户可见模式**。
- **Live 模式体验对齐 Xcode Previews**：60fps 动画、可点击、可滚动、可输入英文、子进程崩溃不影响 Lumi。
- **彻底删除"独立浮动 NSPanel"机制**：Live 内容完全嵌入 Lumi 自身预览面板。
- **两种模式共用同一个显示控件**（`PreviewSurfaceView`），仅切换"帧率 + 是否转发事件"。

### 非目标（v1 不做，留作后续增强）

- 中文 / 日文 IME 输入到预览（需 `NSTextInputClient` 跨进程，单独立项）。
- `.sheet` / `.popover` / `.alert` 在预览中可见（需多 surface 合成，单独立项）。
- 跨进程拖拽（Drag & Drop）。
- 鼠标光标跨进程同步（按钮 hover 变手等）。
- iOS 模拟器集成、设备变体（不适用，本预览仅服务于 macOS UI）。

---

## 1. 总体架构

```
Lumi 主进程                              子进程 (LumiHotPreviewHostApp)
┌────────────────────────────┐          ┌─────────────────────────────────┐
│ HotPreviewCanvas (SwiftUI) │          │ HotPreviewRenderer              │
│   └ PreviewSurfaceCanvas   │          │   • 离屏 NSWindow @(-100k,-100k)│
│      └ PreviewSurfaceView  │◄──ID───┐ │     └ NSHostingView (用户代码)  │
│         CALayer.contents = │  stdio │ │                                 │
│         IOSurfaceLookup(id)│        ├─┤ HotPreviewRenderLoop            │
│                            │        │ │   CVDisplayLink → 渲染 IOSurface│
│         鼠标/键盘/滚轮 ────┼──事件──┘ │                                 │
│                            │  stdio   │ HotPreviewEventDispatcher       │
└────────────────────────────┘          │   NSEvent.mouseEvent/keyEvent   │
                                        │   → window.sendEvent(_:)        │
                                        └─────────────────────────────────┘
```

### 模式语义

| 模式  | 帧循环          | 事件转发 | 用途                                     |
|-------|-----------------|----------|------------------------------------------|
| Image | idle（≤1 fps） | 不转发   | 写代码看 layout，保存触发刷新            |
| Live  | active（60 fps）| 转发     | 调按钮、滚动、动画，体验对齐 Xcode      |

模式切换 = 改帧率 + 改事件转发开关，**不重启子进程、不换 surface 通道、不换显示控件**，瞬间生效。

### 帧传输

- 子进程渲染到 `IOSurface`，已设 `kIOSurfaceIsGlobal: true`。
- 把 32 位 `IOSurfaceID` 通过 stdio 推送给主进程。
- 主进程 `IOSurfaceLookup(id)` → 赋给 `CALayer.contents`，GPU 零拷贝。
- 不再使用 `SharedMemoryFrameChannel` / `FrameFileStore` 作为主路径（保留作为兼容 fallback）。

### 事件回灌

- 主进程 `PreviewSurfaceView` 拦截 `mouseDown / mouseUp / mouseDragged / mouseMoved / scrollWheel / keyDown / keyUp / flagsChanged`。
- 序列化为 `PreviewInputEvent`，通过 stdio 推送给子进程。
- 子进程 `HotPreviewEventDispatcher` 用 `NSEvent.mouseEvent(...)` / `NSEvent.keyEvent(...)` 合成 `NSEvent`，调用 `window.sendEvent(_:)`，SwiftUI 按原生路径处理。

---

## 2. 协议变更总览

### 新增命令（HotHostCommand）

| 命令                       | 方向     | 用途                                              |
|----------------------------|----------|---------------------------------------------------|
| `startFrameStream`         | 主 → 子 | 启动帧循环；参数：目标尺寸、scale、帧率策略       |
| `stopFrameStream`          | 主 → 子 | 停止帧循环                                        |
| `setFrameStreamPolicy`     | 主 → 子 | 切换 idle / interactive / animating 帧率策略      |
| `resizeSurface`            | 主 → 子 | 调整 surface 像素尺寸（面板 resize / 屏幕切换）    |
| `forwardInputEvent`        | 主 → 子 | 注入鼠标 / 键盘 / 滚轮事件                        |

### 新增服务端事件（异步推送，非 request/response）

| 事件                | 方向     | 用途                                                |
|---------------------|----------|-----------------------------------------------------|
| `frameProduced`     | 子 → 主 | 通知主进程一个新 IOSurfaceID 可用                   |
| `streamStateChanged`| 子 → 主 | 通知主进程帧循环当前策略 / 健康状态                 |

### 删除命令（Phase 4 一次性删除）

| 命令                  | 替代方案                                       |
|-----------------------|-----------------------------------------------|
| `startLivePreview`    | `startFrameStream`（无窗口语义）              |
| `updateLiveFrame`     | 完全删除（不再有可见 Live 窗口）              |
| `showLivePreview`     | 完全删除                                      |
| `hideLivePreview`     | 完全删除                                      |
| `stopLivePreview`     | `stopFrameStream`                             |

### 报文新增字段（HotRenderResponse → 或独立 HotHostEvent）

为支持服务端事件流，需引入"消息 envelope"概念：

```
{ "kind": "response", "payload": <HotRenderResponse> }
{ "kind": "event",    "payload": <HotHostEvent> }
```

---

## 3. 文件计划总览

### 新增文件

| 路径                                                                                | 说明                                          |
|-------------------------------------------------------------------------------------|-----------------------------------------------|
| `Sources/LumiPreviewKit/LiveCanvas/PreviewSurfaceView.swift`                        | NSView，layer.contents 绑定 IOSurface         |
| `Sources/LumiPreviewKit/LiveCanvas/PreviewSurfaceCanvas.swift`                      | NSViewRepresentable 包装                      |
| `Sources/LumiPreviewKit/LiveCanvas/PreviewSurfaceController.swift`                  | 主进程侧帧 / 事件路由                         |
| `Sources/LumiPreviewKit/Frames/IOSurfaceFrame.swift`                                | IOSurfaceID 帧描述符                          |
| `Sources/LumiPreviewKit/Host/PreviewInputEvent.swift`                               | 跨进程事件 Codable 模型                       |
| `Sources/LumiPreviewKit/Host/HotHostEvent.swift`                                    | 服务端事件 envelope                            |
| `Sources/LumiPreviewKit/Host/FrameStreamPolicy.swift`                               | 帧率策略枚举                                  |
| `Sources/LumiHotPreviewHostApp/HotPreviewRenderLoop.swift`                          | CVDisplayLink + 节流                          |
| `Sources/LumiHotPreviewHostApp/HotPreviewEventDispatcher.swift`                     | NSEvent 合成 + sendEvent 注入                 |
| `Sources/LumiHotPreviewHostApp/HotPreviewRenderer+EventInjection.swift`             | renderer 扩展，对接 dispatcher                |
| `Tests/LumiPreviewKitTests/PreviewSurfaceViewTests.swift`                           | layer.contents 替换、size change 通知         |
| `Tests/LumiPreviewKitTests/PreviewInputEventTests.swift`                            | 事件 Codable 编解码                            |
| `Tests/LumiPreviewKitTests/HotHostEventTests.swift`                                 | envelope 编解码、向后兼容                      |
| `Tests/LumiPreviewKitTests/FrameStreamPolicyTests.swift`                            | 策略状态机                                    |

### 修改文件

| 路径                                                                                | Phase | 修改要点                                       |
|-------------------------------------------------------------------------------------|-------|-----------------------------------------------|
| `Sources/LumiPreviewKit/Host/HotHostMessages.swift`                                 | P2/P3 | 新增 5 条命令、字段                            |
| `Sources/LumiPreviewKit/Frames/HotRenderResponse.swift`                             | P1    | 新增 `surfaceID`、`scale` 字段                 |
| `Sources/LumiPreviewKit/Host/HotPreviewHostProcess.swift`                           | P2    | `HotHostConnection` 增加 streamEvents 异步序列 |
| `Sources/LumiHotPreviewHostApp/HotStdioPreviewHost.swift`                           | P2/P3 | 接入 envelope、启动帧循环、转发事件            |
| `Sources/LumiHotPreviewHostApp/HotPreviewRenderer.swift`                            | P1    | `snapshotFrame` 默认走 surface 路径            |
| `Plugins/PluginEditorPreview/Sources/PluginEditorPreview/Views/EditorPreviewCanvas.swift`               | P1    | 用 `PreviewSurfaceCanvas` 替换 `Image`         |
| `Plugins/PluginEditorPreview/Sources/PluginEditorPreview/ViewModels/EditorPreviewViewModel.swift`       | P2/P3 | 新增 `currentSurfaceID`、转发事件入口          |
| `Plugins/PluginEditorPreview/Sources/PluginEditorPreview/Services/EditorPreviewService.swift`           | P2/P3 | 移除窗口贴位逻辑，改用 surface 通道            |

### 删除文件（Phase 4）

| 路径                                                                                | 行数  |
|-------------------------------------------------------------------------------------|-------|
| `Sources/LumiPreviewKit/LiveCanvas/LivePreviewWindow.swift`                         | 102   |
| `Sources/LumiPreviewKit/LiveCanvas/LiveCanvasService.swift`                         | 270   |
| `Sources/LumiHotPreviewHostApp/HotLivePreviewWindow.swift`                          | 87    |
| `Sources/LumiHotPreviewHostApp/HotPreviewRenderer+Live.swift`                       | 168   |
| `Plugins/PluginEditorPreview/Sources/PluginEditorPreview/Views/EditorPreviewLiveCanvasFrameReporter.swift` | 323 |

预估净删除 **~950 行**纯协调代码。

---

## 4. Phase 1 — 内嵌显示通道（CALayer + IOSurface）

### 4.1 目标

把"子进程渲染一帧 → 主进程显示"这条最短路径从 PNG/`Image(nsImage:)` 切换为 IOSurface/`CALayer.contents`。**Image 模式视觉不变**，但已经为后续阶段铺好显示控件。Live 窗口路径保留不动，作为 fallback。

### 4.2 新增类型

#### `LumiPreviewFacade.IOSurfaceFrame`（位于 `Frames/IOSurfaceFrame.swift`）

```swift
public struct IOSurfaceFrame: Codable, Sendable, Equatable {
    public let surfaceID: UInt32
    public let width: Int
    public let height: Int
    public let scale: Double          // 像素 / 点
    public let seq: UInt64            // 单调递增序号，主进程用以丢弃过期帧
}
```

#### `PreviewSurfaceView`（位于 `LiveCanvas/PreviewSurfaceView.swift`）

```swift
@MainActor
public final class PreviewSurfaceView: NSView {

    // MARK: - 公开属性

    public var onSizeChange: ((CGSize, CGFloat) -> Void)?

    public private(set) var currentSurfaceID: UInt32?

    // MARK: - 生命周期

    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
    }
    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }

    public override var wantsUpdateLayer: Bool { true }

    public override func makeBackingLayer() -> CALayer {
        let layer = CALayer()
        layer.contentsGravity = .resize
        layer.magnificationFilter = .nearest
        layer.minificationFilter = .linear
        return layer
    }

    // MARK: - 公开方法

    public func attach(surfaceID: UInt32) {
        guard surfaceID != currentSurfaceID,
              let surface = IOSurfaceLookup(IOSurfaceID(surfaceID)) else { return }
        currentSurfaceID = surfaceID
        layer?.contents = surface
        layer?.contentsScale = window?.backingScaleFactor ?? 1
        layer?.setNeedsDisplay()
    }

    public func detach() {
        currentSurfaceID = nil
        layer?.contents = nil
    }

    // MARK: - 尺寸通知

    public override func layout() {
        super.layout()
        notifySize()
    }

    public override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        layer?.contentsScale = window?.backingScaleFactor ?? 1
        notifySize()
    }

    private func notifySize() {
        onSizeChange?(bounds.size, window?.backingScaleFactor ?? 1)
    }
}
```

> **不实现事件转发**。Phase 3 才打开。Phase 1 此 view 仅负责显示。

#### `PreviewSurfaceCanvas`（位于 `LiveCanvas/PreviewSurfaceCanvas.swift`）

```swift
public struct PreviewSurfaceCanvas: NSViewRepresentable {
    public let surfaceID: UInt32?
    public let onSizeChange: (CGSize, CGFloat) -> Void

    public init(surfaceID: UInt32?,
                onSizeChange: @escaping (CGSize, CGFloat) -> Void) {
        self.surfaceID = surfaceID
        self.onSizeChange = onSizeChange
    }

    public func makeNSView(context: Context) -> PreviewSurfaceView {
        let view = PreviewSurfaceView()
        view.onSizeChange = onSizeChange
        if let surfaceID { view.attach(surfaceID: surfaceID) }
        return view
    }

    public func updateNSView(_ nsView: PreviewSurfaceView, context: Context) {
        nsView.onSizeChange = onSizeChange
        if let surfaceID {
            nsView.attach(surfaceID: surfaceID)
        } else {
            nsView.detach()
        }
    }
}
```

### 4.3 修改 `HotRenderResponse`

新增字段（保持向后兼容，使用 `decodeIfPresent`）：

```swift
public let surfaceID: UInt32?
public let scale: Double?
```

`HotPreviewRenderer.snapshotFrame` 已生成 `PreviewSurfaceFrame`（包含 `surfaceID`、`scale`），把它映射到新字段。

### 4.4 修改 `HotStdioPreviewHost.makeHotResponse`

新优先级：

1. 如果 `snapshot.surfaceFrame != nil` → 走 surface 路径，response 写入 `surfaceID / scale / frameSize`，**不再写 `previewImagePNGBase64` / `imageFilePath` / `sharedMemoryTag`**（节省 base64 编解码与磁盘 IO）。
2. 仅当 surface 创建失败时，回退到现在的 base64/file/sharedMemory 路径作为兼容兜底。

### 4.5 主进程消费

`EditorPreviewService` 新增：

```swift
@Published public private(set) var currentSurfaceID: UInt32?
```

收到 `HotRenderResponse` 时：

```swift
if let id = response.surfaceID {
    currentSurfaceID = id
}
```

`EditorPreviewCanvas.swift`：

```swift
PreviewSurfaceCanvas(
    surfaceID: viewModel.currentSurfaceID,
    onSizeChange: { size, scale in
        viewModel.canvasDidResize(size, scale: scale)
    }
)
```

替换原 `Image(nsImage: viewModel.renderImage)` 节点（Image 模式分支）。`renderImage` 字段保留作为兜底，仅当 `currentSurfaceID == nil` 时才回退显示。

### 4.6 完成标志

- [ ] 启动 Image 模式，能看到与重构前完全相同的预览图。
- [ ] `PreviewSurfaceView.currentSurfaceID` 在保存触发 refresh 时被替换。
- [ ] 单元测试 `PreviewSurfaceViewTests`：调用 `attach(surfaceID:)` 后 `layer.contents` 被设置；同 surface 不重复设置。
- [ ] 单元测试 `HotRenderResponseTests`：编解码新增字段；旧响应不带 `surfaceID` 仍可解码。
- [ ] 旧 Live 窗口路径保持可用（feature flag 默认仍指向旧路径）。

### 4.7 风险点

- **IOSurface 跨进程引用计数**：主进程 `IOSurfaceLookup` 后必须保留 `IOSurfaceRef` 强引用（赋给 `layer.contents` 即可），否则下次 lookup 可能拿到已回收的 surface。子进程的 `recentSurfaces` 数组保留最近 4 帧，在保留窗口内主进程必须及时拿走。
- **scale 不一致**：子进程渲染时使用的 scale 必须与主进程当前显示器一致。Phase 1 仍使用 refresh 触发的单帧，scale 可在请求时附带；Phase 2 起改成动态 resizeSurface。

---

## 5. Phase 2 — 60fps 帧流

### 5.1 目标

子进程开 `CVDisplayLink`，按节流策略持续把 IOSurface 推给主进程。**Live 模式视觉对齐 Xcode**：动画流畅、状态变化实时反映。**仍不转发事件**——按钮点不动，但视觉已经"活"。

### 5.2 新增类型

#### `LumiPreviewFacade.FrameStreamPolicy`（位于 `Host/FrameStreamPolicy.swift`）

```swift
public enum FrameStreamPolicy: String, Codable, Sendable, Equatable {
    case stopped       // 不渲染，不推帧
    case idle          // 1 fps 心跳；保活 IOSurface
    case interactive   // 60 fps，2s 内未 dirty 自动回落 idle
    case animating     // 60 fps，CAAnimation 期间强制保持
}
```

#### `LumiPreviewFacade.HotHostEvent`（位于 `Host/HotHostEvent.swift`）

```swift
public enum HotHostEvent: Codable, Sendable, Equatable {
    case frameProduced(IOSurfaceFrame)
    case streamStateChanged(FrameStreamPolicy)
    case rendererFailed(message: String)
}
```

#### Stdio Envelope

`Host/HotHostMessages.swift` 中新增：

```swift
public enum HotHostOutbound: Codable, Sendable {
    case response(requestID: UInt64, payload: HotRenderResponse)
    case event(HotHostEvent)
}
```

请求侧加 `requestID` 字段（`UInt64`），子进程响应时回填，主进程用以匹配 in-flight request。原 `HotHostRequest` 在末尾新增可选 `requestID`，旧调用者不传时由 `HostProcessManager` 自动分配。

### 5.3 新增 `HotPreviewRenderLoop`

位于 `Sources/LumiHotPreviewHostApp/HotPreviewRenderLoop.swift`。

```swift
@MainActor
final class HotPreviewRenderLoop {

    // MARK: - 属性

    weak var renderer: HotPreviewRenderer?
    var onFrameReady: ((LumiPreviewFacade.IOSurfaceFrame) -> Void)?
    var onPolicyChanged: ((LumiPreviewFacade.FrameStreamPolicy) -> Void)?

    private(set) var policy: LumiPreviewFacade.FrameStreamPolicy = .stopped
    private var displayLink: CVDisplayLink?
    private var seq: UInt64 = 0
    private var lastInteractiveTimestamp: TimeInterval = 0
    private var lastFrameHash: Int = 0
    private static let interactiveCooldown: TimeInterval = 2.0

    // MARK: - 公开方法

    func setPolicy(_ new: LumiPreviewFacade.FrameStreamPolicy) {
        guard new != policy else { return }
        policy = new
        onPolicyChanged?(new)
        switch new {
        case .stopped: stopLink()
        case .idle, .interactive, .animating: ensureLink()
        }
        if new == .interactive {
            lastInteractiveTimestamp = CACurrentMediaTime()
        }
    }

    func noteUserInteraction() {
        lastInteractiveTimestamp = CACurrentMediaTime()
        if policy == .idle { setPolicy(.interactive) }
    }

    // MARK: - 私有方法

    private func ensureLink() {
        guard displayLink == nil else { return }
        var link: CVDisplayLink?
        CVDisplayLinkCreateWithActiveCGDisplays(&link)
        guard let link else { return }
        CVDisplayLinkSetOutputHandler(link) { [weak self] _, _, _, _, _ in
            DispatchQueue.main.async { self?.tick() }
            return kCVReturnSuccess
        }
        CVDisplayLinkStart(link)
        displayLink = link
    }

    private func stopLink() {
        guard let link = displayLink else { return }
        CVDisplayLinkStop(link)
        displayLink = nil
    }

    private func tick() {
        guard let renderer else { return }
        switch policy {
        case .stopped: return
        case .idle:
            // 1 fps：每 60 个 vsync 推一帧
            seq &+= 1
            if seq % 60 != 0 { return }
        case .interactive:
            if CACurrentMediaTime() - lastInteractiveTimestamp > Self.interactiveCooldown,
               !rendererIsAnimating() {
                setPolicy(.idle)
                return
            }
        case .animating:
            if !rendererIsAnimating() {
                setPolicy(.interactive)
            }
        }
        emitFrameIfDirty()
    }

    private func emitFrameIfDirty() {
        guard let renderer,
              let snapshot = renderer.snapshotFrame(includePNG: false, includeSurface: true).surfaceFrame else { return }
        // dirty 检测：比较 surfaceID 不够（surface 复用时 ID 相同），用 frame 大小+scale+seq
        let frame = LumiPreviewFacade.IOSurfaceFrame(
            surfaceID: snapshot.surfaceID,
            width: snapshot.width,
            height: snapshot.height,
            scale: snapshot.scale,
            seq: { seq &+= 1; return seq }()
        )
        onFrameReady?(frame)
    }

    private func rendererIsAnimating() -> Bool {
        // v1: 始终返回 false；后续接入 CATransaction completion / NSAnimationContext 检测
        return false
    }
}
```

> **节流的真实判断需要 dirty 标记**。Phase 2 v1 简化为"每 tick 都渲染并比较 surfaceID 字节哈希"，性能足够。Phase 5（增强）再做精确 dirty 检测。

### 5.4 修改子进程 `HotStdioPreviewHost`

- 持有 `renderLoop: HotPreviewRenderLoop`，注入 `renderer`。
- 新命令 dispatch：

  | command                 | 处理                                              |
  |-------------------------|--------------------------------------------------|
  | `startFrameStream`      | `renderLoop.setPolicy(.idle)`                    |
  | `stopFrameStream`       | `renderLoop.setPolicy(.stopped)`                 |
  | `setFrameStreamPolicy`  | `renderLoop.setPolicy(req.policy)`               |
  | `resizeSurface`         | renderer 调整 hosting view frame，下一帧 dirty  |

- 出站写入改为 envelope：原响应包成 `.response(requestID:, payload:)`；`renderLoop.onFrameReady` 触发时写入 `.event(.frameProduced(...))`。

### 5.5 修改主进程 `HotPreviewHostProcess` / `HotHostConnection`

`HotHostConnection` 协议新增异步序列：

```swift
var events: AsyncStream<HotHostEvent> { get }
```

`ProcessHotHostConnection` 内部读取 stdout 时按 envelope 分流：
- `.response` → 唤醒对应 `requestID` 的 continuation
- `.event` → yield 到 `events` stream

### 5.6 主进程消费帧事件

`EditorPreviewService` 新增任务：

```swift
private var eventTask: Task<Void, Never>?

func subscribeHostEvents() {
    eventTask?.cancel()
    eventTask = Task { [weak self] in
        guard let connection = self?.hostConnection else { return }
        for await event in connection.events {
            await self?.handleHostEvent(event)
        }
    }
}

@MainActor
private func handleHostEvent(_ event: HotHostEvent) {
    switch event {
    case .frameProduced(let frame):
        currentSurfaceID = frame.surfaceID
        currentSurfaceScale = frame.scale
    case .streamStateChanged(let policy):
        currentStreamPolicy = policy
    case .rendererFailed(let message):
        showFailure(message)
    }
}
```

模式切换 API：

```swift
func enterImageMode() {
    Task { try? await hostConnection?.requestSetFrameStreamPolicy(.idle) }
}

func enterLiveMode() {
    Task { try? await hostConnection?.requestSetFrameStreamPolicy(.interactive) }
}
```

### 5.7 移除"贴窗口"路径

**Phase 2 内**就把以下三个调用废弃（保留代码但不调用）：
- `requestUpdateLiveFrame`
- `requestShowLivePreview`
- `requestHideLivePreview`

UI 层 `EditorPreviewLiveCanvasFrameReporter` 不再触发屏幕坐标回报；`EditorPreviewWindowLifecycleReporter` 不再驱动可见性同步。Phase 4 再物理删除。

### 5.8 完成标志

- [ ] 切到 Live 模式后能看到子进程 SwiftUI 动画在 Lumi 面板内流畅播放（≥30fps）。
- [ ] 切到 Image 模式后帧率回落到 ≤1fps，Activity Monitor 中子进程 CPU < 5%。
- [ ] resize Lumi 面板，surface 像素尺寸跟随刷新，无明显模糊或拉伸。
- [ ] 跨屏拖动 Lumi 主窗口（Retina ↔ 非 Retina），scale 自动跟随。
- [ ] 子进程退出时主进程显示最后一帧，不闪黑。
- [ ] 单元测试 `FrameStreamPolicyTests`：状态机迁移、interactive cooldown 自动回落。
- [ ] 单元测试 `HotHostEventTests`：envelope 编解码兼容旧响应。

### 5.9 风险点

- **IOSurface 复用导致主进程没有"换图"信号**：`layer.contents` 即使指向同一 `IOSurfaceRef`，需要 `setNeedsDisplay()` 才会重绘。`PreviewSurfaceView.attach(surfaceID:)` 内已调用，但同 ID 时没有触发——Phase 2 需在 `attach` 中**始终**调用 `setNeedsDisplay()` 一次（或暴露 `markFrameUpdated()` 给 controller 调），否则连续相同 surfaceID 的多帧不会刷新。
- **Envelope 兼容老子进程**：协议升级期间，主进程升级了但二进制可能还是老 host。需要 `HostProcessManager` 探测 host 版本（启动后第一条命令）；不支持 envelope 时回退旧路径。建议直接捆绑 host 二进制，避免版本错配。

---

## 6. Phase 3 — 反向事件转发（可交互）

### 6.1 目标

`PreviewSurfaceView` 在 Live 模式下捕获鼠标 / 键盘 / 滚轮事件，序列化转发给子进程。子进程合成 `NSEvent` 调用 `window.sendEvent(_:)`，SwiftUI runtime 按原生流程处理。**完成此阶段后，Live 模式 ≈ Xcode Previews**（中文 IME / 模态弹窗除外）。

### 6.2 新增类型

#### `LumiPreviewFacade.PreviewInputEvent`（位于 `Host/PreviewInputEvent.swift`）

```swift
public struct PreviewInputEvent: Codable, Sendable, Equatable {

    public enum Kind: String, Codable, Sendable {
        case mouseDown, mouseUp, mouseDragged, mouseMoved, mouseEntered, mouseExited
        case rightMouseDown, rightMouseUp, rightMouseDragged
        case otherMouseDown, otherMouseUp, otherMouseDragged
        case scrollWheel
        case keyDown, keyUp, flagsChanged
    }

    public let kind: Kind
    public let timestamp: TimeInterval
    public let modifiers: UInt          // NSEvent.ModifierFlags.rawValue

    // 鼠标
    public let pointInPreview: CGPoint? // 0..1 归一化前的 NSView 坐标
    public let buttonNumber: Int?
    public let clickCount: Int?
    public let pressure: Double?

    // 滚轮
    public let scrollDeltaX: Double?
    public let scrollDeltaY: Double?
    public let scrollHasPrecisePixels: Bool?
    public let scrollPhase: UInt?       // NSEvent.Phase.rawValue
    public let scrollMomentumPhase: UInt?

    // 键盘
    public let keyCode: UInt16?
    public let characters: String?
    public let charactersIgnoringModifiers: String?
    public let isARepeat: Bool?
}
```

> **不携带 surface 内坐标**。子进程持有那个离屏 hosting view，view 在 0..width / 0..height 的点坐标系中。主进程把 `PreviewSurfaceView` 内的点（左上原点 → AppKit 左下原点）转换好后传 `pointInPreview`。

### 6.3 修改 `PreviewSurfaceView`

```swift
// 新增公开属性
public var isInteractive: Bool = false {
    didSet { window?.invalidateCursorRects(for: self) }
}
public var onInputEvent: ((LumiPreviewFacade.PreviewInputEvent) -> Void)?

// 重写
public override var acceptsFirstResponder: Bool { isInteractive }
public override func acceptsFirstMouse(for event: NSEvent?) -> Bool { isInteractive }

public override func mouseDown(with event: NSEvent)        { forward(event, kind: .mouseDown) }
public override func mouseUp(with event: NSEvent)          { forward(event, kind: .mouseUp) }
public override func mouseDragged(with event: NSEvent)     { forward(event, kind: .mouseDragged) }
public override func mouseMoved(with event: NSEvent)       { forward(event, kind: .mouseMoved) }
public override func rightMouseDown(with event: NSEvent)   { forward(event, kind: .rightMouseDown) }
public override func rightMouseUp(with event: NSEvent)     { forward(event, kind: .rightMouseUp) }
public override func rightMouseDragged(with event: NSEvent){ forward(event, kind: .rightMouseDragged) }
public override func otherMouseDown(with event: NSEvent)   { forward(event, kind: .otherMouseDown) }
public override func otherMouseUp(with event: NSEvent)     { forward(event, kind: .otherMouseUp) }
public override func otherMouseDragged(with event: NSEvent){ forward(event, kind: .otherMouseDragged) }
public override func scrollWheel(with event: NSEvent)      { forward(event, kind: .scrollWheel) }
public override func keyDown(with event: NSEvent)          { forward(event, kind: .keyDown) }
public override func keyUp(with event: NSEvent)            { forward(event, kind: .keyUp) }
public override func flagsChanged(with event: NSEvent)     { forward(event, kind: .flagsChanged) }

private func forward(_ event: NSEvent, kind: LumiPreviewFacade.PreviewInputEvent.Kind) {
    guard isInteractive else { return }
    let p = convert(event.locationInWindow, from: nil)
    onInputEvent?(.init(
        kind: kind,
        timestamp: event.timestamp,
        modifiers: event.modifierFlags.rawValue,
        pointInPreview: kind.isMouseEvent ? p : nil,
        buttonNumber: kind.isMouseEvent ? event.buttonNumber : nil,
        clickCount: kind.isMouseEvent ? event.clickCount : nil,
        pressure: kind.isMouseEvent ? Double(event.pressure) : nil,
        scrollDeltaX: kind == .scrollWheel ? event.scrollingDeltaX : nil,
        scrollDeltaY: kind == .scrollWheel ? event.scrollingDeltaY : nil,
        scrollHasPrecisePixels: kind == .scrollWheel ? event.hasPreciseScrollingDeltas : nil,
        scrollPhase: kind == .scrollWheel ? event.phase.rawValue : nil,
        scrollMomentumPhase: kind == .scrollWheel ? event.momentumPhase.rawValue : nil,
        keyCode: kind.isKeyboardEvent ? event.keyCode : nil,
        characters: kind == .keyDown || kind == .keyUp ? event.characters : nil,
        charactersIgnoringModifiers: kind == .keyDown || kind == .keyUp ? event.charactersIgnoringModifiers : nil,
        isARepeat: kind == .keyDown || kind == .keyUp ? event.isARepeat : nil
    ))
}
```

### 6.4 新增 `HotPreviewEventDispatcher`（子进程）

位于 `Sources/LumiHotPreviewHostApp/HotPreviewEventDispatcher.swift`。

```swift
@MainActor
final class HotPreviewEventDispatcher {

    weak var renderer: HotPreviewRenderer?

    func dispatch(_ event: LumiPreviewFacade.PreviewInputEvent) {
        guard let window = renderer?.previewView?.window else { return }
        let pointInWindow = locationInWindow(event, view: renderer?.previewView, window: window)
        let modifiers = NSEvent.ModifierFlags(rawValue: event.modifiers)

        let nsEvent: NSEvent? = {
            switch event.kind {
            case .mouseDown, .mouseUp, .mouseDragged, .mouseMoved,
                 .rightMouseDown, .rightMouseUp, .rightMouseDragged,
                 .otherMouseDown, .otherMouseUp, .otherMouseDragged,
                 .mouseEntered, .mouseExited:
                return NSEvent.mouseEvent(
                    with: nsEventType(for: event.kind),
                    location: pointInWindow,
                    modifierFlags: modifiers,
                    timestamp: event.timestamp,
                    windowNumber: window.windowNumber,
                    context: nil,
                    eventNumber: 0,
                    clickCount: event.clickCount ?? 1,
                    pressure: Float(event.pressure ?? 1)
                )
            case .scrollWheel:
                return synthesizeScrollWheel(event, in: window, location: pointInWindow)
            case .keyDown, .keyUp:
                return NSEvent.keyEvent(
                    with: event.kind == .keyDown ? .keyDown : .keyUp,
                    location: .zero,
                    modifierFlags: modifiers,
                    timestamp: event.timestamp,
                    windowNumber: window.windowNumber,
                    context: nil,
                    characters: event.characters ?? "",
                    charactersIgnoringModifiers: event.charactersIgnoringModifiers ?? "",
                    isARepeat: event.isARepeat ?? false,
                    keyCode: event.keyCode ?? 0
                )
            case .flagsChanged:
                return synthesizeFlagsChanged(event, in: window)
            }
        }()

        if let ns = nsEvent {
            window.sendEvent(ns)
        }
    }
}
```

#### 关键工具函数

- `locationInWindow`：把 `pointInPreview`（NSView 左上原点）转换为子进程离屏窗口坐标（AppKit 左下原点）。需考虑离屏窗口当前 frame：

  ```swift
  let viewSize = renderer.previewView?.bounds.size ?? .zero
  let flipped = NSPoint(x: p.x, y: viewSize.height - p.y)
  ```

- `synthesizeScrollWheel`：`NSEvent.mouseEvent(with: .scrollWheel, ...)` 不支持设置 `scrollingDeltaX/Y`，需用 `NSEvent.event(with: cgEvent: ...)` 间接构造，或使用 `CGEvent` 路径：

  ```swift
  guard let cg = CGEvent(scrollWheelEvent2Source: nil,
                         units: event.scrollHasPrecisePixels == true ? .pixel : .line,
                         wheelCount: 2,
                         wheel1: Int32(event.scrollDeltaY ?? 0),
                         wheel2: Int32(event.scrollDeltaX ?? 0),
                         wheel3: 0) else { return nil }
  return NSEvent(cgEvent: cg)
  ```

  注意 cgEvent 路径不带 `scrollPhase`，但绝大多数 ScrollView 用例不依赖它；可作为 v1 简化。

- `synthesizeFlagsChanged`：用 `CGEventCreateKeyboardEvent` + `flagsChanged` 类型。

### 6.5 离屏窗口必要前置条件

子进程的离屏 `NSWindow`（`HotPreviewRenderer.renderWindow` 或 live 复用的 window）**必须满足**以下条件，事件才能被 SwiftUI 接收：

1. `orderFrontRegardless()` 已调用（已有，保留）。
2. `setFrameOrigin(NSPoint(x: -100_000, y: -100_000))` 移到屏外（已有）。
3. `canBecomeKey = true`：当前 `HotLivePreviewWindow` 已是 `true`，但旧 renderWindow 是 `borderless` 默认 false。**需要为 renderWindow 子类化 NSWindow 或使用 `NSPanel` 改写 `canBecomeKey`**。
4. `acceptsMouseMovedEvents = true`（仅 mouseMoved 转发需要）。
5. `previewView`（`NSHostingView`）的 `acceptsFirstResponder` 默认为 true，无需改动。
6. 在转发 `keyDown` 前，子进程主动 `window.makeFirstResponder(previewView)`：

   ```swift
   if window.firstResponder !== window.previewHostingView {
       window.makeFirstResponder(window.previewHostingView)
   }
   ```

  否则 TextField 收不到键盘事件。

### 6.6 主进程接线

`HotHostConnection` 新增：

```swift
@discardableResult
func requestForwardInputEvent(_ event: LumiPreviewFacade.PreviewInputEvent) async throws -> HotRenderResponse
```

`EditorPreviewService`：

```swift
func forwardInputEvent(_ event: PreviewInputEvent) {
    Task {
        try? await hostConnection?.requestForwardInputEvent(event)
        if event.kind.isMouseEvent || event.kind == .scrollWheel {
            try? await hostConnection?.requestSetFrameStreamPolicy(.interactive)
        }
    }
}
```

`PreviewSurfaceCanvas` 暴露 `onInputEvent`，向上传到 viewModel → service。

### 6.7 模式切换

```swift
viewModel.preferredDisplayMode == .live  →  surfaceView.isInteractive = true
viewModel.preferredDisplayMode == .image →  surfaceView.isInteractive = false
```

### 6.8 完成标志

- [ ] Live 模式下点击 SwiftUI `Button` 能触发其 action（视觉、状态变化均同步到下一帧）。
- [ ] `Toggle`、`Slider`、`Stepper` 可正常交互。
- [ ] `ScrollView` / `List` 可滚动，触摸板二指滑动平滑。
- [ ] `TextField` 可获得焦点并接受英文输入。
- [ ] `Cmd+A`、`Esc` 等修饰键组合工作（仅在子进程内消费，不会泄漏到 Lumi）。
- [ ] Image 模式下 `surfaceView.isInteractive = false`，所有事件不转发。
- [ ] 单元测试 `PreviewInputEventTests`：编解码所有 case；坐标翻转。
- [ ] 集成测试：mock `FakeHotHostConnection` 验证 service 在 Live 模式下转发事件、Image 模式下不转发。

### 6.9 风险点

- **离屏窗口 key window 状态**：子进程是 `.accessory` activation policy，`NSApp.keyWindow` 可能为 nil。SwiftUI 的某些 focus 行为依赖窗口为 key。解决：调用 `window.makeKeyAndOrderFront(nil)` 后立刻 `setFrameOrigin` 移屏外（关键：先 makeKey 再移位置），并保持 `becomesKeyOnlyIfNeeded = false`。
- **scrollWheel 通过 CGEvent 合成不带 phase**：触摸板惯性滑动可能不工作。v1 接受。
- **键盘焦点丢失**：每次 surface resize 或 dylib reload 后，`firstResponder` 会重置。子进程在每次 reload 后必须 `window.makeFirstResponder(previewHostingView)`。
- **修饰键泄漏**：主进程 `flagsChanged` 转发后，子进程的 modifier 状态可能与主进程不一致。`flagsChanged` 必须每次都转发，不能漏。

---

## 7. Phase 4 — 清理旧代码

### 7.1 删除文件

按照 §3 删除清单，物理删除 5 个文件，共 ~950 行。

### 7.2 删除 HotHostCommand 枚举值

`HotHostMessages.swift` 删除：
- `startLivePreview`
- `updateLiveFrame`
- `showLivePreview`
- `hideLivePreview`
- `stopLivePreview`
- `reloadLivePreview`（合并入 `loadDylib` / `interposeDylib`，外加 `setFrameStreamPolicy(.interactive)` 触发刷新）

### 7.3 删除 HotHostConnection 协议方法

`HotPreviewHostProcess.swift` 中删除：
- `requestStartLivePreview`
- `requestUpdateLiveFrame`
- `requestShowLivePreview`
- `requestHideLivePreview`
- `requestReloadLivePreview`
- `requestStopLivePreview`

### 7.4 删除 LivePreviewInfo / LivePreviewState 中"窗口"字段

`PreviewDisplayMode.swift` 中：
- 保留 `PreviewDisplayMode` 枚举与 `LivePreviewState`
- 删除 `LivePreviewInfo.hostWindowNumber`（不再有可见窗口）
- `LivePreviewState` 仍保留 `running / stopped / failed`，语义改为"帧流是否在运行"

### 7.5 删除 ViewModel 生命周期回调

`EditorPreviewViewModel.swift` 删除以下方法（共 ~10 个）：
- `previewWindowDidBecomeActive / Inactive`
- `previewWindowVisibilityDidChange`
- `previewAppDidBecomeActive / DidResignActive`
- `previewWindowDidReceiveInteraction`
- `previewWindowDidMiniaturize / DidDeminiaturize`
- `liveCanvasDidAppear / DidDisappear`
- `liveCanvasFrameUnavailable`
- `updateLiveCanvasRect`

`EditorPreviewService.swift` 中对应实现一并删除。

### 7.6 删除 EditorPreviewDetailView 中的 Reporter

`EditorPreviewDetailView.swift` 移除 `EditorPreviewWindowLifecycleReporter` 节点，移除 `EditorPreviewLiveCanvasFrameReporter.scheduleFrameUpdate` 调用。

### 7.7 完成标志

- [ ] 全量构建通过，无残留 import / 调用。
- [ ] grep `LivePreviewWindow` / `HotLivePreviewWindow` / `EditorPreviewLiveCanvasFrameReporter` 应为空。
- [ ] 所有原 Live 相关单元测试要么删除，要么改为对帧流策略的测试。
- [ ] 集成场景跑一遍：保存 → 看 Image 帧；切到 Live → 60fps 动画 + 可点击；多屏拖动；最小化恢复；子进程崩溃后重启。

---

## 8. 测试计划

### 8.1 新增单元测试

| 文件                                             | 覆盖点                                                    |
|--------------------------------------------------|-----------------------------------------------------------|
| `PreviewSurfaceViewTests`                        | attach / detach / size 通知 / scale 跟随                  |
| `PreviewInputEventTests`                         | 所有 Kind 编解码 / 坐标翻转 / nil 字段                    |
| `HotHostEventTests`                              | envelope 编解码 / 旧响应兼容                              |
| `FrameStreamPolicyTests`                         | 状态机转移 / interactive cooldown                         |
| `IOSurfaceFrameTests`                            | seq 单调 / 编解码                                         |
| `HotPreviewRenderLoopTests`                      | tick 节流 / dirty 检测（用 mock renderer）                |
| `HotPreviewEventDispatcherTests`                 | mouse / scroll / key 合成正确性（用真实离屏 NSWindow）    |

### 8.2 修改的单元测试

| 文件                                             | 改动                                                      |
|--------------------------------------------------|-----------------------------------------------------------|
| `PreviewHostMessagesTests`                       | 新增命令 / 删除已废弃命令的测试                           |
| `HotRenderResponseTests`                         | 新字段 surfaceID / scale 编解码                           |
| `LiveCanvasServiceTests`                         | Phase 4 一并删除                                          |
| `HotPreviewEngineTests`                          | 移除 Live 窗口贴位相关用例                                |

### 8.3 集成测试矩阵（手测，无需自动化）

| 场景                                              | 期望                                                       |
|---------------------------------------------------|------------------------------------------------------------|
| 打开 Lumi，切到 Editor，打开 SwiftUI 文件         | 默认 Image 模式，CPU 静默（< 5%）                          |
| Cmd+S 保存                                        | 触发一帧 refresh，预览图更新                              |
| 切到 Live 模式                                    | CPU 在子进程升至 ~30%，动画流畅，按钮可点                  |
| 在 Live 模式下点击 `Button { print("x") }`        | 子进程 stderr 可见输出，UI 状态切换                        |
| 在 Live 模式下滚动 `List`                          | 平滑滚动                                                   |
| 在 Live 模式下编辑 `TextField`（英文）             | 字符显示                                                   |
| 切回 Image 模式                                    | CPU 静默，最后一帧保持显示                                 |
| 拖动 Lumi 主窗口跨屏（Retina ↔ 非 Retina）        | 预览像素自动重新渲染，不糊                                 |
| Cmd+M 最小化 → 还原                                | 还原后立即可见，无残留浮动窗口                              |
| 子进程崩溃（`kill -9` host 进程）                  | 预览显示最后一帧 + 红色"已断开"覆盖层；点击重启可恢复       |
| 切换文件触发新 dylib 加载                          | 新 dylib 加载后自动渲染一帧；Live 模式下保持 60fps          |

---

## 9. 风险与回滚

### 9.1 关键风险

1. **IOSurface 跨进程引用计数误回收**
   - 现象：主进程 `IOSurfaceLookup` 后短时间内拿到的 surface 是空 / 旧像素。
   - 排查：检查 host 端 `recentSurfaces` 是否在主进程拿到前被裁剪。建议把 `recentSurfaceLimit` 从 4 提到 8。
2. **离屏窗口事件分发失效**
   - 现象：转发了事件但 SwiftUI 没反应。
   - 排查：先确认 `window.isVisible == true`、`window.canBecomeKey == true`、`firstResponder !== nil`。可在子进程加调试断点：`window.sendEvent` 前后打印 `window.firstResponder`。
3. **Envelope 协议不兼容**
   - 现象：升级后旧 host 二进制启动，主进程读到无法识别的 JSON。
   - 排查：`HostProcessManager` 启动后第一条命令做版本握手；不匹配则提示重新构建。
4. **CVDisplayLink 在子进程后台时被节流**
   - 现象：Lumi 切到后台时帧率掉到 0。
   - 排查：是预期行为；恢复前台后下一帧 dirty 自然恢复。

### 9.2 回滚策略

每个 Phase 都通过 feature flag 控制开关，便于快速回滚：

- `LumiPreviewFacade.UseEmbeddedSurfaceFrames`（Phase 1 起）
- `LumiPreviewFacade.UseFrameStream`（Phase 2 起）
- `LumiPreviewFacade.UseInputForwarding`（Phase 3 起）

读取来源：`UserDefaults.standard.object(forKey: "LumiPreview.UseFrameStream")`，默认开。出问题时设为 `false` 立刻退回旧路径，无需重启 Lumi。Phase 4 移除 flag。

### 9.3 完整回退到当前版本

如果整体路线证明不可行，按 git 把 4 个 phase 的提交 revert 即可恢复"独立浮动 Live 窗口"路径。**前提：每个 Phase 独立提交、独立 PR**。

---

## 10. 提交粒度建议

每 Phase 拆 3–5 个提交，每个提交可独立通过测试：

```
P1.1  feat(preview): add IOSurfaceFrame model + HotRenderResponse fields
P1.2  feat(preview): add PreviewSurfaceView / PreviewSurfaceCanvas
P1.3  feat(preview): host writes surface path in HotStdioPreviewHost
P1.4  refactor(plugin): swap Image(nsImage:) → PreviewSurfaceCanvas

P2.1  feat(preview): introduce HotHostEvent envelope + requestID
P2.2  feat(preview): add FrameStreamPolicy state machine
P2.3  feat(host): add HotPreviewRenderLoop (CVDisplayLink)
P2.4  feat(connection): expose events AsyncStream
P2.5  feat(plugin): subscribe events, drive currentSurfaceID
P2.6  feat(plugin): wire mode switch to setFrameStreamPolicy

P3.1  feat(preview): add PreviewInputEvent model
P3.2  feat(preview): forward NSEvent from PreviewSurfaceView
P3.3  feat(host): add HotPreviewEventDispatcher (NSEvent synthesis)
P3.4  feat(host): make offscreen window key + accept events
P3.5  feat(plugin): trigger interactive policy on user input

P4.1  refactor(preview): delete LivePreviewWindow / HotLivePreviewWindow
P4.2  refactor(preview): delete LiveCanvasService + EditorPreviewLiveCanvasFrameReporter
P4.3  refactor(plugin): remove window lifecycle callbacks
P4.4  chore(preview): remove deprecated HotHostCommand cases + tests
```

---

## 11. 词汇表

| 术语                  | 含义                                                                    |
|-----------------------|-------------------------------------------------------------------------|
| **离屏窗口**          | 子进程中位置在 `(-100k, -100k)` 但已 `orderFront` 的 `NSWindow`，AppKit 视其"可见"，事件分发链完整 |
| **帧流（Frame Stream）** | 子进程通过 stdio 持续推送 IOSurfaceID 给主进程的通道                    |
| **Surface ID**        | `IOSurfaceID`（`UInt32`），全局唯一，主进程用 `IOSurfaceLookup(_:)` 解析 |
| **节流策略**          | `FrameStreamPolicy`，决定子进程多少 vsync 推一帧                          |
| **事件回灌**          | 主进程把用户输入序列化通过 stdio 发回子进程，由子进程合成 NSEvent 注入  |
| **Envelope**          | stdio 出站消息的统一 wrapper，区分 `response` / `event`                  |
| **interactive cooldown** | 用户最近一次输入后保持 60fps 的时长（默认 2s），过后自动回落 idle      |

---

## 12. 完工后的对外 API 形态（参考）

```swift
// LumiPreviewKit
public extension LumiPreviewFacade {
    enum PreviewDisplayMode { case image, live }
    enum FrameStreamPolicy { case stopped, idle, interactive, animating }
    struct IOSurfaceFrame { let surfaceID: UInt32; ... }
    struct PreviewInputEvent { ... }
    final class PreviewSurfaceView: NSView { ... }
    struct PreviewSurfaceCanvas: NSViewRepresentable { ... }
}

// EditorPreviewService 对外暴露
@Published var currentSurfaceID: UInt32?
@Published var currentSurfaceScale: Double
@Published var currentStreamPolicy: FrameStreamPolicy
func enterImageMode()
func enterLiveMode()
func forwardInputEvent(_ event: PreviewInputEvent)
func canvasDidResize(_ size: CGSize, scale: CGFloat)
```

主进程 SwiftUI 侧只有一个核心节点：

```swift
PreviewSurfaceCanvas(
    surfaceID: viewModel.currentSurfaceID,
    onSizeChange: viewModel.canvasDidResize
)
.environment(\.previewIsInteractive, viewModel.effectiveDisplayMode == .live)
.background(...)
```

无任何窗口生命周期 / 屏幕坐标 / 显隐协调代码。

---

## 13. 进度追踪

### Phase 1 — 内嵌显示通道
- [ ] P1.1 IOSurfaceFrame + HotRenderResponse 字段
- [ ] P1.2 PreviewSurfaceView / PreviewSurfaceCanvas
- [ ] P1.3 host 端 surface 路径优先
- [ ] P1.4 plugin 端 Image 替换
- [ ] P1.5 单元测试 + 集成验证

### Phase 2 — 60fps 帧流
- [ ] P2.1 HotHostEvent envelope + requestID
- [ ] P2.2 FrameStreamPolicy 状态机
- [ ] P2.3 HotPreviewRenderLoop（CVDisplayLink）
- [ ] P2.4 HotHostConnection.events AsyncStream
- [ ] P2.5 plugin 端 events 订阅 + currentSurfaceID 驱动
- [ ] P2.6 模式切换接线
- [ ] P2.7 单元测试 + 集成验证

### Phase 3 — 反向事件转发
- [ ] P3.1 PreviewInputEvent 模型
- [ ] P3.2 PreviewSurfaceView 事件捕获
- [ ] P3.3 HotPreviewEventDispatcher NSEvent 合成
- [ ] P3.4 离屏窗口 key + first responder 设置
- [ ] P3.5 用户输入触发 interactive 策略
- [ ] P3.6 单元测试 + 集成验证（按钮 / Toggle / List / TextField）

### Phase 4 — 清理
- [ ] P4.1 删除 LivePreviewWindow / HotLivePreviewWindow / HotPreviewRenderer+Live
- [ ] P4.2 删除 LiveCanvasService / EditorPreviewLiveCanvasFrameReporter
- [ ] P4.3 删除 ViewModel 窗口生命周期回调
- [ ] P4.4 删除废弃 HotHostCommand 枚举值与测试
- [ ] P4.5 全量回归


