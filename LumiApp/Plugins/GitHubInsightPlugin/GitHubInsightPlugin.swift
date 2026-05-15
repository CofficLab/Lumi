import Foundation
import MagicKit
import os
import SwiftUI

actor GitHubInsightPlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.github-insight")
    nonisolated static let emoji = "🌐"
    nonisolated static let verbose: Bool = true

    static let id = "GitHubInsight"
    static let displayName = "GitHub Insight"
    static let description = "Builds a local cache of GitHub ecosystem references for the current project."
    static let iconName = "network"
    static let isConfigurable = true
    static let enable = true
    static var order: Int { 16 }
    static let shared = GitHubInsightPlugin()

    private init() {}

    @MainActor
    func addStatusBarTrailingView(activeIcon: String?) -> AnyView? {
        AnyView(GitHubKBStatusBarView())
    }

    @MainActor
    func sendMiddlewares() -> [AnySuperSendMiddleware] {
        [AnySuperSendMiddleware(GitHubKBMiddleware())]
    }

    @MainActor
    func agentTools() -> [SuperAgentTool] {
        [QueryEcoKBTool()]
    }
}
