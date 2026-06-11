import AppKit

/// Menu bar battery indicator renderer.
///
/// Shows a small battery icon filled proportionally to the battery level.
/// When charging, displays a bolt overlay.
struct BatteryMenuBarChartRenderer {

    // MARK: - Constants

    private static let imageWidth: CGFloat = 20
    private static let imageHeight: CGFloat = 14

    // Body of the battery
    private static let bodyWidth: CGFloat = 16
    private static let bodyHeight: CGFloat = 10
    private static let bodyCornerRadius: CGFloat = 2

    // Battery tip (nub on the right)
    private static let tipWidth: CGFloat = 2
    private static let tipHeight: CGFloat = 5

    // MARK: - Colors

    private static let normalColor = NSColor(hex: "30D158")
    private static let warningColor = NSColor(hex: "FF9F0A")
    private static let criticalColor = NSColor(hex: "FF453A")
    private static let chargingColor = NSColor(hex: "FFD60A")
    private static let trackColor = NSColor.labelColor.withAlphaComponent(0.15)

    // MARK: - Public Methods

    static func makeImage(level: Double, isCharging: Bool) -> NSImage {
        let ratio = min(max(level, 0), 1)
        let imageSize = NSSize(width: imageWidth, height: imageHeight)

        let image = NSImage(size: imageSize)
        image.lockFocus()
        NSColor.clear.setFill()
        NSBezierPath(rect: NSRect(origin: .zero, size: imageSize)).fill()

        // Battery body origin (centered vertically)
        let bodyX: CGFloat = 1
        let bodyY: CGFloat = (imageHeight - bodyHeight) / 2

        // Track (background)
        let bodyRect = NSRect(x: bodyX, y: bodyY, width: bodyWidth, height: bodyHeight)
        let trackPath = NSBezierPath(roundedRect: bodyRect, xRadius: bodyCornerRadius, yRadius: bodyCornerRadius)
        trackColor.setFill()
        trackPath.fill()

        // Fill level
        if ratio > 0 {
            let fillWidth = max(bodyWidth * ratio, bodyCornerRadius * 2)
            let fillRect = NSRect(x: bodyX, y: bodyY, width: fillWidth, height: bodyHeight)
            let fillPath = NSBezierPath(roundedRect: fillRect, xRadius: bodyCornerRadius, yRadius: bodyCornerRadius)
            fillColor(for: ratio, isCharging: isCharging).setFill()
            fillPath.fill()
        }

        // Battery tip (right side nub)
        let tipX = bodyX + bodyWidth
        let tipY = (imageHeight - tipHeight) / 2
        let tipRect = NSRect(x: tipX, y: tipY, width: tipWidth, height: tipHeight)
        let tipPath = NSBezierPath(roundedRect: tipRect, xRadius: 1, yRadius: 1)
        NSColor.labelColor.withAlphaComponent(0.3).setFill()
        tipPath.fill()

        // Charging bolt
        if isCharging {
            let boltAttrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 8, weight: .bold),
                .foregroundColor: chargingColor,
            ]
            let boltStr = NSAttributedString(string: "⚡", attributes: boltAttrs)
            let boltSize = boltStr.size()
            let boltX = bodyX + (bodyWidth - boltSize.width) / 2
            let boltY = bodyY + (bodyHeight - boltSize.height) / 2
            boltStr.draw(at: NSPoint(x: boltX, y: boltY))
        }

        image.unlockFocus()
        image.isTemplate = false
        return image
    }

    // MARK: - Private Methods

    private static func fillColor(for level: Double, isCharging: Bool) -> NSColor {
        if isCharging { return chargingColor }
        if level > 0.5 { return normalColor }
        if level > 0.2 { return warningColor }
        return criticalColor
    }
}
