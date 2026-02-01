import Combine
import SwiftData
import SwiftUI

/// 应用级服务提供者，管理应用状态和全局服务
@MainActor
final class AppProvider: ObservableObject {
    // MARK: - 应用状态

    /// 当前选中的设置标签
    @Published var selectedSettingTab: SettingTab = .about

    /// 应用是否正在加载
    @Published var isLoading = false

    /// 应用错误信息
    @Published var errorMessage: String?

    // MARK: - 导航状态

    /// 当前选中的导航入口 ID
    @Published var selectedNavigationId: String?

    // MARK: - 数据状态

    /// 活动状态文本
    @Published var activityStatus: String? = nil

    // MARK: - SwiftData

    /// SwiftData模型上下文
    private let modelContext: ModelContext

    // MARK: - 初始化

    /// 初始化应用提供者
    init(modelContext: ModelContext? = nil) {
        // 初始化SwiftData上下文
        if let context = modelContext {
            self.modelContext = context
        } else {
            // 使用共享容器中的上下文
            self.modelContext = AppConfig.getContainer().mainContext
        }

        setupServices()
    }

    /// 设置应用服务
    private func setupServices() {
        // 初始化应用级别的服务
        loadInitialData()
    }

    /// 加载初始数据
    private func loadInitialData() {
        // 加载应用启动时需要的数据
    }

    // MARK: - 错误处理

    /// 显示错误信息
    /// - Parameter message: 错误消息
    func showError(_ message: String) {
        errorMessage = message
        // 可以在这里添加错误显示逻辑，比如显示通知
    }

    /// 清除错误信息
    func clearError() {
        errorMessage = nil
    }

    // MARK: - 导航管理

    /// 获取当前导航的内容视图
    /// - Parameter pluginProvider: 插件提供者
    /// - Returns: 当前选中导航的内容视图
    func getCurrentNavigationView(pluginProvider: PluginProvider) -> AnyView {
        guard let selectedId = selectedNavigationId else {
            return AnyView(EmptyView())
        }

        let entries = pluginProvider.getNavigationEntries()
        guard let selectedEntry = entries.first(where: { $0.id == selectedId }) else {
            return AnyView(EmptyView())
        }

        return selectedEntry.contentProvider()
    }

    // MARK: - 数据访问

    /// 获取模型上下文
    /// - Returns: SwiftData模型上下文
    func getModelContext() -> ModelContext {
        modelContext
    }
}

/// 设置标签枚举
enum SettingTab: String, CaseIterable {
    case about = "关于"

    var icon: String {
        switch self {
        case .about: return "info.circle"
        }
    }
}

// MARK: - Preview

#Preview("App - Small Screen") {
    ContentLayout()
        .hideSidebar()
        .hideTabPicker()
        .inRootView()
        .frame(width: 800, height: 600)
}

#Preview("App - Big Screen") {
    ContentLayout()
        .hideSidebar()
        .hideTabPicker()
        .inRootView()
        .frame(width: 1200, height: 1200)
}
