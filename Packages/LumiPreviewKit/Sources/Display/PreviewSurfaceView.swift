import AppKit
import CoreImage
import IOSurface
import SuperLogKit
import os

public extension LumiPreviewFacade {
    /// 预览的核心 NSView：
    ///
    /// - 显示路径：把 `IOSurfaceID` 解析为 `IOSurfaceRef` 后赋给 `layer.contents`。
    /// - 输入路径（`isInteractive == true` 时）：捕获鼠标 / 滚轮 / 键盘事件，
    ///   通过 `onInputEvent` 回调上抛，给 ViewModel 走 `forwardInputEvent` 命令送子进程。
    /// - 不持有任何窗口；本控件被嵌入 Lumi 自己的预览面板。
    @MainActor
    final class PreviewSurfaceView: NSView, @preconcurrency NSTextInputClient, SuperLog {
        nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "LumiPreviewKit.PreviewSurfaceView")
        public nonisolated static let emoji = "👁"
        public nonisolated static let verbose: Bool = true

        // MARK: - 公开属性

        /// 当 view 尺寸或 backing scale 变化时回调，参数：(逻辑尺寸, scale)。
        public var onSizeChange: ((CGSize, CGFloat) -> Void)?

        /// 是否捕获并上抛输入事件。`false` 时所有事件都让给 super，本视图行为等同纯显示。
        public var isInteractive: Bool = false

        /// 输入事件回调；仅在 `isInteractive == true` 时触发。
        public var onInputEvent: ((PreviewInputEvent) -> Void)?

        /// 子进程回传的当前 cursor 形状。
        public private(set) var cursorShape: PreviewCursorShape = .arrow

        /// 当前显示的 surface ID；nil 表示尚未附着任何 surface。
        public private(set) var currentSurfaceID: UInt32?

        /// 强引用最近一帧的 IOSurface，避免被 ARC 回收。
        private var retainedSurface: IOSurfaceRef?
        private let contentLayer = CALayer()
        private var contentPointSize: CGSize?
        private var hasIMEMarkedText = false
        private var markedText = ""
        private var inputTrackingArea: NSTrackingArea?

        var debugContentLayerFrame: CGRect {
            contentLayer.frame
        }

        // MARK: - 初始化

        public override init(frame frameRect: NSRect) {
            super.init(frame: frameRect)
            wantsLayer = true
            configureContentLayer()
            registerForDraggedTypes([.fileURL, .URL, .string])
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
        public override func mouseEntered(with event: NSEvent) {
            guard isInteractive else { super.mouseEntered(with: event); return }
            forwardMouse(event, phase: .entered, button: .left)
        }
        public override func mouseExited(with event: NSEvent) {
            guard isInteractive else { super.mouseExited(with: event); return }
            forwardMouse(event, phase: .exited, button: .left)
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
            let contentPoint = contentPoint(fromCanvasPoint: local)
            let model = ScrollWheelEvent(
                x: Double(contentPoint.x),
                y: Double(contentPoint.y),
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
            if inputContext?.handleEvent(event) == true {
                return
            }
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

        public override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
            guard isInteractive else { return [] }
            forwardDrag(sender, phase: .entered)
            return .copy
        }

        public override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
            guard isInteractive else { return [] }
            forwardDrag(sender, phase: .updated)
            return .copy
        }

        public override func draggingExited(_ sender: NSDraggingInfo?) {
            guard isInteractive, let sender else {
                super.draggingExited(sender)
                return
            }
            forwardDrag(sender, phase: .exited)
        }

        public override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
            guard isInteractive else { return false }
            forwardDrag(sender, phase: .perform)
            return true
        }

        // MARK: - 输入事件辅助

        private func forwardMouse(
            _ event: NSEvent,
            phase: MouseEvent.Phase,
            button: MouseEvent.Button
        ) {
            let local = self.convert(event.locationInWindow, from: nil)
            let contentPoint = self.contentPoint(fromCanvasPoint: local)
            let model = MouseEvent(
                phase: phase,
                button: button,
                x: Double(contentPoint.x),
                y: Double(contentPoint.y),
                clickCount: Self.usesSyntheticClickCount(phase) ? 0 : event.clickCount,
                modifiers: ModifierFlags.fromAppKitImported(event.modifierFlags)
            )
            self.onInputEvent?(.mouse(model))
        }

        private static func usesSyntheticClickCount(_ phase: MouseEvent.Phase) -> Bool {
            phase == .moved || phase == .entered || phase == .exited
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

        private func forwardDrag(_ sender: NSDraggingInfo, phase: DragDropEvent.Phase) {
            let location = convert(sender.draggingLocation, from: nil)
            let contentPoint = contentPoint(fromCanvasPoint: location)
            onInputEvent?(.dragAndDrop(.init(
                phase: phase,
                x: Double(contentPoint.x),
                y: Double(contentPoint.y),
                items: Self.dragItems(from: sender.draggingPasteboard),
                modifiers: ModifierFlags.fromAppKitImported(NSApplication.shared.currentEvent?.modifierFlags ?? [])
            )))
        }

        private static func dragItems(from pasteboard: NSPasteboard) -> [DragDropEvent.Item] {
            var items: [DragDropEvent.Item] = []
            if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: nil) as? [URL] {
                items.append(contentsOf: urls.map { .fileURL($0.path) })
            }
            if let string = pasteboard.string(forType: .string), !string.isEmpty {
                items.append(.string(string))
            }
            return items
        }

        // MARK: - Layer 配置

        public override var wantsUpdateLayer: Bool { true }

        public override func updateLayer() {
            super.updateLayer()
        }

        public override func makeBackingLayer() -> CALayer {
            let layer = CALayer()
            layer.magnificationFilter = .linear
            layer.minificationFilter = .linear
            // 恢复为 false，让 layer 支持透明合成
            layer.isOpaque = false
            layer.masksToBounds = true
            return layer
        }

        // MARK: - 公开方法

        /// 把指定的 `IOSurfaceID` 绑定到 layer.contents。
        ///
        /// - 重复绑定同一个 surface ID 时仍然会触发一次 `setNeedsDisplay()`，
        ///   因为子进程可能用同一个 surface 写了新像素而 ID 没变。
        public func attach(surfaceID: UInt32) {
            guard let surface = IOSurfaceLookup(IOSurfaceID(surfaceID)) else {
                Self.logger.warning("\(self.t)attach skipped: stale or unavailable IOSurface for surfaceID=\(surfaceID)")
                return
            }

            currentSurfaceID = surfaceID
            retainedSurface = surface
            let scaleVal = window?.backingScaleFactor ?? 1
            layer?.contentsScale = scaleVal
            ensureContentLayerAttached()

            let surfaceWidth = IOSurfaceGetWidth(surface)
            let surfaceHeight = IOSurfaceGetHeight(surface)
            let contentScale = scaleVal > 0 ? scaleVal : 1
            contentPointSize = CGSize(
                width: CGFloat(surfaceWidth) / contentScale,
                height: CGFloat(surfaceHeight) / contentScale
            )
            updateContentLayerFrame()
            let ciImage = CIImage(ioSurface: surface)
            let cgImage = CIContext().createCGImage(ciImage, from: CGRect(x: 0, y: 0, width: surfaceWidth, height: surfaceHeight))
            if let cgImage {
                contentLayer.contents = cgImage
            } else {
                Self.logger.error("\(self.t)❌ attach failed: CGImage creation failed for surfaceID=\(surfaceID) size=\(surfaceWidth)×\(surfaceHeight)")
            }
        }

        /// 清空当前显示。
        public func detach() {
            currentSurfaceID = nil
            retainedSurface = nil
            contentPointSize = nil
            contentLayer.contents = nil
            contentLayer.frame = .zero
        }

        // MARK: - 尺寸通知

        public override func layout() {
            super.layout()
            ensureContentLayerAttached()
            updateContentLayerFrame()
            notifySize()
        }

        public override func viewDidChangeBackingProperties() {
            super.viewDidChangeBackingProperties()
            layer?.contentsScale = window?.backingScaleFactor ?? 1
            contentLayer.contentsScale = window?.backingScaleFactor ?? 1
            updateContentLayerFrame()
            notifySize()
        }

        public override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            layer?.contentsScale = window?.backingScaleFactor ?? 1
            contentLayer.contentsScale = window?.backingScaleFactor ?? 1
            ensureContentLayerAttached()
            updateContentLayerFrame()
            window?.acceptsMouseMovedEvents = true
            notifySize()
        }

        public override func updateTrackingAreas() {
            super.updateTrackingAreas()
            if let inputTrackingArea {
                removeTrackingArea(inputTrackingArea)
            }
            let area = NSTrackingArea(
                rect: bounds,
                options: [.activeInKeyWindow, .inVisibleRect, .mouseEnteredAndExited, .mouseMoved],
                owner: self,
                userInfo: nil
            )
            addTrackingArea(area)
            inputTrackingArea = area
        }

        public override func resetCursorRects() {
            super.resetCursorRects()
            guard isInteractive else { return }
            addCursorRect(bounds, cursor: cursorShape.appKitCursor)
        }

        public func setCursorShape(_ shape: PreviewCursorShape) {
            guard cursorShape != shape else { return }
            cursorShape = shape
            discardCursorRects()
            window?.invalidateCursorRects(for: self)
        }

        // MARK: - 私有方法

        private func notifySize() {
            let scale = window?.backingScaleFactor ?? 1
            onSizeChange?(bounds.size, scale)
        }

        private func configureContentLayer() {
            contentLayer.contentsGravity = .resize
            contentLayer.magnificationFilter = .linear
            contentLayer.minificationFilter = .linear
            contentLayer.isOpaque = false
            contentLayer.masksToBounds = true
        }

        private func ensureContentLayerAttached() {
            guard let layer else { return }
            layer.contents = nil
            if contentLayer.superlayer !== layer {
                contentLayer.removeFromSuperlayer()
                layer.addSublayer(contentLayer)
            }
        }

        private func updateContentLayerFrame() {
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            contentLayer.frame = contentDisplayRect
            CATransaction.commit()
        }

        private var contentDisplayRect: CGRect {
            guard let contentPointSize,
                  contentPointSize.width > 0,
                  contentPointSize.height > 0,
                  bounds.width > 0,
                  bounds.height > 0 else {
                return bounds
            }
            let fitScale = min(bounds.width / contentPointSize.width, bounds.height / contentPointSize.height, 1)
            let fittedSize = CGSize(
                width: contentPointSize.width * fitScale,
                height: contentPointSize.height * fitScale
            )
            return CGRect(
                x: bounds.midX - fittedSize.width / 2,
                y: bounds.midY - fittedSize.height / 2,
                width: fittedSize.width,
                height: fittedSize.height
            )
        }

        private func contentPoint(fromCanvasPoint point: CGPoint) -> CGPoint {
            guard let contentPointSize else { return point }
            let displayRect = contentDisplayRect
            guard displayRect.width > 0, displayRect.height > 0 else { return point }
            let normalizedX = (point.x - displayRect.minX) / displayRect.width
            let normalizedY = (point.y - displayRect.minY) / displayRect.height
            return CGPoint(
                x: max(0, min(contentPointSize.width, normalizedX * contentPointSize.width)),
                y: max(0, min(contentPointSize.height, normalizedY * contentPointSize.height))
            )
        }

        // MARK: - NSTextInputClient

        public func insertText(_ string: Any, replacementRange: NSRange) {
            guard isInteractive else { return }
            onInputEvent?(.textInput(.init(
                phase: .insertText,
                text: Self.plainText(from: string),
                replacementRange: LumiPreviewFacade.Range(replacementRange)
            )))
        }

        public func setMarkedText(_ string: Any, selectedRange: NSRange, replacementRange: NSRange) {
            guard isInteractive else { return }
            hasIMEMarkedText = true
            markedText = Self.plainText(from: string)
            onInputEvent?(.textInput(.init(
                phase: .setMarkedText,
                text: markedText,
                selectedRange: LumiPreviewFacade.Range(selectedRange),
                replacementRange: LumiPreviewFacade.Range(replacementRange)
            )))
        }

        public func unmarkText() {
            hasIMEMarkedText = false
            markedText = ""
            onInputEvent?(.textInput(.init(phase: .unmarkText, text: "")))
        }

        public func selectedRange() -> NSRange {
            NSRange(location: NSNotFound, length: 0)
        }

        public func markedRange() -> NSRange {
            hasIMEMarkedText ? NSRange(location: 0, length: (markedText as NSString).length) : NSRange(location: NSNotFound, length: 0)
        }

        public func hasMarkedText() -> Bool {
            hasIMEMarkedText
        }

        public func attributedSubstring(forProposedRange range: NSRange, actualRange: NSRangePointer?) -> NSAttributedString? {
            actualRange?.pointee = NSRange(location: NSNotFound, length: 0)
            return nil
        }

        public func validAttributesForMarkedText() -> [NSAttributedString.Key] {
            []
        }

        public func firstRect(forCharacterRange range: NSRange, actualRange: NSRangePointer?) -> NSRect {
            actualRange?.pointee = range
            guard let window else { return .zero }
            return window.convertToScreen(convert(bounds, to: nil))
        }

        public func characterIndex(for point: NSPoint) -> Int {
            0
        }

        public override func doCommand(by selector: Selector) {
            // Keep command keys on the normal key event path; IME composition is handled above.
        }

        private static func plainText(from string: Any) -> String {
            if let attributed = string as? NSAttributedString {
                return attributed.string
            }
            return String(describing: string)
        }
    }
}
