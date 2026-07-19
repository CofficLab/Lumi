import Foundation
import SwiftUI

// MARK: - View Container Item

/// 视图容器项
///
/// 定义一个可在 ActivityBar 中显示的视图容器。
/// 插件通过 `kernel.registerViewContainer()` 注册视图容器。
///
/// 注意：`order` 由内核自动从插件继承，无需手动指定。
public struct ViewContainerItem: Identifiable, Sendable {
    public let id: String
    public let title: String
    public let systemImage: String
    public var order: Int
    public let showsRail: Bool
    public let showsPanelChrome: Bool
    public let makeView: @MainActor @Sendable () -> AnyView

    /// 公开初始化器（不包含 order，由内核自动设置）
    public init<Content: View>(
        id: String,
        title: String,
        systemImage: String,
        showsRail: Bool = false,
        showsPanelChrome: Bool = false,
        @ViewBuilder content: @escaping @MainActor @Sendable () -> Content
    ) {
        self.id = id
        self.title = title
        self.systemImage = systemImage
        self.order = 200  // 默认值，内核会覆盖
        self.showsRail = showsRail
        self.showsPanelChrome = showsPanelChrome
        self.makeView = { AnyView(content()) }
    }

    /// 内部初始化器（用于内核设置 order）
    internal init<Content: View>(
        id: String,
        title: String,
        systemImage: String,
        order: Int,
        showsRail: Bool = false,
        showsPanelChrome: Bool = false,
        @ViewBuilder content: @escaping @MainActor @Sendable () -> Content
    ) {
        self.id = id
        self.title = title
        self.systemImage = systemImage
        self.order = order
        self.showsRail = showsRail
        self.showsPanelChrome = showsPanelChrome
        self.makeView = { AnyView(content()) }
    }
}

// MARK: - Menu Bar Content Item

/// 菜单栏内容项
///
/// 定义菜单栏中显示的内容视图。
///
/// 注意：`order` 由内核自动从插件继承，无需手动指定。
public struct MenuBarContentItem: Identifiable, Sendable {
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

// MARK: - Menu Bar Popup Item

/// 菜单栏弹出项
///
/// 定义菜单栏图标点击后显示的弹出视图。
///
/// 注意：`order` 由内核自动从插件继承，无需手动指定。
public struct MenuBarPopupItem: Identifiable, Sendable {
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