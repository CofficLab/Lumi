import SwiftUI

@MainActor
public struct LumiRootOverlayItem: Identifiable {
    public let id: String
    public let order: Int
    private let wrap: @MainActor (AnyView) -> AnyView

    public init(
        id: String,
        order: Int = 0,
        wrap: @escaping @MainActor (AnyView) -> AnyView
    ) {
        self.id = id
        self.order = order
        self.wrap = wrap
    }

    public init<Overlay: View>(
        id: String,
        order: Int = 0,
        @ViewBuilder overlay: @escaping @MainActor (AnyView) -> Overlay
    ) {
        self.id = id
        self.order = order
        self.wrap = { content in AnyView(overlay(content)) }
    }

    public func apply(to content: AnyView) -> AnyView {
        wrap(content)
    }
}
