import Foundation
import OSLog
import MagicKit
import SwiftUI

/// 状态栏活动状态插件：展示当前长耗时操作的状态文本。
class ActivityStatusPlugin: NSObject, SuperPlugin, PluginRegistrant, SuperLog {
    /// 日志标识符
    nonisolated static let emoji = "⌛️"

    /// 是否启用该插件
    static let enable = true

    /// 是否启用详细日志输出
    nonisolated static let verbose = true

    static let shared = ActivityStatusPlugin()
    static let label = "ActivityStatus"

    /// 插件的唯一标识符，用于设置管理
    static var id: String = "ActivityStatus"

    /// 插件显示名称
    static var displayName: String = "ActivityStatus"

    /// 插件描述
    static var description: String = "在状态栏显示当前长耗时操作的状态"

    /// 插件图标名称
    static var iconName: String = "hourglass"

    /// 插件是否可配置（是否在设置中由用户控制启用/停用）
    static var isConfigurable: Bool = false

    /// 插件实例标签（用于识别唯一实例）
    var instanceLabel: String {
        Self.id
    }

    private override init() {}

    /// 检查插件是否被用户启用
    private var isUserEnabled: Bool {
        PluginSettingsStore.shared.isPluginEnabled(Self.id)
    }

    /// 添加状态栏左侧视图
    /// - Returns: 要添加到状态栏左侧的视图，如果不需要则返回nil
    func addStatusBarLeadingView() -> AnyView? {
        guard isUserEnabled else { return nil }
        return AnyView(ActivityStatusTile())
    }

    /// 添加工具栏前导视图
    /// - Returns: 要添加到工具栏前导的视图，如果不需要则返回nil
    func addToolBarLeadingView() -> AnyView? {
        nil
    }

    /// 添加工具栏右侧视图
    /// - Returns: 要添加到工具栏右侧的视图，如果不需要则返回nil
    func addToolBarTrailingView() -> AnyView? {
        nil
    }

    /// 添加状态栏右侧视图
    /// - Returns: 要添加到状态栏右侧的视图，如果不需要则返回nil
    func addStatusBarTrailingView() -> AnyView? {
        nil
    }

    /// 添加详情视图
    /// - Returns: 要添加的详情视图，如果不需要则返回nil
    func addDetailView() -> AnyView? {
        nil
    }

    /// 添加列表视图
    /// - Parameters:
    ///   - tab: 标签页
    ///   - project: 项目对象
    /// - Returns: 要添加的列表视图，如果不需要则返回nil
    func addListView(tab: String, project: Project?) -> AnyView? {
        nil
    }

    /// 添加侧边栏视图
    /// - Returns: 要添加到侧边栏的视图，如果不需要则返回nil
    func addSidebarView() -> AnyView? {
        nil
    }
}

// MARK: - PluginRegistrant

extension ActivityStatusPlugin {
    /// 注册插件到插件注册表
    static func register() {
        guard enable else { return }

        Task {
            if Self.verbose {
                os_log("\(Self.t) 🚀 Register ActivityStatusPlugin")
            }

            await PluginRegistry.shared.register(id: Self.label, order: 10) {
                ActivityStatusPlugin.shared
            }
        }
    }
}

// MARK: - Preview

#Preview("App - Small Screen") {
    ContentLayout()
        .hideSidebar()
        .hideTabPicker()
        .inRootView()
        .frame(width: 800)
        .frame(height: 600)
}

#Preview("App - Big Screen") {
    ContentLayout()
        .hideSidebar()
        .inRootView()
        .frame(width: 1200)
        .frame(height: 1200)
}
