import LLMProviderManagerPlugin
import Foundation
import LumiKernel
import os
import SuperLogKit

public struct ListAvailableModelsTool: LumiAgentTool, SuperLog, @unchecked Sendable {
    public nonisolated static let emoji = "🤖"
    public nonisolated static let verbose: Bool = true
    private nonisolated static let logger = os.Logger(subsystem: "com.coffic.lumi", category: "plugin.model-selector.tools")

    public static let info = LumiAgentToolInfo(
        id: "list_available_models",
        displayName: LumiPluginLocalization.string("List Available Models"),
        description: LumiPluginLocalization.string(
            "List all available LLM providers and models. Returns provider+model pairs that passed connectivity checks. Returns all available results if no parameter is provided; can filter by provider."
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
                    "description": .string("Optional, filter by provider ID (e.g., OpenAI, Anthropic)"),
                ]),
            ]),
            "required": .array([]),
        ])
    }

    public func displayDescription(arguments: [String: LumiJSONValue]) -> String {
        "列出可用模型"
    }

    public func riskLevel(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext?) -> LumiCommandRiskLevel {
        .low
    }

    @MainActor
    public func execute(arguments: [String: LumiJSONValue], context: LumiToolExecutionContext) async throws -> String {
        let providerFilter = arguments["providerId"]?.stringValue
        let allProviders = chatService.providerInfos

        if Self.verbose {
            if let filter = providerFilter {
                Self.logger.info("[\(Self.emoji)] 查询可用模型，过滤供应商: \(filter)")
            } else {
                Self.logger.info("[\(Self.emoji)] 查询所有可用模型")
            }
        }

        if allProviders.isEmpty {
            if Self.verbose {
                Self.logger.warning("[\(Self.emoji)] 未注册任何 LLM 供应商")
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

        let providers = providerFilter != nil
            ? allProviders.filter { $0.id == providerFilter }
            : allProviders

        if providers.isEmpty, let filter = providerFilter {
            let registeredIds = allProviders.map(\.id)
            if Self.verbose {
                Self.logger.warning("[\(Self.emoji)] 未找到供应商: \(filter)，已注册: \(registeredIds)")
            }
            return """
            ## ❌ 未找到供应商：\(filter)

            当前已注册的供应商：
            \(registeredIds.map { "- `\($0)`" }.joined(separator: "\n"))

            请检查供应商 ID 是否正确。
            """
        }

        var availableMarkdown = ""
        var totalAvailablePairs = 0
        var unavailableByProvider: [String: (total: Int, sample: [String])] = [:]

        for info in providers {
            guard let provider = chatService.provider(forID: info.id) else {
                unavailableByProvider[info.id] = (info.availableModels.count, ["供应商实例未注册"])
                continue
            }

            var providerPairs: [(model: String, available: Bool, reason: String?)] = []
            for model in info.availableModels {
                let result = await provider.checkAvailability(model: model)
                switch result {
                case .available:
                    providerPairs.append((model, true, nil))
                case let .unavailable(failure):
                    let reason = failure.logSummary.isEmpty ? "未知原因" : failure.logSummary
                    providerPairs.append((model, false, reason))
                }
            }

            let availableModels = providerPairs.filter { $0.available }.map(\.model)
            if !availableModels.isEmpty {
                availableMarkdown += "### \(info.displayName) (`\(info.id)`)\n\n"
                for model in availableModels {
                    availableMarkdown += "- `\(model)`\n"
                }
                availableMarkdown += "\n"
                totalAvailablePairs += availableModels.count
            }

            let unavailable = providerPairs.filter { !$0.available }
            if !unavailable.isEmpty {
                let sample = unavailable.prefix(3).compactMap { $0.reason }
                unavailableByProvider[info.id] = (unavailable.count, Array(sample))
            }
        }

        if totalAvailablePairs == 0 {
            let providerSummaries = providers.map { info -> String in
                let total = info.availableModels.count
                let entry = unavailableByProvider[info.id]
                let statusSummary: String
                if let entry {
                    let reason = entry.sample.isEmpty ? "" : "（原因：\(entry.sample.joined(separator: "；"))）"
                    statusSummary = "\(entry.total)/\(total) 不可用\(reason)"
                } else {
                    statusSummary = "0/\(total) 可用"
                }
                return "- **\(info.displayName)** (`\(info.id)`)：\(statusSummary)"
            }

            if Self.verbose {
                Self.logger.warning("[\(Self.emoji)] 有 \(allProviders.count) 个注册供应商，但无可用模型")
            }

            return """
            ## ⚠️ 注册了 \(allProviders.count) 个 LLM 供应商，但没有可用模型

            已注册供应商：
            \(providerSummaries.joined(separator: "\n"))

            可能的原因：
            1. API Key 未配置（请在设置中为对应供应商填写 API Key）
            2. API Key 已过期或无效
            3. 网络连接异常，可用性检测未通过

            请在设置中检查各供应商的 API Key 配置。
            """
        }

        if Self.verbose {
            Self.logger.info("[\(Self.emoji)] 返回 \(totalAvailablePairs) 个可用模型对")
        }

        return """
        ## 可用 LLM 供应商和模型

        \(availableMarkdown)
        """
    }
}
