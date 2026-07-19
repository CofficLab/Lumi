import AppKit
import SwiftUI

/// 菜单栏内存单柱渲染器
struct MemoryMenuBarChartRenderer {

    // MARK: - Constants

    private static let barWidth: CGFloat = 4
    private static let trackCornerRadius: CGFloat = 2
    private static let barCornerRadius: CGFloat = 1.5
    private static let imageWidth: CGFloat = 10
    private static let imageHeight: CGFloat = 14

    // MARK: - Colors
    //
    // 内存柱渲染为单色模板图（`isTemplate = true`），由菜单栏统一着色，
    // 因此这里只用 `labelColor` 的不同透明度表达「填充柱」与「背景槽」，
    // 不再使用品牌紫色 / 警告红色（模板着色会覆盖任意颜色）。
    // 警告态（≥80%）用全不透明填充，与正常态的低透明槽 + 实心柱做视觉区分。

    private static let trackColor = NSColor.labelColor.withAlphaComponent(0.18)
    private static let barColor = NSColor.labelColor

    // MARK: - Public Methods

    static func makeImage(usage: Double) -> NSImage {
        let ratio = min(max(usage / 100.0, 0), 1)
        let imageSize = NSSize(width: imageWidth, height: imageHeight)

        let image = NSImage(size: imageSize)
        image.lockFocus()
        NSColor.clear.setFill()
        NSBezierPath(rect: NSRect(origin: .zero, size: imageSize)).fill()

        let trackRect = NSRect(
            x: (imageWidth - barWidth) / 2,
            y: 0,
            width: barWidth,
            height: imageHeight
        )

        // 背景槽
        let trackPath = NSBezierPath(roundedRect: trackRect, xRadius: trackCornerRadius, yRadius: trackCornerRadius)
        trackColor.setFill()
        trackPath.fill()

        // 填充柱
        let barHeight = max(1, imageHeight * ratio)
        let barRect = NSRect(
            x: trackRect.minX,
            y: 0,
            width: barWidth,
            height: barHeight
        )

        let barPath = NSBezierPath(roundedRect: barRect, xRadius: barCornerRadius, yRadius: barCornerRadius)
        barColor.setFill()
        barPath.fill()

        image.unlockFocus()
        image.isTemplate = true
        return image
    }

}

// MARK: - NSColor Extension

extension NSColor {
    convenience init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6:
            (r, g, b, a) = (int >> 16, int >> 8 & 0xFF, int & 0xFF, 255)
        case 8:
            (r, g, b, a) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (r, g, b, a) = (0, 0, 0, 255)
        }
        self.init(
            calibratedRed: CGFloat(r) / 255.0,
            green: CGFloat(g) / 255.0,
            blue: CGFloat(b) / 255.0,
            alpha: CGFloat(a) / 255.0
        )
    }
}

