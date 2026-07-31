import SwiftUI

@MainActor
public struct LumiMenuBarContentItem: Identifiable {
    public let id: String
    public let order: Int
    public let makeView: @MainActor () -> AnyView

    public init<Content: View>(
        id: String,
        order: Int = 0,
        @ViewBuilder content: @escaping @MainActor () -> Content
    ) {
        self.id = id
        self.order = order
        self.makeView = { AnyView(content()) }
    }
}

@MainActor
public struct LumiMenuBarPopupItem: Identifiable {
    public let id: String
    public let order: Int
    public let makeView: @MainActor () -> AnyView

    public init<Content: View>(
        id: String,
        order: Int = 0,
        @ViewBuilder content: @escaping @MainActor () -> Content
    ) {
        self.id = id
        self.order = order
        self.makeView = { AnyView(content()) }
    }
}
