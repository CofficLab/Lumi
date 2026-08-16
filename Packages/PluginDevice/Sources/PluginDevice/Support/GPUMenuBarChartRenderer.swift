import AppKit
import LumiUI
import SwiftUI

/// 菜单栏 GPU 单柱渲染器
struct GPUMenuBarChartRenderer {

    // MARK: - Constants

    private static let barWidth: CGFloat = 4
    private static let trackCornerRadius: CGFloat = 2
    private static let barCornerRadius: CGFloat = 1.5
    private static let imageWidth: CGFloat = 10
    private static let imageHeight: CGFloat = 14

    // MARK: - Colors
    //
    // GPU 单柱在菜单栏里渲染为带色位图(`isTemplate = false`),颜色取自当前 LumiTheme,
    // 这样它会跟随用户主题(info / error),而不是写死的紫色/红色。
    // 菜单栏 NSImage 始终在主线程绘制(`DeviceInfoMenuBarSnapshot` 由 RunLoop.main 上的
    // sink 构造),故用 `MainActor.assumeIsolated` 取主题色。

    private static var trackColor: NSColor { NSColor.labelColor.withAlphaComponent(0.12) }

    private static var normalColor: NSColor {
        MainActor.assumeIsolated { NSColor(currentTheme.info) }
    }

    private static var warningColor: NSColor {
        MainActor.assumeIsolated { NSColor(currentTheme.error) }
    }

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

        // Background track
        let trackPath = NSBezierPath(roundedRect: trackRect, xRadius: trackCornerRadius, yRadius: trackCornerRadius)
        trackColor.setFill()
        trackPath.fill()

        // Filled bar
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
