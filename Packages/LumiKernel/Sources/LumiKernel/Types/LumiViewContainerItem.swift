import LumiCoreLayout
import SwiftUI

/// 视图容器项贡献
///
/// 插件通过实现 `LumiPlugin.viewContainers(kernel:)` 注入视图容器项。
/// 布局相关的可见性（rail/chat/content/panel）由 `WorkspaceState` 接管，
/// 这里只描述容器的基础信息：id、title、图标、可选视图。
@MainActor
public struct LumiViewContainerItem: Identifiable {
    public let id: String
    public let title: String
    public let systemImage: String
    public let makeView: @MainActor () -> AnyView

    public init<Content: View>(
        id: String,
        title: String,
        systemImage: String,
        @ViewBuilder content: @escaping @MainActor () -> Content
    ) {
        self.id = id
        self.title = title
        self.systemImage = systemImage
        self.makeView = { AnyView(content()) }
    }
}