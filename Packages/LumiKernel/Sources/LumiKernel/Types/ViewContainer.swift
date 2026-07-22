import Foundation
import LumiCoreLayout
import SwiftUI

// MARK: - View Container Item

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
    /// 可选的视图工厂闭包。如果为 nil，表示该容器仅在 ActivityBar 中显示图标，不提供视图内容。
    public let makeView: (@MainActor @Sendable () -> AnyView)?

    /// 公开初始化器（含视图内容）
    public init<Content: View>(
        id: String,
        title: String,
        systemImage: String,
        @ViewBuilder content: @escaping @MainActor @Sendable () -> Content
    ) {
        self.id = id
        self.title = title
        self.systemImage = systemImage
        self.order = 200  // 默认值，内核会覆盖
        self.makeView = { AnyView(content()) }
    }

    /// 内部初始化器（用于内核设置 order）
    internal init<Content: View>(
        id: String,
        title: String,
        systemImage: String,
        order: Int,
        @ViewBuilder content: @escaping @MainActor @Sendable () -> Content
    ) {
        self.id = id
        self.title = title
        self.systemImage = systemImage
        self.order = order
        self.makeView = { AnyView(content()) }
    }

    /// 仅注册图标的初始化器（无视图内容）
    public init(
        id: String,
        title: String,
        systemImage: String
    ) {
        self.id = id
        self.title = title
        self.systemImage = systemImage
        self.order = 200
        self.makeView = nil
    }
}

// MARK: - Menu Bar Content Item

/// 菜单栏内容项
public typealias MenuBarContentItem = LumiMenuBarContentItem

// MARK: - Menu Bar Popup Item

/// 菜单栏弹出项
public typealias MenuBarPopupItem = LumiMenuBarPopupItem