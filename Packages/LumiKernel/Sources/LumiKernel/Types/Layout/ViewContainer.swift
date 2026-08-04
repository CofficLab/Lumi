import Foundation
import SwiftUI

// MARK: - View Container Item

/// 一个布局区域在视图容器中的可用性与默认展示策略。
///
/// `unsupported` 与 `hiddenByDefault` 的区别在于：前者不能由用户开启，
/// 后者只是首次进入时不展示，用户仍可在布局设置中开启。
public enum ViewContainerVisibility: Sendable {
    /// 此容器不提供该区域，用户不能将其开启。
    case unsupported
    /// 支持该区域，但默认隐藏，用户可以开启。
    case hiddenByDefault
    /// 支持该区域，默认展示，用户可以隐藏。
    case visibleByDefault
    /// 支持且始终展示，用户不能将其隐藏。
    case alwaysVisible

    /// 该容器是否允许用户改变该区域的可见性。
    public var allowsUserVisibilityOverride: Bool {
        switch self {
        case .hiddenByDefault, .visibleByDefault:
            true
        case .unsupported, .alwaysVisible:
            false
        }
    }

    /// 未设置用户覆盖时的可见性。
    public var defaultIsVisible: Bool {
        switch self {
        case .unsupported, .hiddenByDefault:
            false
        case .visibleByDefault, .alwaysVisible:
            true
        }
    }

    /// 根据用户覆盖解析最终可见性；不允许覆盖的策略始终使用其默认值。
    public func resolvedVisibility(userOverride: Bool?) -> Bool {
        allowsUserVisibilityOverride ? (userOverride ?? defaultIsVisible) : defaultIsVisible
    }
}

/// 视图容器项
///
/// 定义一个可在 ActivityBar 中显示的视图容器。
/// 插件通过 `LumiPlugin.viewContainers(kernel:)` 注册。
///
/// 布局相关的可见性（rail/chat/content/panel）由 `WorkspaceState` 接管。
/// 这里只描述容器的基础信息：id、title、图标、可选视图。
///
/// - `order` 由内核自动从插件继承，无需手动指定。
/// - `makeView` 可选，nil 表示仅注册图标。
public struct ViewContainerItem: Identifiable, Sendable {
    public let id: String
    public let title: String
    public let systemImage: String
    public var order: Int
    /// 当前容器是否围绕某个项目工作。
    public let supportsProject: Bool
    /// 可选的视图工厂闭包。如果为 nil，表示该容器仅在 ActivityBar 中显示图标，不提供视图内容。
    public let makeView: (@MainActor @Sendable () -> AnyView)?
    public let railVisibility: ViewContainerVisibility
    public let chatVisibility: ViewContainerVisibility
    public let panelHeaderVisibility: ViewContainerVisibility
    public let panelBodyVisibility: ViewContainerVisibility
    public let panelBottomVisibility: ViewContainerVisibility

    /// 公开初始化器（含视图内容）
    public init<Content: View>(
        id: String,
        title: String,
        systemImage: String,
        supportsProject: Bool = false,
        railVisibility: ViewContainerVisibility = .visibleByDefault,
        chatVisibility: ViewContainerVisibility = .visibleByDefault,
        panelHeaderVisibility: ViewContainerVisibility = .visibleByDefault,
        panelBodyVisibility: ViewContainerVisibility = .visibleByDefault,
        panelBottomVisibility: ViewContainerVisibility = .visibleByDefault,
        @ViewBuilder content: @escaping @MainActor @Sendable () -> Content
    ) {
        self.id = id
        self.title = title
        self.systemImage = systemImage
        self.order = 200  // 默认值，内核会覆盖
        self.supportsProject = supportsProject
        self.railVisibility = railVisibility
        self.chatVisibility = chatVisibility
        self.panelHeaderVisibility = panelHeaderVisibility
        self.panelBodyVisibility = panelBodyVisibility
        self.panelBottomVisibility = panelBottomVisibility
        self.makeView = { AnyView(content()) }
    }

    /// 内部初始化器（用于内核设置 order）
    internal init<Content: View>(
        id: String,
        title: String,
        systemImage: String,
        order: Int,
        supportsProject: Bool = false,
        railVisibility: ViewContainerVisibility = .visibleByDefault,
        chatVisibility: ViewContainerVisibility = .visibleByDefault,
        panelHeaderVisibility: ViewContainerVisibility = .visibleByDefault,
        panelBodyVisibility: ViewContainerVisibility = .visibleByDefault,
        panelBottomVisibility: ViewContainerVisibility = .visibleByDefault,
        @ViewBuilder content: @escaping @MainActor @Sendable () -> Content
    ) {
        self.id = id
        self.title = title
        self.systemImage = systemImage
        self.order = order
        self.supportsProject = supportsProject
        self.railVisibility = railVisibility
        self.chatVisibility = chatVisibility
        self.panelHeaderVisibility = panelHeaderVisibility
        self.panelBodyVisibility = panelBodyVisibility
        self.panelBottomVisibility = panelBottomVisibility
        self.makeView = { AnyView(content()) }
    }

    /// 仅注册图标的初始化器（无视图内容）
    public init(
        id: String,
        title: String,
        systemImage: String,
        supportsProject: Bool = false,
        railVisibility: ViewContainerVisibility = .visibleByDefault,
        chatVisibility: ViewContainerVisibility = .visibleByDefault,
        panelHeaderVisibility: ViewContainerVisibility = .visibleByDefault,
        panelBodyVisibility: ViewContainerVisibility = .visibleByDefault,
        panelBottomVisibility: ViewContainerVisibility = .visibleByDefault
    ) {
        self.id = id
        self.title = title
        self.systemImage = systemImage
        self.order = 200
        self.supportsProject = supportsProject
        self.railVisibility = railVisibility
        self.chatVisibility = chatVisibility
        self.panelHeaderVisibility = panelHeaderVisibility
        self.panelBodyVisibility = panelBodyVisibility
        self.panelBottomVisibility = panelBottomVisibility
        self.makeView = nil
    }
}

// MARK: - Menu Bar Content Item

/// 菜单栏内容项
public typealias MenuBarContentItem = LumiMenuBarContentItem

// MARK: - Menu Bar Popup Item

/// 菜单栏弹出项
public typealias MenuBarPopupItem = LumiMenuBarPopupItem
