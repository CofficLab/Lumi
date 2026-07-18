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
    public let fillsRemainingHeight: Bool
    /// When `false`, the stack layout does not render a divider after this section (e.g. toolbar headers that draw their own bottom border).
    public let showsTrailingDivider: Bool
    public let makeView: @MainActor () -> AnyView

    public init<Content: View>(
        id: String,
        order: Int,
        placement: LumiChatSectionPlacement = .stack,
        fillsRemainingHeight: Bool = false,
        showsTrailingDivider: Bool = true,
        @ViewBuilder content: @escaping @MainActor () -> Content
    ) {
        self.id = id
        self.order = order
        self.placement = placement
        self.fillsRemainingHeight = fillsRemainingHeight
        self.showsTrailingDivider = showsTrailingDivider
        self.makeView = { AnyView(content()) }
    }
}

@MainActor
public struct LumiChatSectionToolbarBarItem: Identifiable {
    public let id: String
    public let order: Int
    public let makeView: @MainActor () -> AnyView

    public init<Content: View>(
        id: String,
        order: Int,
        @ViewBuilder content: @escaping @MainActor () -> Content
    ) {
        self.id = id
        self.order = order
        self.makeView = { AnyView(content()) }
    }
}

@MainActor
public struct LumiChatSectionHeaderItem: Identifiable {
    public let id: String
    public let order: Int
    public let makeView: @MainActor () -> AnyView

    public init<Content: View>(
        id: String,
        order: Int,
        @ViewBuilder content: @escaping @MainActor () -> Content
    ) {
        self.id = id
        self.order = order
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