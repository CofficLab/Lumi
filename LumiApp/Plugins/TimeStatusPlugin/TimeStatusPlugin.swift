import Foundation
import MagicKit
import SwiftUI
import Combine
import MagicKit
import OSLog

/// 时间状态插件：在状态栏显示当前时间
actor TimeStatusPlugin: SuperPlugin, SuperLog {
    // MARK: - Plugin Properties

    /// 日志标识符
    nonisolated static let emoji = "🕐"

    /// 是否启用该插件
    static let enable = true

    /// 是否启用详细日志输出
    nonisolated static let verbose = true

    /// 插件唯一标识符
    static let id: String = "TimeStatusPlugin"

    /// 插件显示名称
    static let displayName: String = "时间显示"

    /// 插件功能描述
    static let description: String = "在状态栏显示当前时间"

    /// 插件图标名称
    static let iconName: String = "clock"

    /// 是否可配置
    static let isConfigurable: Bool = true
    
    /// 注册顺序
    static var order: Int { 6 }

    // MARK: - Instance

    /// 插件实例标签（用于识别唯一实例）
    nonisolated var instanceLabel: String {
        Self.id
    }

    /// 插件单例实例
    static let shared = TimeStatusPlugin()

    /// 初始化方法
    init() {}

    // MARK: - UI Contributions
}


