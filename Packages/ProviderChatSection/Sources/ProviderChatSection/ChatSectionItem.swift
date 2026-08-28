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
    public let wrap: @MainActor @Sendable (AnyView) -> AnyView

    public init(
        id: String,
        order: Int = 200,
        wrap: @escaping @MainActor @Sendable (AnyView) -> AnyView
    ) {
        self.id = id
        self.order = order
        self.wrap = wrap
    }
}
