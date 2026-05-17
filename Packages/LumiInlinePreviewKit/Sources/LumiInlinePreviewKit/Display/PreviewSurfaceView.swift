import AppKit
import IOSurface
import os

public extension LumiInlinePreviewFacade {
    /// 内嵌预览的核心 NSView：
    ///
    /// - 显示路径：把 `IOSurfaceID` 解析为 `IOSurfaceRef` 后赋给 `layer.contents`。
    /// - 输入路径（`isInteractive == true` 时）：捕获鼠标 / 滚轮 / 键盘事件，
    ///   通过 `onInputEvent` 回调上抛，给 ViewModel 走 `forwardInputEvent` 命令送子进程。
    /// - 不持有任何窗口；本控件被嵌入 Lumi 自己的预览面板。
    @MainActor
    final class PreviewSurfaceView: NSView {

        // MARK: - 公开属性

        /// 当 view 尺寸或 backing scale 变化时回调，参数：(逻辑尺寸, scale)。
        public var onSizeChange: ((CGSize, CGFloat) -> Void)?

        /// 是否捕获并上抛输入事件。`false` 时所有事件都让给 super，本视图行为等同纯显示。
        public var isInteractive: Bool = false

        /// 输入事件回调；仅在 `isInteractive == true` 时触发。
        public var onInputEvent: ((PreviewInputEvent) -> Void)?

        /// 当前显示的 surface ID；nil 表示尚未附着任何 surface。
        public private(set) var currentSurfaceID: UInt32?

        /// 强引用最近一帧的 IOSurface，避免 CALayer 之外没有持有方时被 ARC 回收。
        private var retainedSurface: IOSurfaceRef?

        // MARK: - 初始化

        public override init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            wantsLayer = true
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) {
            fatalError("init(coder:) is not supported for PreviewSurfaceView.")
        }

        // MARK: - 响应链

        /// 让本 view 能接键盘事件（成为 firstResponder）。
        public override var acceptsFirstResponder: Bool { isInteractive }

        /// 让点击 surface 时即便父视图没主动 makeFirstResponder 也能开始捕获鼠标。
        public override func acceptsFirstMouse(for event: NSEvent?) -> Bool { isInteractive }

        public override func mouseDown(with event: NSEvent) {
            guard isInteractive else { super.mouseDown(with: event); return }
            window?.makeFirstResponder(self)
            forwardMouse(event, phase: .down, button: .left)
        }
        public override func mouseUp(with event: NSEvent) {
            guard isInteractive else { super.mouseUp(with: event); return }
            forwardMouse(event, phase: .up, button: .left)
        }
        public override func mouseDragged(with event: NSEvent) {
            guard isInteractive else { super.mouseDragged(with: event); return }
            forwardMouse(event, phase: .dragged, button: .left)
        }
        public override func mouseMoved(with event: NSEvent) {
            guard isInteractive else { super.mouseMoved(with: event); return }
            forwardMouse(event, phase: .moved, button: .left)
        }
        public override func rightMouseDown(with event: NSEvent) {
            guard isInteractive else { super.rightMouseDown(with: event); return }
            forwardMouse(event, phase: .down, button: .right)
        }
        public override func rightMouseUp(with event: NSEvent) {
            guard isInteractive else { super.rightMouseUp(with: event); return }
            forwardMouse(event, phase: .up, button: .right)
        }
        public override func rightMouseDragged(with event: NSEvent) {
            guard isInteractive else { super.rightMouseDragged(with: event); return }
            forwardMouse(event, phase: .dragged, button: .right)
        }
        public override func otherMouseDown(with event: NSEvent) {
            guard isInteractive else { super.otherMouseDown(with: event); return }
            forwardMouse(event, phase: .down, button: .other)
        }
        public override func otherMouseUp(with event: NSEvent) {
            guard isInteractive else { super.otherMouseUp(with: event); return }
            forwardMouse(event, phase: .up, button: .other)
        }
        public override func otherMouseDragged(with event: NSEvent) {
            guard isInteractive else { super.otherMouseDragged(with: event); return }
            forwardMouse(event, phase: .dragged, button: .other)
        }

        public override func scrollWheel(with event: NSEvent) {
            guard isInteractive else { super.scrollWheel(with: event); return }
            let local = convert(event.locationInWindow, from: nil)
            let model = ScrollWheelEvent(
                x: Double(local.x),
                y: Double(local.y),
                deltaX: Double(event.deltaX),
                deltaY: Double(event.deltaY),
                scrollingDeltaX: Double(event.scrollingDeltaX),
                scrollingDeltaY: Double(event.scrollingDeltaY),
                hasPreciseScrollingDeltas: event.hasPreciseScrollingDeltas,
                modifiers: ModifierFlags.fromAppKitImported(event.modifierFlags),
                phase: ScrollWheelEvent.Phase.fromAppKit(event.phase),
                momentumPhase: ScrollWheelEvent.Phase.fromAppKit(event.momentumPhase)
            )
            onInputEvent?(.scrollWheel(model))
        }

        public override func keyDown(with event: NSEvent) {
            guard isInteractive else { super.keyDown(with: event); return }
            forwardKey(event, phase: .down)
        }

        public override func keyUp(with event: NSEvent) {
            guard isInteractive else { super.keyUp(with: event); return }
            forwardKey(event, phase: .up)
        }

        public override func flagsChanged(with event: NSEvent) {
            guard isInteractive else { super.flagsChanged(with: event); return }
            onInputEvent?(.flagsChanged(modifiers: ModifierFlags.fromAppKitImported(event.modifierFlags)))
        }

        // MARK: - 输入事件辅助

        private func forwardMouse(
            _ event: NSEvent,
            phase: MouseEvent.Phase,
            button: MouseEvent.Button
        ) {
            let local = convert(event.locationInWindow, from: nil)
            let model = MouseEvent(
                phase: phase,
                button: button,
                x: Double(local.x),
                y: Double(local.y),
                clickCount: phase == .moved ? 0 : event.clickCount,
                modifiers: ModifierFlags.fromAppKitImported(event.modifierFlags)
            )
            onInputEvent?(.mouse(model))
        }

        private func forwardKey(_ event: NSEvent, phase: KeyEvent.Phase) {
            let model = KeyEvent(
                phase: phase,
                keyCode: event.keyCode,
                characters: event.characters,
                charactersIgnoringModifiers: event.charactersIgnoringModifiers,
                isARepeat: event.isARepeat,
                modifiers: ModifierFlags.fromAppKitImported(event.modifierFlags)
            )
            onInputEvent?(.key(model))
        }

        // MARK: - Layer 配置

        public override var wantsUpdateLayer: Bool { true }

        public override func makeBackingLayer() -> CALayer {
            let layer = CALayer()
            layer.contentsGravity = .resize
            layer.magnificationFilter = .nearest
            layer.minificationFilter = .linear
            layer.isOpaque = false
            return layer
        }

        // MARK: - 公开方法

        /// 把指定的 `IOSurfaceID` 绑定到 layer.contents。
        ///
        /// - 重复绑定同一个 surface ID 时仍然会触发一次 `setNeedsDisplay()`，
        ///   因为子进程可能用同一个 surface 写了新像素而 ID 没变。
        public func attach(surfaceID: UInt32) {
            let curIDStr = currentSurfaceID.map { String($0) } ?? "nil"
            let winStr = (window != nil) ? "yes" : "no"
            let layerStr = (layer != nil) ? "yes" : "no"
            let scaleVal = window?.backingScaleFactor ?? 1
            let boundsStr = "\(bounds.width)×\(bounds.height)"
            if LumiInlinePreviewFacade.verbose {
                            LumiInlinePreviewFacade.logger.info("[PreviewSurfaceView] attach(surfaceID: \(surfaceID)) — currentSurfaceID: \(curIDStr), bounds: \(boundsStr), window: \(winStr)")
            }
            guard let surface = IOSurfaceLookup(IOSurfaceID(surfaceID)) else {
                if LumiInlinePreviewFacade.verbose {
                                    LumiInlinePreviewFacade.logger.error("[PreviewSurfaceView] ❌ IOSurfaceLookup FAILED for surfaceID=\(surfaceID)")
                }
                return
            }
            currentSurfaceID = surfaceID
            retainedSurface = surface
            layer?.contents = surface
            layer?.contentsScale = scaleVal
            layer?.setNeedsDisplay()
            if LumiInlinePreviewFacade.verbose {
                            LumiInlinePreviewFacade.logger.info("[PreviewSurfaceView] ✅ Attached surface \(surfaceID) to layer, contentsScale=\(scaleVal), layer: \(layerStr)")
            }
        }

        /// 清空当前显示。
        public func detach() {
            currentSurfaceID = nil
            retainedSurface = nil
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

        public override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            layer?.contentsScale = window?.backingScaleFactor ?? 1
            notifySize()
        }

        // MARK: - 私有方法

        private func notifySize() {
            let scale = window?.backingScaleFactor ?? 1
            onSizeChange?(bounds.size, scale)
        }
    }
}
