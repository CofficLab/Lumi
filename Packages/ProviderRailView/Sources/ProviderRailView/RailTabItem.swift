import SwiftUI

// MARK: - Rail Tab Item

/// Rail（侧边栏）标签项（由外部注入）。
///
/// 类似 Lumi 的 `PanelRailTabItem`：在 Rail 侧边栏顶部的标签栏显示一个入口，
/// 点击切换活跃 tab 并展示对应内容。
@MainActor
public struct RailTabItem: Identifiable {
    public let id: String
    /// 标签所属的展示分组。通常使用贡献插件的稳定 id。
    ///
    /// ActivityBar 激活某插件后，由插件调用 `activateGroup(id:)`，Rail 只展示
    /// 该分组的标签；ProviderRailView 不需要依赖 ProviderActivityBar。
    public let groupID: String
    public let title: String
    public let systemImage: String
    public var order: Int
    /// tab 内容视图。
    public let makeView: @MainActor () -> AnyView

    public init<Content: View>(
        id: String,
        groupID: String = "default",
        title: String,
        systemImage: String,
        order: Int = 200,
        @ViewBuilder content: @escaping @MainActor () -> Content
    ) {
        self.id = id
        self.groupID = groupID
        self.title = title
        self.systemImage = systemImage
        self.order = order
        self.makeView = { AnyView(content()) }
    }
}
