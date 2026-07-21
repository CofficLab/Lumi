import Foundation
import LumiCoreLayout
import LumiCoreMenuBar
import SwiftUI

// MARK: - View Container Item

/// 视图容器项
///
/// 定义一个可在 ActivityBar 中显示的视图容器。
/// 插件通过 `kernel.registerViewContainer()` 注册视图容器。
///
/// 注意：`order` 由内核自动从插件继承，无需手动指定。
/// 注意：`makeView` 为可选，插件可仅注册图标而不提供视图内容。
public struct ViewContainerItem: Identifiable, Sendable {
    public let id: String
    public let title: String
    public let systemImage: String
    public let chatSection: LumiChatSectionLayout
    public var order: Int
    public let showsRail: Bool
    public let showsPanelChrome: Bool
    /// 可选的视图工厂闭包。如果为 nil，表示该容器仅在 ActivityBar 中显示图标，不提供视图内容。
    public let makeView: (@MainActor @Sendable () -> AnyView)?

    /// 公开初始化器（不包含 order，由内核自动设置）
    ///
    /// - Parameters:
    ///   - content: 视图内容闭包，传入空闭包 `{ EmptyView() }` 可表示无视图
    public init<Content: View>(
        id: String,
        title: String,
        systemImage: String,
        chatSection: LumiChatSectionLayout = .none,
        showsRail: Bool = false,
        showsPanelChrome: Bool = false,
        @ViewBuilder content: @escaping @MainActor @Sendable () -> Content
    ) {
        self.id = id
        self.title = title
        self.systemImage = systemImage
        self.chatSection = chatSection
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
        chatSection: LumiChatSectionLayout = .none,
        showsRail: Bool = false,
        showsPanelChrome: Bool = false,
        @ViewBuilder content: @escaping @MainActor @Sendable () -> Content
    ) {
        self.id = id
        self.title = title
        self.systemImage = systemImage
        self.order = order
        self.chatSection = chatSection
        self.showsRail = showsRail
        self.showsPanelChrome = showsPanelChrome
        self.makeView = { AnyView(content()) }
    }

    /// 仅注册图标的初始化器（无视图内容）
    ///
    /// 适用于插件仅需在 ActivityBar 中显示图标，而不提供实际视图的场景。
    public init(
        id: String,
        title: String,
        systemImage: String,
        chatSection: LumiChatSectionLayout = .none,
        showsRail: Bool = false,
        showsPanelChrome: Bool = false
    ) {
        self.id = id
        self.title = title
        self.systemImage = systemImage
        self.chatSection = chatSection
        self.order = 200
        self.showsRail = showsRail
        self.showsPanelChrome = showsPanelChrome
        self.makeView = nil
    }
}

// MARK: - Menu Bar Content Item

/// 菜单栏内容项
public typealias MenuBarContentItem = LumiMenuBarContentItem

// MARK: - Menu Bar Popup Item

/// 菜单栏弹出项
public typealias MenuBarPopupItem = LumiMenuBarPopupItem
