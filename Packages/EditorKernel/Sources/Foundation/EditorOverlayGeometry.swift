import CoreGraphics

/// 悬停卡片相对于锚点的放置方位（替代 SwiftUI.UnitPoint，保持内核无 UI 依赖）。
public enum EditorOverlayAnchor: Equatable, Sendable {
    case topLeading
    case bottomLeading
}

public struct EditorHoverOverlayPlacement: Equatable, Sendable {
    public let anchor: EditorOverlayAnchor
    public let origin: CGPoint
    public let cardSize: CGSize
    public let isPresentedAboveSymbol: Bool

    public init(anchor: EditorOverlayAnchor, origin: CGPoint, cardSize: CGSize, isPresentedAboveSymbol: Bool) {
        self.anchor = anchor
        self.origin = origin
        self.cardSize = cardSize
        self.isPresentedAboveSymbol = isPresentedAboveSymbol
    }
}

public struct EditorCodeActionIndicatorPlacement: Equatable, Sendable {
    public let origin: CGPoint
    public let panelOrigin: CGPoint

    public init(origin: CGPoint, panelOrigin: CGPoint) {
        self.origin = origin
        self.panelOrigin = panelOrigin
    }
}
