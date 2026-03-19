import Combine
import SwiftData
import SwiftUI

/// 全局服务 VM，管理应用状态和全局服务
///
/// GlobalVM 是 Lumi 应用的核心状态管理类，负责：
/// - 应用级别的状态（加载状态、错误信息）
/// - 主题管理
/// - 导航状态
/// - 应用模式切换
///
/// ## 状态类型
///
/// - **应用状态**: isLoading, errorMessage
/// - **主题**: themeManager
/// - **导航**: selectedNavigationId
/// - **模式**: selectedMode (App 模式 / Agent 模式)
///
/// ## 使用示例
///
/// ```swift
/// @StateObject private var globalVM = GlobalVM()
///
/// // 切换主题
/// globalVM.themeManager.setTheme(.aurora)
///
/// // 切换模式
/// globalVM.selectedMode = .agent
///
/// // 显示错误
/// globalVM.showError("网络连接失败")
/// ```
@MainActor
final class GlobalVM: ObservableObject {
    // MARK: - 应用状态

    /// 当前选中的设置标签
    ///
    /// 用于设置面板中的标签切换。
    /// 默认为 ".about"。
    @Published var selectedSettingTab: SettingTab = .about

    /// 应用是否正在加载
    ///
    /// 当应用执行耗时操作时设为 true，
    /// UI 可以根据此状态显示加载指示器。
    @Published var isLoading = false

    /// 应用错误信息
    ///
    /// 当发生错误时存储错误消息。
    /// 通过 showError() 设置，clearError() 清除。
    @Published var errorMessage: String?

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
    @Published var selectedMode: AppMode = .app

    // MARK: - 数据状态

    /// 活动状态文本
    ///
    /// 用于在状态栏显示当前活动信息。
    /// 例如："正在分析代码..."、"正在搜索..."
    @Published var activityStatus: String? = nil

    // MARK: - 初始化

    /// 初始化全局提供者
    ///
    /// 模式恢复由插件负责。
    init() {
        // no-op
    }

    // MARK: - 错误处理

    /// 显示错误信息
    ///
    /// 设置 errorMessage 并可触发 UI 显示错误提示。
    ///
    /// - Parameter message: 错误消息
    func showError(_ message: String) {
        errorMessage = message
        // 可以在这里添加错误显示逻辑，比如显示通知
    }

    /// 清除错误信息
    ///
    /// 重置 errorMessage 为 nil。
    func clearError() {
        errorMessage = nil
    }

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

    /// 获取当前导航的标题
    ///
    /// 根据 selectedNavigationId 获取导航项的标题。
    ///
    /// - Parameter pluginVM: 插件 VM
    /// - Returns: 当前选中导航的标题，如果未找到则返回空字符串
    func getCurrentNavigationTitle(pluginVM: PluginVM) -> String {
        guard let selectedId = selectedNavigationId else {
            return ""
        }

        let entries = pluginVM.getNavigationEntries()
        return entries.first(where: { $0.id == selectedId })?.title ?? ""
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
