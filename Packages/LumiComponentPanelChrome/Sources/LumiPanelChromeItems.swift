import SwiftUI

@MainActor
public struct LumiPanelHeaderItem: Identifiable {
    public let id: String
    public let makeView: @MainActor () -> AnyView

    public init<Content: View>(
        id: String,
        @ViewBuilder content: @escaping @MainActor () -> Content
    ) {
        self.id = id
        self.makeView = { AnyView(content()) }
    }
}

@MainActor
public struct LumiPanelBottomTabItem: Identifiable {
    public let id: String
    public let order: Int
    public let title: String
    public let systemImage: String
    public let makeView: @MainActor () -> AnyView

    public init<Content: View>(
        id: String,
        order: Int,
        title: String,
        systemImage: String,
        @ViewBuilder content: @escaping @MainActor () -> Content
    ) {
        self.id = id
        self.order = order
        self.title = title
        self.systemImage = systemImage
        self.makeView = { AnyView(content()) }
    }
}

@MainActor
public struct LumiPanelRailTabItem: Identifiable {
    public let id: String
    public let order: Int
    public let title: String
    public let systemImage: String
    public let makeView: @MainActor () -> AnyView

    public init<Content: View>(
        id: String,
        order: Int,
        title: String,
        systemImage: String,
        @ViewBuilder content: @escaping @MainActor () -> Content
    ) {
        self.id = id
        self.order = order
        self.title = title
        self.systemImage = systemImage
        self.makeView = { AnyView(content()) }
    }
}
