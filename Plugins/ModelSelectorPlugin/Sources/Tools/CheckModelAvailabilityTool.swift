import LLMProviderManagerPlugin
import Foundation
import LumiKernel
import os
import SuperLogKit

public struct CheckModelAvailabilityTool: LumiAgentTool, SuperLog, @unchecked Sendable {
    public nonisolated static let emoji = "🔍"
    public nonisolated static let verbose: Bool = true
    private nonisolated static let logger = os.Logger(subsystem: "com.coffic.lumi", category: "plugin.model-selector.tools")

    public static let info = LumiAgentToolInfo(
        id: "check_model_availability",
        displayName: LumiPluginLocalization.string("Check Model Availability"),
        description: LumiPluginLocalization.string(
            "Check if a specific LLM model from a given provider is available. Sends a lightweight request to verify connectivity. Returns available ✅ or unavailable ❌ with reason."
        )
    )

    private let chatService: any LumiChatServicing

    public init(chatService: any LumiChatServicing) {
        self.chatService = chatService
    }

    public var inputSchema: LumiJSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([
                "providerId": .object([
                    "type": .string("string"),
                    "description": .string("Provider ID (e.g., openai, anthropic, deepseek, zhipu, aliyun)"),
                ]),
                "modelId": .object([
                    "type": .string("string"),
                    "description": .string("Model ID (e.g., gpt-4o, claude-sonnet-4-20250514, deepseek-chat)"),
                ]),
            ]),
            "required": .array([.string("providerId"), .string("modelId")]),
        ])
    }

    public func displayDescription(arguments: [String: LumiJSONValue]) -> String {
        "检测模型可用性"
    }

    public func riskLevel(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext?) -> LumiCommandRiskLevel {
        .low
    }

    @MainActor
    public func execute(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext) async throws -> String {
        guard let providerId = arguments["providerId"]?.stringValue, !providerId.isEmpty else {
            return "## ❌ 参数错误\n\n缺少必填参数 `providerId`，请提供供应商 ID。"
        }

        guard let modelId = arguments["modelId"]?.stringValue, !modelId.isEmpty else {
            return "## ❌ 参数错误\n\n缺少必填参数 `modelId`，请提供模型 ID。"
        }

        if Self.verbose {
            Self.logger.info("[\(Self.emoji)] 开始检测：\(providerId) / \(modelId)")
        }

        guard let provider = chatService.provider(forID: providerId) else {
            return """
            ## ❌ 供应商未注册

            - **供应商 ID**：`\(providerId)`
            - **状态**：当前应用未注册该供应商插件

            请检查供应商 ID 是否正确，或在设置中确认该插件已启用。
            """
        }

        let result = await provider.checkAvailability(model: modelId)

        if Self.verbose {
            switch result {
            case .available:
                Self.logger.info("[\(Self.emoji)] 检测完成：\(providerId) / \(modelId) 可用")
            case .unavailable(let failure):
                Self.logger.warning("[\(Self.emoji)] 检测完成：\(providerId) / \(modelId) 不可用 - \(failure.logSummary)")
            }
        }

        switch result {
        case .available:
            return """
            ## ✅ 模型可用

            - **供应商**：`\(providerId)`
            - **模型**：`\(modelId)`
            - **状态**：连通性检测通过，可以正常使用
            """
        case .unavailable(let failure):
            return """
            ## ❌ 模型不可用

            - **供应商**：`\(providerId)`
            - **模型**：`\(modelId)`
            - **状态**：连通性检测未通过
            - **原因**：\(failure.logSummary.isEmpty ? "未知" : failure.logSummary)

            ### 排查建议

            1. 检查 API Key 是否已配置且有效
            2. 确认网络连接正常
            3. 验证模型 ID 拼写是否正确
            4. 检查供应商账户余额或配额
            """
        }
    }
}
