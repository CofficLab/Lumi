import Foundation
import MagicKit
import SwiftUI
import OSLog

/// 应用信息插件：在工具栏显示应用信息图标，点击后弹出应用详情
class AppInfoPlugin: NSObject, SuperPlugin, PluginRegistrant, SuperLog {
    // MARK: - Plugin Properties

    /// 日志标识符
    nonisolated static let emoji = "ℹ️"

    /// 是否启用该插件
    static let enable = true

    /// 是否启用详细日志输出
    nonisolated static let verbose = true

    /// 插件唯一标识符
    static var id: String = "AppInfoPlugin"

    /// 插件显示名称
    static var displayName: String = "应用信息"

    /// 插件功能描述
    static var description: String = "在工具栏显示应用信息图标，点击后弹出应用详情面板"

    /// 插件图标名称
    static var iconName: String = "info.circle"

    /// 是否可配置
    static var isConfigurable: Bool = true

    // MARK: - Instance

    /// 插件实例标签（用于识别唯一实例）
    var instanceLabel: String {
        Self.id
    }

    /// 插件单例实例
    static let shared = AppInfoPlugin()

    /// 私有初始化方法
    private override init() {}

    /// 检查插件是否被用户启用
    private var isUserEnabled: Bool {
        PluginSettingsStore.shared.isPluginEnabled(Self.id)
    }

    // MARK: - UI Contributions

    /// 添加工具栏前导视图
    /// - Returns: 工具栏前导视图
    func addToolBarLeadingView() -> AnyView? {
        guard isUserEnabled else { return nil }
        return AnyView(AppInfoIconButton())
    }
}

// MARK: - PluginRegistrant

extension AppInfoPlugin {
    /// 注册插件到插件注册表
    static func register() {
        guard enable else { return }

        Task {
            if Self.verbose {
                os_log("\(Self.t) 🚀 Register AppInfoPlugin")
            }

            await PluginRegistry.shared.register(id: id, order: 5) {
                AppInfoPlugin.shared
            }
        }
    }
}
