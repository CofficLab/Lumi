import Foundation
import LumiCoreKit
import SuperLogKit
import os

/// 检测指定供应商+模型可用性的工具
///
/// 向目标模型发送一条轻量 ping 消息，验证其连通性并返回结果。
public struct CheckModelAvailabilityTool: LumiAgentTool, SuperLog {
    public nonisolated static let emoji = "🔍"
    public nonisolated static let verbose: Bool = false

    public static let info = LumiAgentToolInfo(
        id: "check_model_availability",
        displayName: LumiPluginLocalization.string("Check Model Availability", bundle: .module),
        description: LumiPluginLocalization.string(
            "Check if a specific LLM model from a given provider is available. Sends a lightweight request to verify connectivity. Returns available ✅ or unavailable ❌ with reason.",
            bundle: .module
        )
    )

    private let llmService: (any LLMAvailabilityLLMServicing)?

    public init(llmService: (any LLMAvailabilityLLMServicing)? = nil) {
        self.llmService = llmService
    }

    public var inputSchema: LumiJSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([
                "providerId": .object([
                    "type": .string("string"),
                    "description": .string("Provider ID (e.g., openai, anthropic, deepseek, zhipu, aliyun)")
                ]),
                "modelId": .object([
                    "type": .string("string"),
                    "description": .string("Model ID (e.g., gpt-4o, claude-sonnet-4-20250514, deepseek-chat)")
                ])
            ]),
            "required": .array([.string("providerId"), .string("modelId")])
        ])
    }

    public func displayDescription(arguments: [String: LumiJSONValue]) -> String { "检测模型可用性" }
    public func riskLevel(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext?) -> LumiCommandRiskLevel {
        .low
    }

    @MainActor
    public func execute(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext) async throws -> String {
        guard let providerId = arguments["providerId"]?.stringValue, !providerId.isEmpty else {
            if Self.verbose {
                if LLMAvailabilityPlugin.verbose {
                                    LLMAvailabilityPlugin.logger.warning("\(self.t)⚠️ 缺少必填参数 providerId")
                }
            }
            return "## ❌ 参数错误\n\n缺少必填参数 `providerId`，请提供供应商 ID。"
        }

        guard let modelId = arguments["modelId"]?.stringValue, !modelId.isEmpty else {
            if Self.verbose {
                if LLMAvailabilityPlugin.verbose {
                                    LLMAvailabilityPlugin.logger.warning("\(self.t)⚠️ 缺少必填参数 modelId")
                }
            }
            return "## ❌ 参数错误\n\n缺少必填参数 `modelId`，请提供模型 ID。"
        }

        if Self.verbose {
            if LLMAvailabilityPlugin.verbose {
                            LLMAvailabilityPlugin.logger.info("\(self.t)🔍 开始检测：\(providerId) / \(modelId)")
            }
        }

        guard let llmService else {
            return "## ❌ 模型不可用\n\n当前运行时没有注入 LLM 服务，无法执行连通性检测。"
        }

        let checker = LLMAvailabilityChecker(llmService: llmService)
        let result = await checker.checkModel(providerId: providerId, modelId: modelId)

        if result.isAvailable {
            if Self.verbose {
                if LLMAvailabilityPlugin.verbose {
                                    LLMAvailabilityPlugin.logger.info("\(self.t)✅ 检测完成：\(providerId) / \(modelId) 可用")
                }
            }
            return """
                ## ✅ 模型可用

                - **供应商**：`\(result.providerId)`
                - **模型**：`\(result.modelId)`
                - **状态**：连通性检测通过，可以正常使用
                """
        } else {
            if Self.verbose {
                if LLMAvailabilityPlugin.verbose {
                                    LLMAvailabilityPlugin.logger.warning("\(self.t)❌ 检测完成：\(providerId) / \(modelId) 不可用 - \(result.reason ?? "未知原因")")
                }
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
