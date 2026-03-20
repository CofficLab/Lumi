import Combine
import SwiftUI

/// 全局服务 VM：主题、侧边栏导航、App/Agent 模式等。
@MainActor
final class GlobalVM: ObservableObject {
    // MARK: - 主题管理

    /// 主题管理器
    ///
    /// 负责管理应用的主题切换和样式。
    /// 支持多种主题：Aurora, Nebula, Midnight, etc.
    let themeManager = MystiqueThemeManager()

    // MARK: - 导航状态

    /// 当前选中的导航入口 ID
    ///
    /// 对应插件提供的 NavigationEntry.id。
    /// 用于在侧边栏中高亮当前选中的导航项。
    @Published var selectedNavigationId: String?

    /// 当前选中的应用模式
    ///
    /// Lumi 支持两种模式：
    /// - `.app`: 应用模式，传统的工具应用
    /// - `.agent`: Agent 模式，AI 助手对话模式
    ///
    /// 模式选择持久化由插件负责。
    @Published var selectedMode: AppMode = .agent

    // MARK: - 导航管理

    /// 当前导航是否有可显示的内容
    ///
    /// - Parameter pluginVM: 插件 VM
    func hasCurrentNavigationContent(pluginVM: PluginVM) -> Bool {
        guard let selectedId = selectedNavigationId else { return false }
        return pluginVM.getNavigationEntries().contains { $0.id == selectedId }
    }

    /// 获取当前导航的内容视图
    ///
    /// 根据 selectedNavigationId 从插件提供的导航入口中查找对应的视图。
    ///
    /// - Parameter pluginVM: 插件 VM
    func getCurrentNavigationView(pluginVM: PluginVM) -> AnyView {
        guard let selectedId = selectedNavigationId else {
            return AnyView(EmptyView())
        }

        let entries = pluginVM.getNavigationEntries()
        guard let selectedEntry = entries.first(where: { $0.id == selectedId }) else {
            return AnyView(EmptyView())
        }

        return selectedEntry.contentProvider()
    }
}

// MARK: - Preview

#Preview("App - Small Screen") {
    ContentLayout()
        .hideSidebar()
        .inRootView()
        .frame(width: 800, height: 600)
}

#Preview("App - Big Screen") {
    ContentLayout()
        .hideSidebar()
        .inRootView()
        .frame(width: 1200, height: 1200)
}
