import LumiCoreLayout
import SwiftUI

/// 视图容器项贡献
///
/// 插件通过实现 `LumiPlugin.viewContainers(kernel:)` 注入视图容器项。
@MainActor
public struct LumiViewContainerItem: Identifiable {
    public let id: String
    public let title: String
    public let systemImage: String
    public let chatSection: LumiChatSectionLayout
    public let showsRail: Bool
    public let showsPanelChrome: Bool
    public let makeView: @MainActor () -> AnyView

    public init<Content: View>(
        id: String,
        title: String,
        systemImage: String,
        chatSection: LumiChatSectionLayout = .none,
        showsRail: Bool = false,
        showsPanelChrome: Bool = false,
        @ViewBuilder content: @escaping @MainActor () -> Content
    ) {
        self.id = id
        self.title = title
        self.systemImage = systemImage
        self.chatSection = chatSection
        self.showsRail = showsRail
        self.showsPanelChrome = showsPanelChrome
        self.makeView = { AnyView(content()) }
    }
}
