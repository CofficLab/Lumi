import PluginCodeReview
import SwiftUI
import AgentToolKit

actor CodeReviewPlugin: SuperPlugin {
    nonisolated static let logger = PluginCodeReview.CodeReviewPlugin.logger
    nonisolated static let emoji = PluginCodeReview.CodeReviewPlugin.emoji
    nonisolated static let verbose = PluginCodeReview.CodeReviewPlugin.verbose
    static let id = PluginCodeReview.CodeReviewPlugin.id
    static let displayName = PluginCodeReview.CodeReviewPlugin.displayName
    static let description = PluginCodeReview.CodeReviewPlugin.description
    static let iconName = PluginCodeReview.CodeReviewPlugin.iconName
    static var category: PluginCategory { PluginCategory(package: PluginCodeReview.CodeReviewPlugin.category) }
    static var order: Int { PluginCodeReview.CodeReviewPlugin.order }
    static let shared = CodeReviewPlugin()

    @MainActor
    func agentTools(context: ToolContext) -> [SuperAgentTool] {
        CodeReviewRuntime.currentConfigProvider = {
            RootContainer.shared.agentSessionConfig.getCurrentConfig()
        }
        CodeReviewRuntime.sendMessage = { messages, config in
            guard let service = context.llmService else {
                throw CodeReviewRuntimeBridgeError.llmServiceUnavailable
            }
            return try await service.sendMessage(messages: messages, config: config)
        }
        return [PluginCodeReview.RunReviewTool()]
    }
}

private enum CodeReviewRuntimeBridgeError: LocalizedError {
    case llmServiceUnavailable

    var errorDescription: String? {
        "LLM service is unavailable."
    }
}
