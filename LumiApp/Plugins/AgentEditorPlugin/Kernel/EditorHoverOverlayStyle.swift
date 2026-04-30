import SwiftUI

struct EditorHoverOverlayPlacement {
    let anchor: UnitPoint
    let origin: CGPoint
    let cardSize: CGSize
    let isPresentedAboveSymbol: Bool
}

struct EditorHoverOverlayStyle {
    let cornerRadius: CGFloat
    let borderColor: Color
    let borderWidth: CGFloat
    let shadowColor: Color
    let shadowRadius: CGFloat
    let shadowYOffset: CGFloat
    let backgroundTop: Color
    let backgroundBottom: Color
    let labelBackground: Color
    let labelForeground: Color
    let contentPadding: CGFloat
    let headerSpacing: CGFloat
    let maxWidth: CGFloat
    let minHeight: CGFloat
    let maxHeight: CGFloat
    let verticalGap: CGFloat
    let outerPadding: CGFloat

    static let standard = EditorHoverOverlayStyle(
        cornerRadius: 10,
        borderColor: Color(nsColor: .separatorColor).opacity(0.55),
        borderWidth: 0.75,
        shadowColor: .black.opacity(0.18),
        shadowRadius: 16,
        shadowYOffset: 8,
        backgroundTop: AppUI.Color.semantic.textPrimary.opacity(0.06),
        backgroundBottom: AppUI.Color.semantic.textTertiary.opacity(0.08),
        labelBackground: AppUI.Color.semantic.primary.opacity(0.12),
        labelForeground: AppUI.Color.semantic.primary,
        contentPadding: 12,
        headerSpacing: 8,
        maxWidth: 460,
        minHeight: 60,
        maxHeight: 320,
        verticalGap: 8,
        outerPadding: 8
    )
}
