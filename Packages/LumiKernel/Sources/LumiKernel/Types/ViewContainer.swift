import Foundation
import SwiftUI

// MARK: - View Container Item

/// 视图容器项
///
/// 定义一个可在 ActivityBar 中显示的视图容器。
/// 插件通过 `kernel.registerViewContainer()` 注册视图容器。
public struct ViewContainerItem: Identifiable, Sendable {
    public let id: String
    public let title: String
    public let systemImage: String
    public let order: Int
    public let showsRail: Bool
    public let showsPanelChrome: Bool
    public let makeView: @MainActor @Sendable () -> AnyView

    public init<Content: View>(
        id: String,
        title: String,
        systemImage: String,
        order: Int = 200,
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
public struct MenuBarContentItem: Identifiable, Sendable {
    public let id: String
    public let order: Int
    public let makeView: @MainActor @Sendable () -> AnyView

    public init<Content: View>(
        id: String,
        order: Int = 200,
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
public struct MenuBarPopupItem: Identifiable, Sendable {
    public let id: String
    public let order: Int
    public let makeView: @MainActor @Sendable () -> AnyView

    public init<Content: View>(
        id: String,
        order: Int = 200,
        @ViewBuilder content: @escaping @MainActor @Sendable () -> Content
    ) {
        self.id = id
        self.order = order
        self.makeView = { AnyView(content()) }
    }
}