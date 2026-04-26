import MagicKit
import SwiftUI

/// 自动批准开关插件
///
/// 注意：自动批准开关（AutoApproveToggle）和持久化覆盖层
/// （AutoApprovePersistenceOverlay）已整合到 EditorPlugin 的聊天栏中。
/// 本插件保留仅用于维护自动批准相关的持久化存储逻辑。
/// 实际 UI 渲染和根视图包裹由 EditorPlugin 负责。
actor AgentAutoApprovePlugin: SuperPlugin {
    nonisolated static let emoji = "✅"
    nonisolated static let verbose: Bool = false
    static let id = "AgentAutoApproveHeader"
    static let displayName = String(localized: "Auto-Approve Toggle", table: "AgentAutoApproveHeader")
    static let description = String(localized: "Auto-approve toggle in chat header", table: "AgentAutoApproveHeader")
    static let iconName = "checkmark.circle"
    static var order: Int { 82 }
    
    /// 核心安全功能，禁止用户配置
    static var isConfigurable: Bool { false }
    
    static let enable: Bool = true

    static let shared = AgentAutoApprovePlugin()

    nonisolated func onRegister() {}
    nonisolated func onEnable() {}
    nonisolated func onDisable() {}
}
