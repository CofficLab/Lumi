import Foundation
import MagicKit
import os

/// 列出可用 LLM 模型工具
struct ListAvailableModelsTool: SuperAgentTool, SuperLog {
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

        if Self.verbose {
            if let filter = providerFilter {
                LLMAvailabilityPlugin.logger.info("\(self.t)📋 查询可用模型，过滤供应商: \(filter)")
            } else {
                LLMAvailabilityPlugin.logger.info("\(self.t)📋 查询所有可用模型")
            }
        }

        let providers = providerFilter != nil
            ? store.providers.filter { $0.providerId == providerFilter }
            : store.providers

        guard !providers.isEmpty else {
            if let filter = providerFilter {
                if Self.verbose {
                    LLMAvailabilityPlugin.logger.warning("\(self.t)⚠️ 未找到供应商: \(filter)")
                }
                return "❌ 未找到供应商：\(filter)"
            }
            if Self.verbose {
                LLMAvailabilityPlugin.logger.warning("\(self.t)⚠️ 暂无可用供应商")
            }
            return "⚠️ 暂无可用供应商，请检查 API Key 配置"
        }

        var markdown = "## 可用 LLM 供应商和模型\n\n"

        for provider in providers {
            let available = provider.availableModels
            guard !available.isEmpty else {
                if Self.verbose {
                    LLMAvailabilityPlugin.logger.info("\(self.t)ℹ️ \(provider.displayName) 暂无可用模型")
                }
                continue
            }

            markdown += "### \(provider.displayName) (`\(provider.providerId)`)\n\n"
            for modelId in available {
                markdown += "- `\(modelId)`\n"
            }
            markdown += "\n"
        }

        let pairCount = store.availablePairs.count
        if Self.verbose {
            LLMAvailabilityPlugin.logger.info("\(self.t)✅ 返回 \(pairCount) 个可用模型对")
        }

        return markdown
    }
}
