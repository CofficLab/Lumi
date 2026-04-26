import MagicKit
import SwiftUI

/// 自动批准开关插件
///
/// 在工具栏右侧提供自动批准开关（AutoApproveToggle），
/// 持久化覆盖层（AutoApprovePersistenceOverlay）通过 addRootView 提供。
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

    // MARK: - Toolbar Views

    /// 工具栏右侧：自动批准开关
    @MainActor
    func addToolBarTrailingView() -> AnyView? {
        AnyView(AutoApproveToggle())
    }
}
