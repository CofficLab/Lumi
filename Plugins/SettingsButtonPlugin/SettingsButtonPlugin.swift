import Foundation
import MagicKit
import OSLog
import SwiftUI

/// 设置按钮插件：在状态栏右侧显示设置按钮
class SettingsButtonPlugin: NSObject, SuperPlugin, SuperLog {
    // MARK: - Plugin Properties

    /// 日志标识符
    nonisolated static let emoji = "⚙️"

    /// 是否启用该插件
    static let enable = true

    /// 是否启用详细日志输出
    nonisolated static let verbose = true

    /// 插件唯一标识符
    static var id: String = "SettingsButtonPlugin"

    /// 插件显示名称
    static var displayName: String = "设置按钮"

    /// 插件功能描述
    static var description: String = "在状态栏右侧显示设置按钮，点击打开设置界面"

    /// 插件图标名称
    static var iconName: String = "gearshape"

    /// 是否可配置
    static var isConfigurable: Bool = false
    
    /// 注册顺序
    static var order: Int { 100 }

    // MARK: - Instance

    /// 插件实例标签（用于识别唯一实例）
    var instanceLabel: String {
        Self.id
    }

    /// 插件单例实例
    static let shared = SettingsButtonPlugin()

    /// 初始化方法
    override init() {}

    /// 检查插件是否被用户启用
    private var isUserEnabled: Bool {
        PluginSettingsStore.shared.isPluginEnabled(Self.id)
    }

    // MARK: - UI Contributions

    /// 添加状态栏右侧视图
    /// - Returns: 状态栏右侧视图
    func addStatusBarTrailingView() -> AnyView? {
        guard isUserEnabled else { return nil }
        return AnyView(SettingsButtonView())
    }
}


