import Foundation
import os
import SwiftUI

actor CodeReviewPlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.code-review")
    nonisolated static let emoji = "🔎"
    nonisolated static let verbose: Bool = false

    static let id: String = "CodeReview"
    static let displayName: String = "Code Review"
    static let description: String = "Reviews current Git changes and reports actionable issues."
    static let iconName: String = "checklist"
    static let isConfigurable: Bool = true
    static let enable: Bool = true
    static var category: PluginCategory { .developerTool }
    static var order: Int { 17 }

    static let shared = CodeReviewPlugin()

    @MainActor
    func agentTools(context: ToolContext) -> [SuperAgentTool] {
        [RunReviewTool(llmService: context.llmService)]
    }
}
