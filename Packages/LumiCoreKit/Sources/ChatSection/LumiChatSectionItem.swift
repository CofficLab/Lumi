import SwiftUI

public enum LumiChatSectionPlacement: Sendable {
    case stack
    case bottomFixed
}

@MainActor
public struct LumiChatSectionItem: Identifiable {
    public let id: String
    public let order: Int
    public let placement: LumiChatSectionPlacement
    public let makeView: @MainActor () -> AnyView

    public init<Content: View>(
        id: String,
        order: Int,
        placement: LumiChatSectionPlacement = .stack,
        @ViewBuilder content: @escaping @MainActor () -> Content
    ) {
        self.id = id
        self.order = order
        self.placement = placement
        self.makeView = { AnyView(content()) }
    }
}

public enum LumiChatSectionToolbarPlacement: Sendable {
    case leading
    case trailing
}

@MainActor
public struct LumiChatSectionToolbarItem: Identifiable {
    public let id: String
    public let order: Int
    public let placement: LumiChatSectionToolbarPlacement
    public let makeView: @MainActor () -> AnyView

    public init<Content: View>(
        id: String,
        order: Int,
        placement: LumiChatSectionToolbarPlacement,
        @ViewBuilder content: @escaping @MainActor () -> Content
    ) {
        self.id = id
        self.order = order
        self.placement = placement
        self.makeView = { AnyView(content()) }
    }
}
