import AgentToolKit
import LumiCoreKit
import PluginAgentMCPTools

actor AgentMCPToolsPlugin: SuperPlugin {
    nonisolated static let logger = PluginAgentMCPTools.AgentMCPToolsPlugin.logger
    nonisolated static let emoji = PluginAgentMCPTools.AgentMCPToolsPlugin.emoji
    nonisolated static let verbose = PluginAgentMCPTools.AgentMCPToolsPlugin.verbose
    static let id = PluginAgentMCPTools.AgentMCPToolsPlugin.id
    static let displayName = PluginAgentMCPTools.AgentMCPToolsPlugin.displayName
    static let description = PluginAgentMCPTools.AgentMCPToolsPlugin.description
    static let iconName = PluginAgentMCPTools.AgentMCPToolsPlugin.iconName
    static var category: PluginCategory { PluginCategory(package: PluginAgentMCPTools.AgentMCPToolsPlugin.category) }
    static var order: Int { PluginAgentMCPTools.AgentMCPToolsPlugin.order }
    static let shared = AgentMCPToolsPlugin()

    private let packaged = PluginAgentMCPTools.AgentMCPToolsPlugin.shared

    init() {
        PluginAgentMCPTools.AgentMCPPluginLocalStore.dbFolderURLProvider = {
            AppConfig.getDBFolderURL()
        }
    }

    nonisolated func onRegister() {
        PluginAgentMCPTools.AgentMCPToolsPlugin.shared.onRegister()
    }

    nonisolated func onEnable() {
        PluginAgentMCPTools.AgentMCPToolsPlugin.shared.onEnable()
    }

    nonisolated func onDisable() {
        PluginAgentMCPTools.AgentMCPToolsPlugin.shared.onDisable()
    }

    @MainActor
    func agentTools(context: ToolContext) -> [SuperAgentTool] {
        packaged.agentTools(context: context.packageContext)
    }
}
