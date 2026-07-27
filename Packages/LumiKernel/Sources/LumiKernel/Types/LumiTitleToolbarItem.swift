import SwiftUI

/// 标题工具栏项贡献
///
/// 插件通过实现 `LumiPlugin.titleToolbarItems(kernel:)` 注入标题工具栏项。
@MainActor
public struct LumiTitleToolbarItem: Identifiable {
    public let id: String
    public let title: String
    public let placement: TitleToolbarPlacement
    public var order: Int
    public let makeView: @MainActor () -> AnyView

    public init<Content: View>(
        id: String,
        title: String,
        placement: TitleToolbarPlacement = .trailing,
        order: Int = 200,
        @ViewBuilder content: @escaping @MainActor () -> Content
    ) {
        self.id = id
        self.title = title
        self.placement = placement
        self.order = order
        self.makeView = { AnyView(content()) }
    }
}
