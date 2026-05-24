import Foundation
import AgentToolKit

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
            return "停用 caffeinate 并恢复正常的系统睡眠行为。会释放所有 IOKit 电源断言。"
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
    func execute(arguments: [String: ToolArgument], context: ToolExecutionContext) async throws -> String {
        let manager = CaffeinateManager.shared

        guard manager.isActive else {
            return """
            ## Caffeinate Status
            
            Caffeinate is **not active**. No action needed.
            System is already following normal sleep policy.
            """
        }

        if Self.verbose {
            if CaffeinatePlugin.verbose {
                            CaffeinatePlugin.logger.info("\(Self.t)Deactivating caffeinate")
            }
        }

        manager.deactivate()

        return """
        ## Caffeinate Deactivated ✅
        
        System sleep policy has been **restored to normal**.
        The system will now follow its default power management settings.
        """
    }
}
