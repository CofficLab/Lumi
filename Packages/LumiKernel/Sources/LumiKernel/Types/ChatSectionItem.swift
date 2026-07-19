import Foundation
import SwiftUI

// MARK: - Chat Section Placement

/// 聊天分区布局位置
public enum ChatSectionPlacement: Sendable {
    /// 堆叠布局
    case stack
    /// 底部固定
    case bottomFixed
}

// MARK: - Chat Section Item

/// 聊天分区项
///
/// 插件通过 `kernel.registerChatSectionItem()` 注册聊天界面分区。
///
/// 注意：`order` 由内核自动从插件继承，无需手动指定。
@MainActor
public struct ChatSectionItem: Identifiable, Sendable {
    public let id: String
    public var order: Int
    public let placement: ChatSectionPlacement
    public let fillsRemainingHeight: Bool
    /// 当为 `false` 时，堆叠布局不会在该分区后渲染分隔线（例如绘制自己底部边框的工具栏标题）。
    public let showsTrailingDivider: Bool
    public let makeView: @MainActor @Sendable () -> AnyView

    /// 公开初始化器（不包含 order）
    public init<Content: View>(
        id: String,
        placement: ChatSectionPlacement = .stack,
        fillsRemainingHeight: Bool = false,
        showsTrailingDivider: Bool = true,
        @ViewBuilder content: @escaping @MainActor @Sendable () -> Content
    ) {
        self.id = id
        self.order = 200  // 默认值，内核会覆盖
        self.placement = placement
        self.fillsRemainingHeight = fillsRemainingHeight
        self.showsTrailingDivider = showsTrailingDivider
        self.makeView = { AnyView(content()) }
    }

    /// 内部初始化器（用于内核设置 order）
    internal init<Content: View>(
        id: String,
        order: Int,
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

// MARK: - Chat Section Toolbar Bar Item

/// 聊天分区工具栏条项
///
/// 插件通过 `kernel.registerChatSectionToolbarBarItem()` 注册聊天分区工具栏条。
///
/// 注意：`order` 由内核自动从插件继承，无需手动指定。
@MainActor
public struct ChatSectionToolbarBarItem: Identifiable, Sendable {
    public let id: String
    public var order: Int
    public let makeView: @MainActor @Sendable () -> AnyView

    /// 公开初始化器（不包含 order）
    public init<Content: View>(
        id: String,
        @ViewBuilder content: @escaping @MainActor @Sendable () -> Content
    ) {
        self.id = id
        self.order = 200  // 默认值，内核会覆盖
        self.makeView = { AnyView(content()) }
    }

    /// 内部初始化器（用于内核设置 order）
    internal init<Content: View>(
        id: String,
        order: Int,
        @ViewBuilder content: @escaping @MainActor @Sendable () -> Content
    ) {
        self.id = id
        self.order = order
        self.makeView = { AnyView(content()) }
    }
}

// MARK: - Chat Section Header Item

/// 聊天分区标题项
///
/// 插件通过 `kernel.registerChatSectionHeaderItem()` 注册聊天分区标题。
///
/// 注意：`order` 由内核自动从插件继承，无需手动指定。
@MainActor
public struct ChatSectionHeaderItem: Identifiable, Sendable {
    public let id: String
    public var order: Int
    public let makeView: @MainActor @Sendable () -> AnyView

    /// 公开初始化器（不包含 order）
    public init<Content: View>(
        id: String,
        @ViewBuilder content: @escaping @MainActor @Sendable () -> Content
    ) {
        self.id = id
        self.order = 200  // 默认值，内核会覆盖
        self.makeView = { AnyView(content()) }
    }

    /// 内部初始化器（用于内核设置 order）
    internal init<Content: View>(
        id: String,
        order: Int,
        @ViewBuilder content: @escaping @MainActor @Sendable () -> Content
    ) {
        self.id = id
        self.order = order
        self.makeView = { AnyView(content()) }
    }
}

// MARK: - Chat Section Toolbar Placement

/// 聊天分区工具栏位置
public enum ChatSectionToolbarPlacement: Sendable {
    /// 左侧
    case leading
    /// 右侧
    case trailing
}

// MARK: - Chat Section Toolbar Item

/// 聊天分区工具栏项
///
/// 插件通过 `kernel.registerChatSectionToolbarItem()` 注册聊天分区工具栏按钮。
///
/// 注意：`order` 由内核自动从插件继承，无需手动指定。
@MainActor
public struct ChatSectionToolbarItem: Identifiable, Sendable {
    public let id: String
    public var order: Int
    public let placement: ChatSectionToolbarPlacement
    public let makeView: @MainActor @Sendable () -> AnyView

    /// 公开初始化器（不包含 order）
    public init<Content: View>(
        id: String,
        placement: ChatSectionToolbarPlacement,
        @ViewBuilder content: @escaping @MainActor @Sendable () -> Content
    ) {
        self.id = id
        self.order = 200  // 默认值，内核会覆盖
        self.placement = placement
        self.makeView = { AnyView(content()) }
    }

    /// 内部初始化器（用于内核设置 order）
    internal init<Content: View>(
        id: String,
        order: Int,
        placement: ChatSectionToolbarPlacement,
        @ViewBuilder content: @escaping @MainActor @Sendable () -> Content
    ) {
        self.id = id
        self.order = order
        self.placement = placement
        self.makeView = { AnyView(content()) }
    }
}