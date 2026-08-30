import SwiftUI

/// Stable identity for the currently visible chat workbench.
///
/// The chat shell is shared by many plugins, so a boolean such as
/// `isContextActive` is not enough to decide which plugin contribution should
/// be rendered. Plugins should use their own stable id here and never depend
/// on another plugin's implementation details.
@MainActor
public struct ChatContext: Identifiable, Equatable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let subtitle: String?
    public let systemImage: String?

    public init(
        id: String,
        title: String,
        subtitle: String? = nil,
        systemImage: String? = nil
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
    }

    /// The default chat workbench. Plugin launch suggestions remain available
    /// in this context so users can enter a plugin-specific workflow from chat.
    public static let defaultChat = ChatContext(
        id: "com.coffic.lumi.chat.default",
        title: "Chat",
        systemImage: "bubble.left.and.bubble.right"
    )
}

public enum ChatSectionScope: Equatable, Sendable {
    case global
    case context(String)

    public func matches(_ context: ChatContext?) -> Bool {
        switch self {
        case .global:
            return true
        case let .context(id):
            return context?.id == id
        }
    }
}

public enum ChatSectionPlacement: Sendable {
    case stack
    case bottomFixed
}

@MainActor
public struct ChatSectionItem: Identifiable, Sendable {
    public let id: String
    public var order: Int
    public let scope: ChatSectionScope
    public let placement: ChatSectionPlacement
    public let fillsRemainingHeight: Bool
    public let showsTrailingDivider: Bool
    public let makeView: @MainActor @Sendable () -> AnyView

    public init<Content: View>(
        id: String,
        order: Int = 200,
        scope: ChatSectionScope = .global,
        placement: ChatSectionPlacement = .stack,
        fillsRemainingHeight: Bool = false,
        showsTrailingDivider: Bool = true,
        @ViewBuilder content: @escaping @MainActor @Sendable () -> Content
    ) {
        self.id = id
        self.order = order
        self.scope = scope
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
    public let scope: ChatSectionScope
    public let placement: ChatSectionBarPlacement
    public let makeView: @MainActor @Sendable () -> AnyView

    public init<Content: View>(
        id: String,
        order: Int = 200,
        scope: ChatSectionScope = .global,
        placement: ChatSectionBarPlacement,
        @ViewBuilder content: @escaping @MainActor @Sendable () -> Content
    ) {
        self.id = id
        self.order = order
        self.scope = scope
        self.placement = placement
        self.makeView = { AnyView(content()) }
    }
}

/// 聊天分区根包装器：把整个 Chat 内容区（header / toolbar / 正文 / 输入区）
/// 再包一层，对应旧版插件的 `chatSectionRootWrapper` 贡献点（如主题包、
/// 权限蒙层等需要包裹整个聊天区的场景）。
///
/// 多个包装器按 `order` 升序链式叠加：`order` 小的先执行 `wrap`，因此
/// `order` 最小者位于最外层。未注册任何包装器时内容原样返回。
@MainActor
public struct ChatSectionRootWrapper: Identifiable, Sendable {
    public let id: String
    public var order: Int
    public let scope: ChatSectionScope
    public let wrap: @MainActor @Sendable (AnyView) -> AnyView

    public init(
        id: String,
        order: Int = 200,
        scope: ChatSectionScope = .global,
        wrap: @escaping @MainActor @Sendable (AnyView) -> AnyView
    ) {
        self.id = id
        self.order = order
        self.scope = scope
        self.wrap = wrap
    }
}
