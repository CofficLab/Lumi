import Foundation
import MagicKit
import OSLog
import SwiftUI

/// 欢迎插件：提供欢迎界面作为详情视图
class WelcomePlugin: NSObject, SuperPlugin, PluginRegistrant, SuperLog {
    // MARK: - Plugin Properties

    /// 日志标识符
    nonisolated static let emoji = "⭐️"

    /// 是否启用该插件
    static let enable = true

    /// 是否启用详细日志输出
    nonisolated static let verbose = true

    /// 插件唯一标识符
    static var id: String = "WelcomePlugin"

    /// 插件显示名称
    static var displayName: String = "欢迎页面"

    /// 插件功能描述
    static var description: String = "显示应用欢迎界面和使用指南"

    /// 插件图标名称
    static var iconName: String = "star.circle.fill"

    /// 是否可配置
    static var isConfigurable: Bool = true

    // MARK: - Instance

    /// 插件实例标签（用于识别唯一实例）
    var instanceLabel: String {
        Self.id
    }

    /// 插件单例实例
    static let shared = WelcomePlugin()

    /// 私有初始化方法
    private override init() {}

    /// 检查插件是否被用户启用
    private var isUserEnabled: Bool {
        PluginSettingsStore.shared.isPluginEnabled(Self.id)
    }

    // MARK: - UI Contributions

    /// 添加详情视图
    /// - Returns: 详情视图
    func addDetailView() -> AnyView? {
        guard isUserEnabled else { return nil }
        return AnyView(WelcomeView())
    }
}

// MARK: - PluginRegistrant

extension WelcomePlugin {
    /// 注册插件到插件注册表
    static func register() {
        guard enable else { return }

        Task {
            if Self.verbose {
                os_log("\(Self.t) 🚀 Register WelcomePlugin")
            }

            await PluginRegistry.shared.register(id: id, order: 0) {
                WelcomePlugin.shared
            }
        }
    }
}
