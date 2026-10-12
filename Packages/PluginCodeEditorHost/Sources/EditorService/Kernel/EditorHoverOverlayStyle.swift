import SwiftUI

public struct EditorHoverOverlayStyle: Sendable {
    public let cornerRadius: CGFloat
    public let borderColor: Color
    public let borderWidth: CGFloat
    public let shadowColor: Color
    public let shadowRadius: CGFloat
    public let shadowYOffset: CGFloat
    public let backgroundTop: Color
    public let backgroundBottom: Color
    public let labelBackground: Color
    public let labelForeground: Color
    public let contentPadding: CGFloat
    public let headerSpacing: CGFloat
    public let maxWidth: CGFloat
    public let minHeight: CGFloat
    public let maxHeight: CGFloat
    public let verticalGap: CGFloat
    public let outerPadding: CGFloat

    public static let standard = EditorHoverOverlayStyle(
        cornerRadius: 10,
        borderColor: Color(nsColor: .separatorColor).opacity(0.55),
        borderWidth: 0.75,
        shadowColor: .black.opacity(0.18),
        shadowRadius: 16,
        shadowYOffset: 8,
        backgroundTop: Color(nsColor: .labelColor).opacity(0.06),
        backgroundBottom: Color(nsColor: .tertiaryLabelColor).opacity(0.08),
        labelBackground: Color.accentColor.opacity(0.12),
        labelForeground: Color.accentColor,
        contentPadding: 12,
        headerSpacing: 8,
        maxWidth: 460,
        minHeight: 60,
        maxHeight: 320,
        verticalGap: 8,
        outerPadding: 8
    )
}
