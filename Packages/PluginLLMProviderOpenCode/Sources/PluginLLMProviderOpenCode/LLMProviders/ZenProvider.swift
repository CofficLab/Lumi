import KitLLM
import Foundation
import ProviderLLMManager

/// OpenCode Zen 供应商（Zen 系列模型网关）。
///
/// 骨架实现，待补充具体模型列表与协议路由。
@MainActor
public final class ZenProvider: VendorLLMProvider {

    private static let base = "https://opencode.ai/zen/v1"

    public init(apiService: VendorAPIService = VendorAPIService()) {
        super.init(
            info: LLMProviderInfo(
                id: "opencode-zen",
                displayName: "OpenCode Zen",
                description: "OpenCode Zen 系列模型服务",
                defaultModel: "",
                models: [],
                websiteURL: URL(string: "https://opencode.ai")!,
                providerType: .cloudService,
                apiFormat: .openAI,
                apiKeyStorageKey: "DevAssistant_ApiKey_OpenCodeZen"
            ),
            apiService: apiService
        )
    }
}
