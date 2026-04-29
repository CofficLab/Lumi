import Foundation
import MagicKit

/// 列出可用 LLM 模型工具
struct ListAvailableModelsTool: AgentTool, SuperLog {
    nonisolated static let emoji = "🤖"
    nonisolated static let verbose: Bool = true

    let name = "list_available_models"
    let description = "列出当前可用的 LLM 供应商和模型。返回实际通过连通性检测的供应商+模型对。如果未传入参数，返回全部可用列表；可指定供应商过滤。"

    var inputSchema: [String: Any] {
        [
            "type": "object",
            "properties": [
                "providerId": [
                    "type": "string",
                    "description": "可选，按供应商 ID 过滤（如 OpenAI、Anthropic）",
                ],
            ],
        ]
    }

    func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel {
        .low
    }

    @MainActor
    func execute(arguments: [String: ToolArgument]) async throws -> String {
        let providerFilter = arguments["providerId"]?.value as? String
        let store = LLMAvailabilityStore.shared

        let providers = providerFilter != nil
            ? store.providers.filter { $0.providerId == providerFilter }
            : store.providers

        guard !providers.isEmpty else {
            if let filter = providerFilter {
                return "❌ 未找到供应商：\(filter)"
            }
            return "⚠️ 暂无可用供应商，请检查 API Key 配置"
        }

        var markdown = "## 可用 LLM 供应商和模型\n\n"

        for provider in providers {
            let available = provider.availableModels
            guard !available.isEmpty else { continue }

            markdown += "### \(provider.displayName) (`\(provider.providerId)`)\n\n"
            for modelId in available {
                markdown += "- `\(modelId)`\n"
            }
            markdown += "\n"
        }

        if Self.verbose {
            let pairCount = store.availablePairs.count
            LLMAvailabilityPlugin.logger.info("\(Self.t)📋 返回 \(pairCount) 个可用模型对")
        }

        return markdown
    }
}
