import AgentToolKit
import Foundation
import LumiCoreKit
import PluginAgentGitHubTools
import SwiftUI

actor AgentGitHubToolsPlugin: SuperPlugin {
    nonisolated static let emoji = PluginAgentGitHubTools.GitHubToolsPlugin.emoji
    nonisolated static let verbose = PluginAgentGitHubTools.GitHubToolsPlugin.verbose
    static let id = PluginAgentGitHubTools.GitHubToolsPlugin.id
    static let displayName = PluginAgentGitHubTools.GitHubToolsPlugin.displayName
    static let description = PluginAgentGitHubTools.GitHubToolsPlugin.description
    static let iconName = PluginAgentGitHubTools.GitHubToolsPlugin.iconName
    static var category: PluginCategory { PluginCategory(package: PluginAgentGitHubTools.GitHubToolsPlugin.category) }
    static var order: Int { PluginAgentGitHubTools.GitHubToolsPlugin.order }
    static let shared = AgentGitHubToolsPlugin()

    init() {
        PluginAgentGitHubTools.GitHubPluginLocalStore.dbFolderURLProvider = {
            AppConfig.getDBFolderURL()
        }
    }

    nonisolated func onRegister() {}
    nonisolated func onEnable() {}
    nonisolated func onDisable() {}

    @MainActor
    func addPosterViews() -> [AnyView] {
        PluginAgentGitHubTools.GitHubToolsPlugin.shared.addPosterViews()
    }

    @MainActor
    func agentTools(context: ToolContext) -> [SuperAgentTool] {
        PluginAgentGitHubTools.GitHubToolsPlugin.shared.agentTools(context: context.packageContext)
    }

    @MainActor
    func addSettingsView() -> AnyView? {
        PluginAgentGitHubTools.GitHubToolsPlugin.shared.addSettingsView()
    }
}
