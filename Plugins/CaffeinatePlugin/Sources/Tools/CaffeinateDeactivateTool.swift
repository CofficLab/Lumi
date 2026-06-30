import Foundation
import LumiCoreKit
import SuperLogKit

/// 关闭防休眠工具
///
/// 释放 IOKit 电源断言，恢复系统正常的休眠策略。
struct CaffeinateDeactivateTool: LumiAgentTool, SuperLog {
    nonisolated static let emoji = "😴"
    nonisolated static let verbose: Bool = false

    static let info = LumiAgentToolInfo(
        id: "caffeinate_deactivate",
        displayName: "Deactivate Caffeinate",
        description: "Deactivate caffeinate and restore normal system sleep behavior. Releases all IOKit power assertions."
    )

    var inputSchema: LumiJSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([:]),
        ])
    }

    func displayDescription(arguments: [String: LumiJSONValue]) -> String { "恢复系统睡眠" }
    func riskLevel(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext?) -> LumiCommandRiskLevel {
        .low
    }

    @MainActor
    func execute(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext) async throws -> String {
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
