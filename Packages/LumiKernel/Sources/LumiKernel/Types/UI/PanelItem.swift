import Foundation
import SwiftUI

// MARK: - Panel Header Item

/// 面板顶部标题栏项
///
/// 插件通过 `kernel.registerPanelHeaderItem()` 注册面板顶部内容。
@MainActor
public struct PanelHeaderItem: Identifiable, Sendable {
    public let id: String
    public let makeView: @MainActor @Sendable () -> AnyView

    public init<Content: View>(
        id: String,
        @ViewBuilder content: @escaping @MainActor @Sendable () -> Content
    ) {
        self.id = id
        self.makeView = { AnyView(content()) }
    }
}

// MARK: - Panel Bottom Tab Item

/// 面板底部标签项
///
/// 插件通过 `kernel.registerPanelBottomTabItem()` 注册面板底部标签。
///
/// 注意：`order` 由内核自动从插件继承，无需手动指定。
@MainActor
public struct PanelBottomTabItem: Identifiable, Sendable {
    public let id: String
    public var order: Int
    public let title: String
    public let systemImage: String
    public let makeView: @MainActor @Sendable () -> AnyView

    /// 公开初始化器（不包含 order）
    public init<Content: View>(
        id: String,
        title: String,
        systemImage: String,
        @ViewBuilder content: @escaping @MainActor @Sendable () -> Content
    ) {
        self.id = id
        self.order = 200  // 默认值，内核会覆盖
        self.title = title
        self.systemImage = systemImage
        self.makeView = { AnyView(content()) }
    }

    /// 内部初始化器（用于内核设置 order）
    internal init<Content: View>(
        id: String,
        order: Int,
        title: String,
        systemImage: String,
        @ViewBuilder content: @escaping @MainActor @Sendable () -> Content
    ) {
        self.id = id
        self.order = order
        self.title = title
        self.systemImage = systemImage
        self.makeView = { AnyView(content()) }
    }
}

// MARK: - Panel Rail Tab Item

/// 侧边栏标签项的可见范围。
public enum PanelRailTabVisibility: Sendable, Equatable {
    /// 在所有 ViewContainer 中可见。
    case always
    /// 仅在指定 ViewContainer 中可见。
    case viewContainer(id: String)

    /// 判断标签项是否应在指定 ViewContainer 中展示。
    public func isVisible(in viewContainerID: String) -> Bool {
        switch self {
        case .always:
            true
        case .viewContainer(let id):
            id == viewContainerID
        }
    }
}

/// 侧边栏标签项
///
/// 插件通过 `kernel.registerPanelRailTabItem()` 注册侧边栏标签。
///
/// 注意：`order` 由内核自动从插件继承，无需手动指定。
@MainActor
public struct PanelRailTabItem: Identifiable, Sendable {
    public let id: String
    public var order: Int
    public let title: String
    public let systemImage: String
    public let visibility: PanelRailTabVisibility
    public let makeView: @MainActor @Sendable () -> AnyView

    /// 公开初始化器（不包含 order）
    public init<Content: View>(
        id: String,
        title: String,
        systemImage: String,
        visibility: PanelRailTabVisibility = .always,
        @ViewBuilder content: @escaping @MainActor @Sendable () -> Content
    ) {
        self.id = id
        self.order = 200  // 默认值，内核会覆盖
        self.title = title
        self.systemImage = systemImage
        self.visibility = visibility
        self.makeView = { AnyView(content()) }
    }

    /// 内部初始化器（用于内核设置 order）
    internal init<Content: View>(
        id: String,
        order: Int,
        title: String,
        systemImage: String,
        visibility: PanelRailTabVisibility = .always,
        @ViewBuilder content: @escaping @MainActor @Sendable () -> Content
    ) {
        self.id = id
        self.order = order
        self.title = title
        self.systemImage = systemImage
        self.visibility = visibility
        self.makeView = { AnyView(content()) }
    }
}
