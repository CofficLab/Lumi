import SwiftUI

/// Rail 标签的预定义业务分类。
public enum RailViewCategory: String, CaseIterable, Sendable {
    case chat
    case project
    case design
    case system
    case general
}

// MARK: - Rail Tab Item

/// Rail（侧边栏）标签项（由外部注入）。
///
/// 类似 Lumi 的 `PanelRailTabItem`：在 Rail 侧边栏顶部的标签栏显示一个入口，
/// 点击切换活跃 tab 并展示对应内容。
@MainActor
public struct RailTabItem: Identifiable {
    public let id: String
    /// 标签所属的业务分类，由贡献 RailView 的插件显式指定。
    public let category: RailViewCategory
    public let title: String
    public let systemImage: String
    public var order: Int
    /// tab 内容视图。
    public let makeView: @MainActor () -> AnyView

    public init<Content: View>(
        id: String,
        category: RailViewCategory,
        title: String,
        systemImage: String,
        order: Int = 200,
        @ViewBuilder content: @escaping @MainActor () -> Content
    ) {
        self.id = id
        self.category = category
        self.title = title
        self.systemImage = systemImage
        self.order = order
        self.makeView = { AnyView(content()) }
    }
}
