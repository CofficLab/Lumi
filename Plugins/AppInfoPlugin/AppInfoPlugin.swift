import Foundation
import MagicKit
import SwiftUI
import OSLog

/// 应用信息插件：在工具栏显示应用信息图标，点击后弹出应用详情
actor AppInfoPlugin: SuperPlugin, SuperLog {
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
    
    /// 注册顺序
    static var order: Int { 5 }

    // MARK: - Instance

    /// 插件实例标签（用于识别唯一实例）
    nonisolated var instanceLabel: String {
        Self.id
    }

    /// 插件单例实例
    static let shared = AppInfoPlugin()

    /// 初始化方法
    init() {}

    // MARK: - UI Contributions

    /// 添加工具栏前导视图
    /// - Returns: 工具栏前导视图
    @MainActor func addToolBarLeadingView() -> AnyView? {
        return AnyView(AppInfoIconButton())
    }
}


