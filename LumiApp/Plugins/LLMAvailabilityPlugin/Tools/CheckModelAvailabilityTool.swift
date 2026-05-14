import Foundation
import MagicKit
import os

/// 检测指定供应商+模型可用性的工具
///
/// 向目标模型发送一条轻量 ping 消息，验证其连通性并返回结果。
struct CheckModelAvailabilityTool: SuperAgentTool, SuperLog {
    nonisolated static let emoji = "🔍"
    nonisolated static let verbose: Bool = true

    let name = "check_model_availability"
    let description = "检测指定供应商的某个大模型是否可用。通过向目标模型发送轻量请求验证连通性。返回可用 ✅ 或不可用 ❌ 及原因。"

    var inputSchema: [String: Any] {
        [
            "type": "object",
            "properties": [
                "providerId": [
                    "type": "string",
                    "description": "供应商 ID（如 openai、anthropic、deepseek、zhipu、aliyun 等）",
                ],
                "modelId": [
                    "type": "string",
                    "description": "模型 ID（如 gpt-4o、claude-sonnet-4-20250514、deepseek-chat 等）",
                ],
            ],
            "required": ["providerId", "modelId"],
        ]
    }

    func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .low
    }

    @MainActor
    func execute(arguments: [String: ToolArgument]) async throws -> String {
        guard let providerId = arguments["providerId"]?.value as? String, !providerId.isEmpty else {
            if Self.verbose {
                LLMAvailabilityPlugin.logger.warning("\(self.t)⚠️ 缺少必填参数 providerId")
            }
            return "## ❌ 参数错误\n\n缺少必填参数 `providerId`，请提供供应商 ID。"
        }

        guard let modelId = arguments["modelId"]?.value as? String, !modelId.isEmpty else {
            if Self.verbose {
                LLMAvailabilityPlugin.logger.warning("\(self.t)⚠️ 缺少必填参数 modelId")
            }
            return "## ❌ 参数错误\n\n缺少必填参数 `modelId`，请提供模型 ID。"
        }

        if Self.verbose {
            LLMAvailabilityPlugin.logger.info("\(self.t)🔍 开始检测：\(providerId) / \(modelId)")
        }

        let llmService = RootContainer.shared.llmService
        let checker = LLMAvailabilityChecker(llmService: llmService)
        let result = await checker.checkModel(providerId: providerId, modelId: modelId)

        if result.isAvailable {
            if Self.verbose {
                LLMAvailabilityPlugin.logger.info("\(self.t)✅ 检测完成：\(providerId) / \(modelId) 可用")
            }
            return """
                ## ✅ 模型可用

                - **供应商**：`\(result.providerId)`
                - **模型**：`\(result.modelId)`
                - **状态**：连通性检测通过，可以正常使用
                """
        } else {
            if Self.verbose {
                LLMAvailabilityPlugin.logger.warning("\(self.t)❌ 检测完成：\(providerId) / \(modelId) 不可用 - \(result.reason ?? "未知原因")")
            }
            return """
                ## ❌ 模型不可用

                - **供应商**：`\(result.providerId)`
                - **模型**：`\(result.modelId)`
                - **状态**：连通性检测未通过
                - **原因**：\(result.reason ?? "未知")

                ### 排查建议

                1. 检查 API Key 是否已配置且有效
                2. 确认网络连接正常
                3. 验证模型 ID 拼写是否正确
                4. 检查供应商账户余额或配额
                """
        }
    }
}
