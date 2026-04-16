import AppKit
import SwiftUI

/// 菜单栏 CPU 柱状图图片生成器
struct CPUStatusBarChartRenderer {
    
    // MARK: - Constants
    
    private static let barWidth: CGFloat = 4
    private static let horizontalSpacing: CGFloat = 1
    private static let minimumBarHeight: CGFloat = 1
    private static let cornerRadius: CGFloat = 0.5
    private static let imageHeight: CGFloat = 14
    
    // MARK: - Public Methods
    
    static func makeImage(from usage: [Double]) -> NSImage {
        let barCount = max(usage.count, 1)
        let totalSpacing = horizontalSpacing * CGFloat(max(0, barCount - 1))
        let totalWidth = CGFloat(barCount) * barWidth + totalSpacing
        let imageSize = NSSize(width: totalWidth, height: imageHeight)
        
        let image = NSImage(size: imageSize)
        image.lockFocus()
        NSColor.clear.setFill()
        NSBezierPath(rect: NSRect(origin: .zero, size: imageSize)).fill()
        
        let values = normalizedValues(from: usage)
        let chartHeight = imageSize.height - 1
        
        for (index, value) in values.enumerated() {
            let x = CGFloat(index) * (barWidth + horizontalSpacing)
            let height = max(minimumBarHeight, chartHeight * value)
            let rect = NSRect(
                x: x,
                y: 0,
                width: barWidth,
                height: min(chartHeight, height)
            )
            
            let path = NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)
            NSColor.labelColor.setFill()
            path.fill()
        }
        
        image.unlockFocus()
        image.isTemplate = true
        return image
    }
    
    // MARK: - Private Methods
    
    private static func normalizedValues(from usage: [Double]) -> [CGFloat] {
        usage.map { CGFloat(min(max($0, 0), 100) / 100) }
    }
}

// MARK: - Preview

#Preview("CPU Status Bar Chart Renderer") {
    let image = CPUStatusBarChartRenderer.makeImage(from: [12, 28, 44, 76, 55, 18, 91, 63, 35, 47, 22, 68])
    return Image(nsImage: image)
        .interpolation(.none)
        .padding()
}
