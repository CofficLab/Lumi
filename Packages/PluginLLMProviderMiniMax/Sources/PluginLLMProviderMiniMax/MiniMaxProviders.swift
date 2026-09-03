import KitLLM
import Foundation
import ProviderLLMManager

/// MiniMax 供应商族：三个协议变体共用的模型列表。
enum MiniMaxVendorModels {
    static let all: [LLMModelInfo] = [
        LLMModelInfo(id: "MiniMax-M3", contextWindowSize: 1_000_000, supportsVision: true),
        LLMModelInfo(id: "MiniMax-M2.7", contextWindowSize: 204_800, supportsVision: true),
        LLMModelInfo(id: "MiniMax-M2.7-highspeed", contextWindowSize: 204_800, supportsVision: true),
        LLMModelInfo(id: "MiniMax-M2.5", contextWindowSize: 204_800, supportsVision: false),
        LLMModelInfo(id: "MiniMax-M2.5-highspeed", contextWindowSize: 204_800, supportsVision: false),
    ]
}

/// MiniMax TokenPlan OpenAI 协议变体（迁移自旧 `MiniMaxOpenAIProvider`）。
@MainActor
public final class MiniMaxOpenAIProvider: VendorLLMProvider {

    public init(apiService: VendorAPIService = VendorAPIService()) {
        super.init(
            info: LLMProviderInfo(
                id: "minimax-tokenplan",
                displayName: "MiniMax (OpenAI)",
                description: "MiniMax Token Plan via OpenAI-compatible API",
                defaultModel: "MiniMax-M2.7",
                models: MiniMaxVendorModels.all,
                websiteURL: URL(string: "https://platform.minimaxi.com/")!,
                apiFormat: .openAI,
                apiKeyStorageKey: "DevAssistant_ApiKey_MiniMax"
            ),
            apiService: apiService
        )
    }


    public override var openAIConfiguration: OpenAICompatibleProviderConfiguration? {
        OpenAICompatibleProviderConfiguration(
            baseURL: "https://api.minimaxi.com/v1/chat/completions"
        )
    }
}

/// MiniMax Anthropic 协议变体（迁移自旧 `MiniMaxAnthropicProvider`）。
///
/// 已停用：与 OpenAI 变体共享同一批模型与 API Key，当前仅保留 OpenAI 变体。
/// 如需恢复，取消注释并在 MiniMaxProviderPlugin 中重新注册。
// @MainActor
// public final class MiniMaxAnthropicProvider: VendorLLMProvider {
//
//     public init(apiService: VendorAPIService = VendorAPIService()) {
//         super.init(
//             info: LLMProviderInfo(
//                 id: "minimax-tokenplan-anthropic",
//                 displayName: "MiniMax (Anthropic)",
//                 description: "MiniMax Token Plan via Anthropic-compatible API",
//                 defaultModel: "MiniMax-M2.7",
//                 models: MiniMaxVendorModels.all,
//                 websiteURL: URL(string: "https://platform.minimaxi.com/")!,
//                 apiFormat: .anthropic,
//                 apiKeyStorageKey: "DevAssistant_ApiKey_MiniMax"
//             ),
//             apiService: apiService
//         )
//     }
//
//
//     public override var anthropicConfiguration: AnthropicCompatibleProviderConfiguration? {
//         AnthropicCompatibleProviderConfiguration(
//             baseURL: "https://api.minimax.chat/anthropic/v1/messages"
//         )
//     }
// }

/// MiniMax Responses 协议变体（迁移自旧 `MiniMaxResponsesProvider`）。
///
/// 已停用：与 OpenAI 变体共享同一批模型与 API Key，当前仅保留 OpenAI 变体。
/// 如需恢复，取消注释并在 MiniMaxProviderPlugin 中重新注册。
// @MainActor
// public final class MiniMaxResponsesProvider: VendorLLMProvider {
//
//     public init(apiService: VendorAPIService = VendorAPIService()) {
//         super.init(
//             info: LLMProviderInfo(
//                 id: "minimax-responses",
//                 displayName: "MiniMax (Responses)",
//                 description: "MiniMax Token Plan via OpenAI Responses API",
//                 defaultModel: "MiniMax-M3",
//                 models: MiniMaxVendorModels.all,
//                 websiteURL: URL(string: "https://platform.minimaxi.com/")!,
//                 apiFormat: .responses,
//                 apiKeyStorageKey: "DevAssistant_ApiKey_MiniMax"
//             ),
//             apiService: apiService
//         )
//     }
//
//     public override var responsesEndpointURL: String {
//         "https://api.minimaxi.com/v1/responses"
//     }
//
// }
