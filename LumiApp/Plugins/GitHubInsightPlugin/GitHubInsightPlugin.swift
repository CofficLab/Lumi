import Foundation
import MagicKit
import os
import SwiftUI

/// Registers GitHub ecosystem insight capabilities for the Lumi plugin system.
///
/// The plugin contributes a status bar view, a send middleware that injects cached
/// ecosystem references into prompts, and an agent tool for querying the local
/// GitHub ecosystem knowledge base.
actor GitHubInsightPlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.github-insight")
    nonisolated static let emoji = "🌐"
    nonisolated static let verbose: Bool = false

    static let id = "GitHubInsight"
    static let displayName = String(localized: "GitHub Insight", table: "GitHubInsight")
    static let description = String(localized: "Builds a local cache of GitHub ecosystem references for the current project.", table: "GitHubInsight")
    static let iconName = "network"
    static let isConfigurable = true
    static let enable = true
    static var order: Int { 16 }
    static let shared = GitHubInsightPlugin()

    private init() {}

    /// Adds the GitHub ecosystem knowledge base status indicator to the trailing status bar.
    @MainActor
    func addStatusBarTrailingView(activeIcon: String?) -> AnyView? {
        AnyView(GitHubKBStatusBarView())
    }

    /// Registers send middlewares that can enrich outgoing messages with cached GitHub context.
    @MainActor
    func sendMiddlewares() -> [AnySuperSendMiddleware] {
        [AnySuperSendMiddleware(GitHubKBMiddleware())]
    }

    /// Registers agent tools exposed by this plugin.
    @MainActor
    func agentTools() -> [SuperAgentTool] {
        [QueryEcoKBTool()]
    }
}
