import SwiftUI

struct EditorCodeActionIndicatorPlacement {
    let origin: CGPoint
    let panelOrigin: CGPoint
}

struct EditorCodeActionOverlayStyle {
    let indicatorSize: CGFloat
    let indicatorCornerRadius: CGFloat
    let indicatorInsetX: CGFloat
    let panelGap: CGFloat
    let panelWidth: CGFloat
    let maxPanelHeight: CGFloat

    static let standard = EditorCodeActionOverlayStyle(
        indicatorSize: 20,
        indicatorCornerRadius: 6,
        indicatorInsetX: 28,
        panelGap: 8,
        panelWidth: 380,
        maxPanelHeight: 300
    )
}
