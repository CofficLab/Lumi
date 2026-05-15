import Foundation
import MagicKit
import os
import SwiftUI

actor CodeReviewPlugin: SuperPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.code-review")
    nonisolated static let emoji = "🔎"
    nonisolated static let verbose: Bool = true

    static let id: String = "CodeReview"
    static let displayName: String = "Code Review"
    static let description: String = "Reviews current Git changes and reports actionable issues."
    static let iconName: String = "checklist"
    static let isConfigurable: Bool = true
    static let enable: Bool = true
    static var order: Int { 17 }

    static let shared = CodeReviewPlugin()

    @MainActor
    func agentToolFactories() -> [AnySuperAgentToolFactory] {
        [AnySuperAgentToolFactory(CodeReviewToolsFactory())]
    }
}

@MainActor
private struct CodeReviewToolsFactory: SuperAgentToolFactory {
    let id: String = "code.review.tools.factory"
    let order: Int = 0

    func makeTools(env: SuperAgentToolEnvironment) -> [SuperAgentTool] {
        [RunReviewTool(llmService: env.llmService)]
    }
}
