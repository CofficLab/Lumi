import Foundation
import MagicKit
import OSLog
import SwiftUI

/// 版本状态插件：在状态栏显示应用版本号
actor VersionStatusPlugin: SuperPlugin, SuperLog {
    // MARK: - Plugin Properties

    /// 日志标识符
    nonisolated static let emoji = "🔢"

    /// 是否启用该插件
    static let enable = true

    /// 是否启用详细日志输出
    nonisolated static let verbose = true

    /// 插件唯一标识符
    static var id: String = "VersionStatusPlugin"

    /// 插件显示名称
    static var displayName: String = "版本显示"

    /// 插件功能描述
    static var description: String = "在状态栏显示应用版本号"

    /// 插件图标名称
    static var iconName: String = "number"

    /// 是否可配置
    static var isConfigurable: Bool = true
    
    /// 注册顺序
    static var order: Int { 7 }

    // MARK: - Instance

    /// 插件实例标签（用于识别唯一实例）
    nonisolated var instanceLabel: String {
        Self.id
    }

    /// 插件单例实例
    static let shared = VersionStatusPlugin()

    /// 初始化方法
    init() {}

    // MARK: - UI Contributions

    /// 添加状态栏左侧视图
    /// - Returns: 状态栏左侧视图
    @MainActor func addStatusBarLeadingView() -> AnyView? {
        return AnyView(VersionStatusView())
    }

    /// 提供导航入口
    /// - Returns: 导航入口数组
    @MainActor func addNavigationEntries() -> [NavigationEntry]? {
        return [
            NavigationEntry.create(
                id: "\(Self.id).info",
                title: "版本信息",
                icon: "number.circle.fill",
                pluginId: Self.id
            ) {
                VersionInfoView()
            }
        ]
    }
}


