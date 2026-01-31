import Foundation
import MagicKit
import OSLog
import SwiftUI

/// 工具栏按钮插件：在工具栏显示可点击的按钮
actor ToolbarButtonPlugin: SuperPlugin, SuperLog {
    // MARK: - Plugin Properties

    /// 日志标识符
    nonisolated static let emoji = "🔘"

    /// 是否启用该插件
    static let enable = true

    /// 是否启用详细日志输出
    nonisolated static let verbose = true

    /// 插件唯一标识符
    static var id: String = "ToolbarButtonPlugin"

    /// 插件显示名称
    static var displayName: String = "工具栏按钮"

    /// 插件功能描述
    static var description: String = "在工具栏右侧显示可点击的按钮"

    /// 插件图标名称
    static var iconName: String = "star"

    /// 是否可配置
    static var isConfigurable: Bool = true
    
    /// 注册顺序
    static var order: Int { 4 }

    // MARK: - Instance

    /// 插件实例标签（用于识别唯一实例）
    nonisolated var instanceLabel: String {
        Self.id
    }

    /// 插件单例实例
    static let shared = ToolbarButtonPlugin()

    /// 初始化方法
    init() {}

    /// 检查插件是否被用户启用
    private var isUserEnabled: Bool {
        PluginSettingsStore.shared.isPluginEnabled(Self.id)
    }

    // MARK: - UI Contributions

    /// 添加工具栏右侧视图
    /// - Returns: 工具栏右侧视图
    @MainActor func addToolBarTrailingView() -> AnyView? {
        return AnyView(ToolbarActionButton())
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
