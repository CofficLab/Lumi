import Foundation
import MagicKit
import OSLog
import SwiftUI

/// 状态栏活动状态插件：展示当前长耗时操作的状态文本。
actor ActivityStatusPlugin: SuperPlugin, SuperLog {
    /// 日志标识符
    nonisolated static let emoji = "⌛️"

    /// 是否启用该插件
    nonisolated(unsafe) static let enable = true

    /// 是否启用详细日志输出
    nonisolated static let verbose = true

    nonisolated(unsafe) static let shared = ActivityStatusPlugin()
    nonisolated(unsafe) static let label = "ActivityStatus"

    /// 插件的唯一标识符，用于设置管理
    nonisolated(unsafe) static var id: String = "ActivityStatus"

    /// 插件显示名称
    nonisolated(unsafe) static var displayName: String = "ActivityStatus"

    /// 插件描述
    nonisolated(unsafe) static var description: String = "在状态栏显示当前长耗时操作的状态"

    /// 插件图标名称
    nonisolated(unsafe) static var iconName: String = "hourglass"

    /// 插件是否可配置（是否在设置中由用户控制启用/停用）
    nonisolated(unsafe) static var isConfigurable: Bool = false

    /// 注册顺序
    nonisolated(unsafe) static var order: Int { 10 }
}

// MARK: - PluginRegistrant

// MARK: - Preview

#Preview("App") {
    ContentLayout()
        .hideSidebar()
        .hideTabPicker()
        .inRootView()
        .withDebugBar()
}
