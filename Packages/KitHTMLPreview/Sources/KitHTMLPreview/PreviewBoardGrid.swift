import AppKit
import SwiftUI

/// 预览画布的背景网格。
///
/// 在预览区域底层绘制等间距的浅色参考线，便于对齐内容。不响应点击。
public struct PreviewBoardGrid: View {
    private let spacing: CGFloat = 24

    public init() {}

    public var body: some View {
        Canvas { context, size in
            drawGrid(
                context: &context,
                size: size,
                spacing: spacing,
                color: NSColor.separatorColor.withAlphaComponent(0.04),
                lineWidth: 1
            )
        }
        .allowsHitTesting(false)
    }

    private func drawGrid(
        context: inout GraphicsContext,
        size: CGSize,
        spacing: CGFloat,
        color: NSColor,
        lineWidth: CGFloat
    ) {
        guard spacing > 0 else { return }

        var path = Path()
        var x: CGFloat = 0
        while x <= size.width {
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: size.height))
            x += spacing
        }

        var y: CGFloat = 0
        while y <= size.height {
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: size.width, y: y))
            y += spacing
        }

        context.stroke(path, with: .color(Color(nsColor: color)), lineWidth: lineWidth)
    }
}
