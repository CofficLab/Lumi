import Foundation
import ToolKit
import os

/// 列出可用 LLM 模型工具
struct ListAvailableModelsTool: SuperAgentTool, SuperLog {
    nonisolated static let emoji = "🤖"
    nonisolated static let verbose: Bool = false

    let name = "list_available_models"
    func description(for language: LanguagePreference) -> String {
        switch language {
        case .chinese:
            return "列出当前可用的 LLM 供应商和模型。返回实际通过连通性检测的供应商+模型对。如果未传入参数，返回全部可用列表；可指定供应商过滤。"
        case .english:
            return "List all available LLM providers and models. Returns provider+model pairs that passed connectivity checks. Returns all available results if no parameter is provided; can filter by provider."
        }
    }

    func inputSchema(for language: LanguagePreference) -> [String: Any] {
        let providerIdDesc: String
        switch language {
        case .chinese:
            providerIdDesc = "可选，按供应商 ID 过滤（如 OpenAI、Anthropic）"
        case .english:
            providerIdDesc = "Optional, filter by provider ID (e.g., OpenAI, Anthropic)"
        }
        return [
            "type": "object",
            "properties": [
                "providerId": [
                    "type": "string",
                    "description": providerIdDesc,
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
        let allProviders = store.providers

        if Self.verbose {
            if let filter = providerFilter {
                if LLMAvailabilityPlugin.verbose {
                                    LLMAvailabilityPlugin.logger.info("\(self.t)📋 查询可用模型，过滤供应商: \(filter)")
                }
            } else {
                if LLMAvailabilityPlugin.verbose {
                                    LLMAvailabilityPlugin.logger.info("\(self.t)📋 查询所有可用模型")
                }
            }
        }

        // ── 情况 1：没有任何注册的供应商 ──
        if allProviders.isEmpty {
            if Self.verbose {
                if LLMAvailabilityPlugin.verbose {
                                    LLMAvailabilityPlugin.logger.warning("\(self.t)⚠️ 未注册任何 LLM 供应商")
                }
            }
            return """
                ## ⚠️ 未注册任何 LLM 供应商

                当前应用未注册任何 LLM 供应商插件，无法使用 AI 功能。

                可能的原因：
                1. LLM 供应商插件未启用（请在设置中检查插件状态）
                2. 应用尚未完成初始化

                请检查插件设置，确保至少启用了一个 LLM 供应商插件。
                """
        }

        // 按供应商过滤
        let providers = providerFilter != nil
            ? allProviders.filter { $0.providerId == providerFilter }
            : allProviders

        // ── 情况 2：过滤后未找到指定供应商 ──
        if providers.isEmpty, let filter = providerFilter {
            let registeredIds = allProviders.map(\.providerId)
            if Self.verbose {
                if LLMAvailabilityPlugin.verbose {
                                    LLMAvailabilityPlugin.logger.warning("\(self.t)⚠️ 未找到供应商: \(filter)，已注册: \(registeredIds)")
                }
            }
            return """
                ## ❌ 未找到供应商：\(filter)

                当前已注册的供应商：
                \(registeredIds.map { "- `\($0)`" }.joined(separator: "\n"))

                请检查供应商 ID 是否正确。
                """
        }

        // 统计可用模型对
        var availableMarkdown = ""
        var totalAvailablePairs = 0

        for provider in providers {
            let available = provider.availableModels
            guard !available.isEmpty else { continue }

            availableMarkdown += "### \(provider.displayName) (`\(provider.providerId)`)\n\n"
            for modelId in available {
                availableMarkdown += "- `\(modelId)`\n"
            }
            availableMarkdown += "\n"
            totalAvailablePairs += available.count
        }

        // ── 情况 3：有注册供应商但无可用模型（API Key 未配置或检测未通过）──
        if totalAvailablePairs == 0 {
            let providerSummaries = providers.map { provider -> String in
                let totalModels = provider.models.count
                let statusSummary = summarizeStatuses(provider.models)
                return "- **\(provider.displayName)** (`\(provider.providerId)`)：\(totalModels) 个模型，\(statusSummary)"
            }

            if Self.verbose {
                if LLMAvailabilityPlugin.verbose {
                                    LLMAvailabilityPlugin.logger.warning("\(self.t)⚠️ 有 \(allProviders.count) 个注册供应商，但无可用模型")
                }
            }

            return """
                ## ⚠️ 注册了 \(allProviders.count) 个 LLM 供应商，但没有可用模型

                已注册供应商：
                \(providerSummaries.joined(separator: "\n"))

                可能的原因：
                1. API Key 未配置（请在设置中为对应供应商填写 API Key）
                2. API Key 已过期或无效
                3. 网络连接异常，可用性检测未通过
                4. 可用性检测尚未完成（请稍后再试）

                请在设置中检查各供应商的 API Key 配置。
                """
        }

        // ── 情况 4：正常返回可用模型 ──
        var markdown = "## 可用 LLM 供应商和模型\n\n"
        markdown += availableMarkdown

        if Self.verbose {
            if LLMAvailabilityPlugin.verbose {
                            LLMAvailabilityPlugin.logger.info("\(self.t)✅ 返回 \(totalAvailablePairs) 个可用模型对")
            }
        }

        return markdown
    }

    // MARK: - Private

    /// 汇总模型状态，生成可读描述
    private func summarizeStatuses(_ models: [LLMModelAvailability]) -> String {
        var unknown = 0, checking = 0, available = 0, unavailable = 0
        var unavailableReasons: [String] = []

        for model in models {
            switch model.status {
            case .unknown:
                unknown += 1
            case .checking:
                checking += 1
            case .available:
                available += 1
            case .unavailable(let reason):
                unavailable += 1
                if unavailableReasons.count < 3 {
                    unavailableReasons.append(reason)
                }
            }
        }

        var parts: [String] = []
        if available > 0 { parts.append("\(available) 可用") }
        if checking > 0 { parts.append("\(checking) 检测中") }
        if unavailable > 0 { parts.append("\(unavailable) 不可用") }
        if unknown > 0 { parts.append("\(unknown) 未检测") }

        var summary = parts.joined(separator: "、")
        if !unavailableReasons.isEmpty {
            summary += "（原因：\(unavailableReasons.joined(separator: "；"))）"
        }
        return summary
    }
}
