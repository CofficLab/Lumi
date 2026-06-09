import AgentToolKit
import LumiCoreKit
import os
import SwiftUI

public enum DatabaseManagerPlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .disabled
    public static let category: LumiPluginCategory = .general
    public static let iconName = "server.rack"
    public static let verbose: Bool = false

    public static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.database-manager")

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.database-manager",
        displayName: String(localized: "Database", bundle: .module),
        description: String(localized: "Manage SQLite, MySQL, PostgreSQL, and Redis", bundle: .module),
        order: 50
    )

    @MainActor
    public static func viewContainers(context: LumiPluginContext) -> [LumiViewContainerItem] {
        [
            LumiViewContainerItem(
                id: info.id,
                title: info.displayName,
                systemImage: iconName
            ) {
                DatabaseMainView()
            }
        ]
    }

    @MainActor
    public static func agentTools(context: LumiPluginContext) -> [any LumiAgentTool] {
        [
            DatabaseListConnectionsTool().asLumiAgentTool(),
            DatabaseDescribeSchemaTool().asLumiAgentTool(),
            DatabaseReadonlyQueryTool().asLumiAgentTool(),
            DatabaseSampleTableTool().asLumiAgentTool(),
        ]
    }
}
