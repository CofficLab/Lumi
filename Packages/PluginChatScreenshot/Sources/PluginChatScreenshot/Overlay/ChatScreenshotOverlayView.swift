import AppKit
import CoreGraphics
import Foundation

/// 单个屏幕遮罩的视图:接收鼠标拖选,绘制半透明遮罩 + 选区高亮
@MainActor
final class ChatScreenshotOverlayView: NSView {

    /// 全局选区(屏幕坐标,原点在左下,NSEvent.mouseLocation 风格)
    var selectionRect: CGRect = .zero

    /// 该视图所在的屏幕 frame(屏幕坐标),用于将全局 selectionRect 转 local
    let screenFrame: CGRect

    private var dragStart: CGPoint?

    var onSelectionChanged: ((CGRect) -> Void)?
    var onSelectionCompleted: ((CGRect) -> Void)?
    var onCancel: (() -> Void)?

    init(screenFrame: CGRect) {
        self.screenFrame = screenFrame
        super.init(frame: CGRect(origin: .zero, size: screenFrame.size))
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var acceptsFirstResponder: Bool { true }
    override var isFlipped: Bool { false }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.makeFirstResponder(self)
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let context = NSGraphicsContext.current?.cgContext else { return }

        // 半透明黑色遮罩全屏
        context.setFillColor(NSColor.black.withAlphaComponent(0.48).cgColor)
        context.fill(bounds)

        // 选区内部"挖空",显示原图(实际是透明,这里仅去掉遮罩)
        if let localRect = localSelectionRect {
            context.clear(localRect)
            // 边框
            let borderPath = CGPath(
                rect: localRect.insetBy(dx: 1, dy: 1),
                transform: nil
            )
            context.addPath(borderPath)
            context.setStrokeColor(NSColor.controlAccentColor.cgColor)
            context.setLineWidth(2)
            context.strokePath()
            drawSizeLabel(for: localRect)
        }

        drawHint()
    }

    // MARK: - Mouse handling

    override func mouseDown(with event: NSEvent) {
        let point = NSEvent.mouseLocation
        dragStart = point
        let initial = rectBetween(point, point)
        selectionRect = initial
        onSelectionChanged?(initial)
        needsDisplay = true
    }

    override func mouseDragged(with event: NSEvent) {
        guard let dragStart else { return }
        let current = NSEvent.mouseLocation
        let rect = rectBetween(dragStart, current)
        selectionRect = rect
        onSelectionChanged?(rect)
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        guard let dragStart else { return }
        let endPoint = NSEvent.mouseLocation
        self.dragStart = nil
        let rect = rectBetween(dragStart, endPoint)
        onSelectionChanged?(rect)
        onSelectionCompleted?(rect)
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {  // ESC
            onCancel?()
        } else {
            super.keyDown(with: event)
        }
    }

    // MARK: - Helpers

    private func rectBetween(_ start: CGPoint, _ end: CGPoint) -> CGRect {
        CGRect(
            x: min(start.x, end.x),
            y: min(start.y, end.y),
            width: abs(end.x - start.x),
            height: abs(end.y - start.y)
        )
    }

    /// 把全局屏幕坐标 selectionRect 转 local(view bounds)
    private var localSelectionRect: CGRect? {
        let intersection = selectionRect.intersection(screenFrame)
        guard !intersection.isNull, !intersection.isEmpty else { return nil }
        return intersection.offsetBy(dx: -screenFrame.minX, dy: -screenFrame.minY)
    }

    private func drawSizeLabel(for rect: CGRect) {
        let label = "\(Int(selectionRect.width)) × \(Int(selectionRect.height))"
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium),
            .foregroundColor: NSColor.white
        ]
        let attributed = NSAttributedString(string: label, attributes: attributes)
        let labelSize = attributed.size()
        let padding = CGSize(width: 8, height: 5)
        let bubbleSize = CGSize(
            width: labelSize.width + padding.width * 2,
            height: labelSize.height + padding.height * 2
        )
        let labelOrigin = CGPoint(
            x: max(8, min(rect.minX, bounds.maxX - bubbleSize.width - 8)),
            y: max(8, rect.minY - bubbleSize.height - 8)
        )
        let bubbleRect = CGRect(origin: labelOrigin, size: bubbleSize)

        NSColor.black.withAlphaComponent(0.72).setFill()
        NSBezierPath(roundedRect: bubbleRect, xRadius: 5, yRadius: 5).fill()
        attributed.draw(at: CGPoint(
            x: bubbleRect.minX + padding.width,
            y: bubbleRect.minY + padding.height
        ))
    }

    private func drawHint() {
        let hint = "Drag to select. Press ESC to cancel."
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13, weight: .medium),
            .foregroundColor: NSColor.white.withAlphaComponent(0.82)
        ]
        let attributed = NSAttributedString(string: hint, attributes: attributes)
        let size = attributed.size()
        attributed.draw(at: CGPoint(
            x: (bounds.width - size.width) / 2,
            y: 28
        ))
    }
}