import Foundation
import LumiCoreKit
import SuperLogKit
import os

/// 列出可用 LLM 模型工具
public struct ListAvailableModelsTool: LumiAgentTool, SuperLog {
    public nonisolated static let emoji = "🤖"
    public nonisolated static let verbose: Bool = false

    public static let info = LumiAgentToolInfo(
        id: "list_available_models",
        displayName: LumiPluginLocalization.string("List Available Models", bundle: .module),
        description: LumiPluginLocalization.string(
            "List all available LLM providers and models. Returns provider+model pairs that passed connectivity checks. Returns all available results if no parameter is provided; can filter by provider.",
            bundle: .module
        )
    )

    public init() {}

    public var inputSchema: LumiJSONValue {
        .object([
            "type": .string("object"),
            "properties": .object([
                "providerId": .object([
                    "type": .string("string"),
                    "description": .string("Optional, filter by provider ID (e.g., OpenAI, Anthropic)")
                ])
            ]),
            "required": .array([])
        ])
    }

    public func displayDescription(arguments: [String: LumiJSONValue]) -> String { "列出可用模型" }
    public func riskLevel(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext?) -> LumiCommandRiskLevel {
        .low
    }

    @MainActor
    public func execute(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext) async throws -> String {
        let providerFilter = arguments["providerId"]?.stringValue
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
            case .unavailable(let failure):
                unavailable += 1
                if unavailableReasons.count < 3 {
                    unavailableReasons.append(failure.logSummary)
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
