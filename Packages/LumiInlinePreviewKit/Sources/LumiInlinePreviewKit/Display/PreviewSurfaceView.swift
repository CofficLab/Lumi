import AppKit
import CoreImage
import IOSurface
import MagicKit
import os

public extension LumiInlinePreviewFacade {
    /// 内嵌预览的核心 NSView：
    ///
    /// - 显示路径：把 `IOSurfaceID` 解析为 `IOSurfaceRef` 后赋给 `layer.contents`。
    /// - 输入路径（`isInteractive == true` 时）：捕获鼠标 / 滚轮 / 键盘事件，
    ///   通过 `onInputEvent` 回调上抛，给 ViewModel 走 `forwardInputEvent` 命令送子进程。
    /// - 不持有任何窗口；本控件被嵌入 Lumi 自己的预览面板。
    @MainActor
    final class PreviewSurfaceView: NSView, SuperLog {
        nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "LumiInlinePreviewKit.PreviewSurfaceView")
        public nonisolated static let emoji = "👁"
        public nonisolated static let verbose: Bool = true

        // MARK: - 公开属性

        /// 当 view 尺寸或 backing scale 变化时回调，参数：(逻辑尺寸, scale)。
        public var onSizeChange: ((CGSize, CGFloat) -> Void)?

        /// 是否捕获并上抛输入事件。`false` 时所有事件都让给 super，本视图行为等同纯显示。
        public var isInteractive: Bool = false

        /// 输入事件回调；仅在 `isInteractive == true` 时触发。
        public var onInputEvent: ((PreviewInputEvent) -> Void)?

        /// 当前显示的 surface ID；nil 表示尚未附着任何 surface。
        public private(set) var currentSurfaceID: UInt32?

        /// 强引用最近一帧的 IOSurface，避免被 ARC 回收。
        private var retainedSurface: IOSurfaceRef?

        /// 内嵌的图像视图，用于可靠渲染 IOSurface 内容。
        /// 在 SwiftUI 的 NSViewRepresentable 中，直接设置 layer.contents 会被宿主覆盖，
        /// 使用 NSImageView 子视图可以绕过这个限制。
        private let imageView: NSImageView = {
            let iv = NSImageView()
            iv.autoresizingMask = [.width, .height]
            iv.imageScaling = .scaleProportionallyUpOrDown
            return iv
        }()

        // MARK: - 初始化

        public override init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            // 使用 NSImageView 作为内容渲染层，绕过 SwiftUI 对自定义 layer 的覆盖
            addSubview(imageView)
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
            let local = self.convert(event.locationInWindow, from: nil)
            let model = MouseEvent(
                phase: phase,
                button: button,
                x: Double(local.x),
                y: Double(local.y),
                clickCount: phase == .moved ? 0 : event.clickCount,
                modifiers: ModifierFlags.fromAppKitImported(event.modifierFlags)
            )
            self.onInputEvent?(.mouse(model))
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

        public override func updateLayer() {
            super.updateLayer()
            guard let surface = retainedSurface else {
                layer?.contents = nil
                return
            }
            let surfaceWidth = IOSurfaceGetWidth(surface)
            let surfaceHeight = IOSurfaceGetHeight(surface)
            // 确保 layer 以 Retina 密度渲染
            layer?.contentsScale = window?.backingScaleFactor ?? 1
            let ciImage = CIImage(ioSurface: surface)
            let cgImage = CIContext().createCGImage(ciImage, from: CGRect(x: 0, y: 0, width: surfaceWidth, height: surfaceHeight))
            if let cgImage {
                layer?.contents = cgImage
            }
        }

        public override func makeBackingLayer() -> CALayer {
            let layer = CALayer()
            layer.contentsGravity = .resize
            layer.magnificationFilter = .nearest
            layer.minificationFilter = .linear
            // 恢复为 false，让 layer 支持透明合成
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
            let scaleVal = window?.backingScaleFactor ?? 1
            let boundsStr = "\(self.bounds.width)×\(self.bounds.height)"
            if LumiInlinePreviewFacade.verbose {
                Self.logger.info("\(self.t) 绑定 surfaceID: \(surfaceID) — 当前: \(curIDStr), 边界: \(boundsStr), 窗口: \(winStr)")
            }
            
            // 🔍 诊断：记录 attach 开始
            Self.logger.info("📝[attach] 开始绑定 surfaceID=\(surfaceID)")
            Self.logger.info("📝[attach] 当前视图状态：bounds=\(boundsStr), window=\(winStr), scale=\(scaleVal)")
            
            guard let surface = IOSurfaceLookup(IOSurfaceID(surfaceID)) else {
                if LumiInlinePreviewFacade.verbose {
                    Self.logger.error("\(self.t)❌ IOSurfaceLookup 失败：surfaceID=\(surfaceID)")
                }
                Self.logger.error("📝[attach] ❌ IOSurfaceLookup 失败：surfaceID=\(surfaceID)")
                return
            }
            
            // 🔍 诊断：IOSurface 查找成功
            let surfaceWidth = IOSurfaceGetWidth(surface)
            let surfaceHeight = IOSurfaceGetHeight(surface)
            Self.logger.info("📝[attach] ✅ IOSurfaceLookup 成功：\(surfaceWidth)×\(surfaceHeight)")
            
            guard let layer = self.layer else {
                if LumiInlinePreviewFacade.verbose {
                    Self.logger.error("\(self.t) layer 为 nil，无法绑定 surface")
                }
                Self.logger.error("📝[attach] ❌ layer 为 nil，无法绑定 surface")
                return
            }
            
            // 🔍 诊断：layer 状态
            Self.logger.info("📝[attach] layer 状态：bounds=\(layer.bounds.width)×\(layer.bounds.height), contentsScale=\(layer.contentsScale)")
            
            currentSurfaceID = surfaceID
            retainedSurface = surface

            // 通过 NSImageView 渲染 IOSurface 内容
            // 在 SwiftUI NSViewRepresentable 中直接设置 layer.contents 会被宿主覆盖，
            // NSImageView 作为子视图可以可靠渲染。
            //
            // 关键：NSImage 的 size 必须是**逻辑尺寸**（像素 / backingScale），
            // 否则 2x 像素的图会被当作 1x 来缩放，导致模糊。
            let scale = window?.backingScaleFactor ?? 1
            let logicalWidth = CGFloat(surfaceWidth) / scale
            let logicalHeight = CGFloat(surfaceHeight) / scale
            let ciImage = CIImage(ioSurface: surface)
            let cgImage = CIContext().createCGImage(ciImage, from: CGRect(x: 0, y: 0, width: surfaceWidth, height: surfaceHeight))
            if let cgImage {
                let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: logicalWidth, height: logicalHeight))
                imageView.image = nsImage
                imageView.frame = bounds
                imageView.needsDisplay = true
                Self.logger.info("📝[attach] ✅ NSImageView.image 设置完成: \(surfaceWidth)×\(surfaceHeight) px → \(String(format: "%.0f", logicalWidth))×\(String(format: "%.0f", logicalHeight)) pt @\(scale)x")
            } else {
                Self.logger.error("📝[attach] ❌ CGImage 创建失败")
            }
        }

        /// 清空当前显示。
        public func detach() {
            currentSurfaceID = nil
            retainedSurface = nil
            imageView.image = nil
        }

        // MARK: - 尺寸通知

        public override func layout() {
            super.layout()
            // 同步 imageView 的 frame 到当前 bounds
            imageView.frame = bounds
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
