import Foundation
import MagicKit

/// 关闭防休眠工具
///
/// 释放 IOKit 电源断言，恢复系统正常的休眠策略。
struct CaffeinateDeactivateTool: SuperAgentTool, SuperLog {
    nonisolated static let emoji = "😴"
    nonisolated static let verbose: Bool = true

    let name = "caffeinate_deactivate"
    func description(for language: LanguagePreference) -> String {
        switch language {
        case .chinese:
            return "Deactivate caffeinate and restore normal system sleep behavior. Releases all IOKit power assertions."
        case .english:
            return "Deactivate caffeinate and restore normal system sleep behavior. Releases all IOKit power assertions."
        }
    }

    func inputSchema(for language: LanguagePreference) -> [String: Any] {
        [
            "type": "object",
            "properties": [:],
        ]
    }

    func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .low
    }

    @MainActor
    func execute(arguments: [String: ToolArgument]) async throws -> String {
        let manager = CaffeinateManager.shared

        guard manager.isActive else {
            return """
            ## Caffeinate Status
            
            Caffeinate is **not active**. No action needed.
            System is already following normal sleep policy.
            """
        }

        if Self.verbose {
            CaffeinatePlugin.logger.info("\(Self.t)Deactivating caffeinate")
        }

        manager.deactivate()

        return """
        ## Caffeinate Deactivated ✅
        
        System sleep policy has been **restored to normal**.
        The system will now follow its default power management settings.
        """
    }
}
