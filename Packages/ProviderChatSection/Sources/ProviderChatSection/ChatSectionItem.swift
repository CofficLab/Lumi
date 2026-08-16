import SwiftUI

public enum ChatSectionPlacement: Sendable {
    case stack
    case bottomFixed
}

@MainActor
public struct ChatSectionItem: Identifiable, Sendable {
    public let id: String
    public var order: Int
    public let placement: ChatSectionPlacement
    public let fillsRemainingHeight: Bool
    public let showsTrailingDivider: Bool
    public let makeView: @MainActor @Sendable () -> AnyView

    public init<Content: View>(
        id: String,
        order: Int = 200,
        placement: ChatSectionPlacement = .stack,
        fillsRemainingHeight: Bool = false,
        showsTrailingDivider: Bool = true,
        @ViewBuilder content: @escaping @MainActor @Sendable () -> Content
    ) {
        self.id = id
        self.order = order
        self.placement = placement
        self.fillsRemainingHeight = fillsRemainingHeight
        self.showsTrailingDivider = showsTrailingDivider
        self.makeView = { AnyView(content()) }
    }
}

public enum ChatSectionBarPlacement: Sendable {
    case header
    case toolbarLeading
    case toolbarTrailing
    case actionLeading
    case actionTrailing
}

@MainActor
public struct ChatSectionBarItem: Identifiable, Sendable {
    public let id: String
    public var order: Int
    public let placement: ChatSectionBarPlacement
    public let makeView: @MainActor @Sendable () -> AnyView

    public init<Content: View>(
        id: String,
        order: Int = 200,
        placement: ChatSectionBarPlacement,
        @ViewBuilder content: @escaping @MainActor @Sendable () -> Content
    ) {
        self.id = id
        self.order = order
        self.placement = placement
        self.makeView = { AnyView(content()) }
    }
}
