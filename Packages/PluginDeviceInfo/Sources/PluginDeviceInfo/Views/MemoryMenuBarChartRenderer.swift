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

    private static let normalColor = NSColor(hex: "7C6FFF")
    private static let warningColor = NSColor(hex: "FF6B6B")
    private static let trackColor = NSColor.labelColor.withAlphaComponent(0.12)

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
        barColor(for: usage).setFill()
        barPath.fill()

        image.unlockFocus()
        image.isTemplate = false
        return image
    }

    // MARK: - Private Methods

    private static func barColor(for usage: Double) -> NSColor {
        if usage >= 80 {
            return warningColor
        }
        return normalColor
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

