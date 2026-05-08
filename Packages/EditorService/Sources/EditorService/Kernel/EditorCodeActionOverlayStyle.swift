import SwiftUI

public struct EditorCodeActionOverlayStyle: Sendable {
    public let indicatorSize: CGFloat
    public let indicatorCornerRadius: CGFloat
    public let indicatorInsetX: CGFloat
    public let panelGap: CGFloat
    public let panelWidth: CGFloat
    public let maxPanelHeight: CGFloat

    public static let standard = EditorCodeActionOverlayStyle(
        indicatorSize: 20,
        indicatorCornerRadius: 6,
        indicatorInsetX: 28,
        panelGap: 8,
        panelWidth: 380,
        maxPanelHeight: 300
    )
}
