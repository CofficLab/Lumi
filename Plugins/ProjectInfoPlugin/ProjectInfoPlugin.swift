import Foundation
import MagicKit
import OSLog
import SwiftUI

/// 项目信息插件：在列表视图中显示当前项目详细信息
class ProjectInfoPlugin: NSObject, SuperPlugin, PluginRegistrant, SuperLog {
    // MARK: - Plugin Properties

    /// 日志标识符
    nonisolated static let emoji = "📋"

    /// 是否启用该插件
    static let enable = true

    /// 是否启用详细日志输出
    nonisolated static let verbose = true

    /// 插件唯一标识符
    static var id: String = "ProjectInfoPlugin"

    /// 插件显示名称
    static var displayName: String = "项目信息"

    /// 插件功能描述
    static var description: String = "在列表视图中显示当前标签页和项目的详细信息"

    /// 插件图标名称
    static var iconName: String = "info.bubble"

    /// 是否可配置
    static var isConfigurable: Bool = true

    // MARK: - Instance

    /// 插件实例标签（用于识别唯一实例）
    var instanceLabel: String {
        Self.id
    }

    /// 插件单例实例
    static let shared = ProjectInfoPlugin()

    /// 私有初始化方法
    private override init() {}

    /// 检查插件是否被用户启用
    private var isUserEnabled: Bool {
        PluginSettingsStore.shared.isPluginEnabled(Self.id)
    }

    // MARK: - UI Contributions

    /// 添加列表视图
    /// - Parameters:
    ///   - tab: 标签页
    ///   - project: 项目对象
    /// - Returns: 列表视图
    func addListView(tab: String, project: Project?) -> AnyView? {
        guard isUserEnabled else { return nil }
        return AnyView(ProjectInfoListView(tab: tab, project: project))
    }
}

// MARK: - PluginRegistrant

extension ProjectInfoPlugin {
    /// 注册插件到插件注册表
    static func register() {
        guard enable else { return }

        Task {
            if Self.verbose {
                os_log("\(Self.t) 🚀 Register ProjectInfoPlugin")
            }

            await PluginRegistry.shared.register(id: id, order: 3) {
                ProjectInfoPlugin.shared
            }
        }
    }
}
