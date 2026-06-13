import SwiftUI

public struct EditorHoverOverlayPlacement: Equatable, Sendable {
    public let anchor: UnitPoint
    public let origin: CGPoint
    public let cardSize: CGSize
    public let isPresentedAboveSymbol: Bool

    public init(anchor: UnitPoint, origin: CGPoint, cardSize: CGSize, isPresentedAboveSymbol: Bool) {
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
