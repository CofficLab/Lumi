import KitLLM
import Foundation
import ProviderLLMManager

/// CommandCode GoatPlan 供应商（OpenAI 兼容协议）。
///
/// 通过 CommandCode 统一网关访问多种模型，使用 OpenAI Chat Completions 格式。
///
/// 模型列表来源（按优先级）：
/// 1. 远程模型池（`/provider/v1/models`），由 `RemoteModelListLoader` 解析并缓存。
/// 2. 磁盘缓存（`LLMModelListCache`），跨启动保留，失败时兜底。
/// 3. 下方 `providerInfo.models` 中硬编码的 4 个主力模型，仅在完全无网络、无缓存时生效。
///
/// 上游加模型无需改本文件——刷新一次即可拿到新模型池。
@MainActor
public final class GoatPlanProvider: VendorLLMProvider {

    public init(apiService: VendorAPIService = VendorAPIService()) {
        super.init(
            info: LLMProviderInfo(
                id: "goatplan",
                displayName: "CommandCode GoatPlan",
                description: "CommandCode GoatPlan 多模型订阅服务（远程模型源）",
                defaultModel: "deepseek/deepseek-v4-flash",
                models: [
                    // 最小离线兜底基线。远程模型源可用时会被动态池覆盖。
                    LLMModelInfo(id: "deepseek/deepseek-v4-flash", displayName: "DeepSeek V4 Flash", contextWindowSize: 1_000_000),
                    LLMModelInfo(id: "claude-sonnet-5", displayName: "Claude Sonnet 5", contextWindowSize: 1_000_000),
                    LLMModelInfo(id: "gpt-5.5", displayName: "GPT-5.5", contextWindowSize: 400_000),
                    LLMModelInfo(id: "google/gemini-3.5-flash", displayName: "Gemini 3.5 Flash", contextWindowSize: 1_000_000),
                ],
                websiteURL: URL(string: "https://commandcode.ai")!,
                providerType: .cloudService,
                apiFormat: .openAI,
                apiKeyStorageKey: "DevAssistant_ApiKey_CommandCodeGoatPlan"
            ),
            apiService: apiService
        )
    }

    /// 远程模型源：拉取 CommandCode `/provider/v1/models` 端点。
    public override var remoteModelSource: RemoteModelSource? {
        RemoteModelSource(
            endpoint: URL(string: "https://api.commandcode.ai/provider/v1/models")!,
            apiKeyStorageKey: "DevAssistant_ApiKey_CommandCodeGoatPlan"
        )
    }

    public override var openAIConfiguration: OpenAICompatibleProviderConfiguration? {
        OpenAICompatibleProviderConfiguration(
            baseURL: "https://api.commandcode.ai/provider/v1/chat/completions"
        )
    }
}