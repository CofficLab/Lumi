import LLMProviderManagerPlugin
import Foundation
import LumiKernel

struct SwitchModelTool: LumiAgentTool, @unchecked Sendable {
    static let info = LumiAgentToolInfo(
        id: "switch_model",
        displayName: LumiPluginLocalization.string("Switch Model"),
        description: """
        Switch the current LLM provider and model for the active conversation.

        Parameters:
        - providerId: Provider ID (e.g. openai, anthropic, deepseek)
        - modelId: Model ID (e.g. gpt-4o, claude-sonnet-4-20250514)

        Call list_available_models first when unsure which combinations are registered.
        """
    )

    private let chatService: any LumiChatServicing

    init(chatService: any LumiChatServicing) {
        self.chatService = chatService
    }

    var inputSchema: LumiJSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([
                "providerId": .object([
                    "type": .string("string"),
                    "description": .string("Provider ID (e.g. openai, anthropic, deepseek, zhipu, aliyun)")
                ]),
                "modelId": .object([
                    "type": .string("string"),
                    "description": .string("Model ID (e.g. gpt-4o, claude-sonnet-4-20250514, deepseek-chat)")
                ])
            ]),
            "required": .array([.string("providerId"), .string("modelId")])
        ])
    }

    func displayDescription(arguments: [String: LumiJSONValue]) -> String {
        LumiPluginLocalization.string("切换模型")
    }

    @MainActor
    func execute(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext) async throws -> String {
        guard let providerId = arguments["providerId"]?.stringValue?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !providerId.isEmpty
        else {
            return "## ❌ Missing `providerId`"
        }

        guard let modelId = arguments["modelId"]?.stringValue?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !modelId.isEmpty
        else {
            return "## ❌ Missing `modelId`"
        }

        let providers = chatService.providerInfos
        guard let targetProvider = providers.first(where: { $0.id == providerId }) else {
            let registeredIds = providers.map(\.id)
            return """
                ## ❌ Unknown provider `\(providerId)`

                Registered providers:
                \(registeredIds.map { "- `\($0)`" }.joined(separator: "\n"))
                """
        }

        guard targetProvider.availableModels.contains(modelId) else {
            return """
                ## ❌ Model not available for provider

                Provider **\(targetProvider.displayName)** (`\(providerId)`) does not include `\(modelId)`.

                Available models:
                \(targetProvider.availableModels.map { "- `\($0)`" }.joined(separator: "\n"))
                """
        }

        let conversationID = context.conversationID
        let previousProvider = chatService.providerID(for: conversationID) ?? chatService.selectedProviderID ?? "-"
        let previousModel = chatService.modelName(for: conversationID) ?? chatService.selectedModel ?? "-"

        chatService.setRoutingMode(.manual)
        chatService.selectProvider(id: providerId, model: modelId, for: conversationID)

        return """
            ## ✅ Model switched

            - **Provider**: \(targetProvider.displayName) (`\(providerId)`)
            - **Model**: `\(modelId)`
            - **Previous**: `\(previousProvider)` / `\(previousModel)`
            - **Auto routing**: disabled
            """
    }
}
