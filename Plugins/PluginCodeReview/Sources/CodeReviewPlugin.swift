import Foundation
import LumiCoreKit
import SuperLogKit
import AgentToolKit
import os
import SwiftUI

public actor CodeReviewPlugin: SuperPlugin, SuperLog {
    public nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.code-review")
    public nonisolated static let emoji = "🔎"
    public nonisolated static let verbose: Bool = true

    public static let id: String = "CodeReview"
    public static let displayName: String = "Code Review"
    public static let description: String = "Reviews current Git changes and reports actionable issues."
    public static let iconName: String = "checklist"
    public static var category: PluginCategory { .developerTool }
    public static var order: Int { 17 }

    public static let shared = CodeReviewPlugin()

    @MainActor
    public func agentTools(context: ToolContext) -> [SuperAgentTool] {
        [RunReviewTool()]
    }
}
