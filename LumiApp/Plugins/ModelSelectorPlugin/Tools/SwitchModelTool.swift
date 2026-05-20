import Foundation
import os

/// 切换当前 LLM 供应商和模型的工具
///
/// 允许 LLM 在对话过程中主动切换到更合适的供应商和模型。
/// 通过 `ToolContext.llmVM` 获取 `AppLLMVM` 引用，
/// 修改其 `selectedProviderId`、`currentModel` 和 `isAutoMode` 属性。
struct SwitchModelTool: SuperAgentTool, SuperLog {
    nonisolated static let emoji = "🔄"
    nonisolated static let verbose: Bool = false

    let name = "switch_model"

    // MARK: - SuperAgentTool

    func description(for language: LanguagePreference) -> String {
        switch language {
        case .chinese:
            return "切换当前使用的 LLM 供应商和模型。需要提供供应商 ID 和模型 ID。建议先调用 list_available_models 确认目标可用。"
        case .english:
            return "Switch the current LLM provider and model. Requires provider ID and model ID. It is recommended to call list_available_models first to confirm availability."
        }
    }

    func inputSchema(for language: LanguagePreference) -> [String: Any] {
        let providerIdDesc: String
        let modelIdDesc: String
        switch language {
        case .chinese:
            providerIdDesc = "供应商 ID（如 openai、anthropic、deepseek、zhipu、aliyun 等）"
            modelIdDesc = "模型 ID（如 gpt-4o、claude-sonnet-4-20250514、deepseek-chat 等）"
        case .english:
            providerIdDesc = "Provider ID (e.g., openai, anthropic, deepseek, zhipu, aliyun)"
            modelIdDesc = "Model ID (e.g., gpt-4o, claude-sonnet-4-20250514, deepseek-chat)"
        }
        return [
            "type": "object",
            "properties": [
                "providerId": [
                    "type": "string",
                    "description": providerIdDesc,
                ],
                "modelId": [
                    "type": "string",
                    "description": modelIdDesc,
                ],
            ],
            "required": ["providerId", "modelId"],
        ]
    }

    func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .low
    }

    // MARK: - Dependencies

    private let llmVM: AppLLMVM

    init(llmVM: AppLLMVM) {
        self.llmVM = llmVM
    }

    // MARK: - Execute

    @MainActor
    func execute(arguments: [String: ToolArgument]) async throws -> String {
        guard let providerId = arguments["providerId"]?.value as? String, !providerId.isEmpty else {
            return "## ❌ 参数错误\n\n缺少必填参数 `providerId`，请提供供应商 ID。"
        }

        guard let modelId = arguments["modelId"]?.value as? String, !modelId.isEmpty else {
            return "## ❌ 参数错误\n\n缺少必填参数 `modelId`，请提供模型 ID。"
        }

        // 验证供应商是否存在
        let allProviders = llmVM.allProviders
        guard let targetProvider = allProviders.first(where: { $0.id == providerId }) else {
            let registeredIds = allProviders.map(\.id)
            return """
                ## ❌ 供应商不存在：`\(providerId)`

                当前已注册的供应商：
                \(registeredIds.map { "- `\($0)`" }.joined(separator: "\n"))

                请检查供应商 ID 是否正确。可调用 `list_available_models` 查看可用列表。
                """
        }

        // 验证模型是否属于该供应商
        guard targetProvider.availableModels.contains(modelId) else {
            return """
                ## ❌ 模型不属于该供应商

                供应商 **\(targetProvider.displayName)** (`\(providerId)`) 不包含模型 `\(modelId)`。

                该供应商的可用模型：
                \(targetProvider.availableModels.map { "- `\($0)`" }.joined(separator: "\n"))
                """
        }

        // 记录切换前的状态
        let previousProvider = llmVM.selectedProviderId
        let previousModel = llmVM.currentModel

        // 执行切换
        llmVM.isAutoMode = false
        llmVM.selectedProviderId = providerId
        llmVM.currentModel = modelId

        if Self.verbose {
            ModelSelectorPlugin.logger.info("\(self.t)切换模型：\(previousProvider)/\(previousModel) → \(providerId)/\(modelId)")
        }

        return """
            ## ✅ 模型切换成功

            - **供应商**：\(targetProvider.displayName) (`\(providerId)`)
            - **模型**：`\(modelId)`
            - **Auto 模式**：已关闭

            后续对话将使用新模型。如需恢复自动选择，请在模型选择器中重新开启 Auto 模式。
            """
    }
}
