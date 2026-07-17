import Foundation
import LumiCoreKit
import LumiLLMProviderSupport

/// 智谱 API（OpenAI 兼容协议）
///
/// 与 `ZhipuProvider`（CodingPlan 计费入口，走 Anthropic 协议 + Claude Code 模拟）同属智谱 GLM 系列，
/// 但走标准的 OpenAI 兼容接口（`https://open.bigmodel.cn/api/paas/v4/chat/completions`），
/// 使用独立的 API Key 与按量计费。两者模型清单一致，方便用户在「Coding Plan 套餐」与「标准 API」间切换。
public final class ZhipuAPIProvider: OpenAICompatibleLumiProvider, @unchecked Sendable {
    public static let shortName = "ZhiPu API"
    public static let apiKeyHelpURL: String? = "https://open.bigmodel.cn/usercenter/apikeys"

    public override class var info: LumiLLMProviderInfo {
        LumiLLMProviderInfo(
            id: "zhipu-api",
            displayName: LumiPluginLocalization.string("智谱 API", bundle: .module),
            description: LumiPluginLocalization.string("Zhipu AI GLM (OpenAI-compatible)", bundle: .module),
            defaultModel: "glm-4.7",
            availableModels: [
                "glm-5.2",
                "glm-5.1",
                "glm-5-turbo",
                "glm-5",
                "glm-4.7",
                "glm-4.6",
                "glm-4.5",
                "glm-4.5-air",
            ],
            contextWindowSizes: [
                "glm-5.2": 1_000_000,
                "glm-5.1": 1_000_000,
                "glm-5-turbo": 1_000_000,
                "glm-5": 1_000_000,
                "glm-4.7": 128_000,
                "glm-4.6": 200_000,
                "glm-4.5": 128_000,
                "glm-4.5-air": 128_000
            ],
            modelCapabilities: [
                "glm-5.2": .init(supportsVision: true, supportsTools: true),
                "glm-5.1": .init(supportsVision: true, supportsTools: true),
                "glm-5-turbo": .init(supportsVision: true, supportsTools: true),
                "glm-5": .init(supportsVision: true, supportsTools: true),
                "glm-4.7": .init(supportsVision: false, supportsTools: true),
                "glm-4.6": .init(supportsVision: true, supportsTools: true),
                "glm-4.5": .init(supportsVision: true, supportsTools: true),
                "glm-4.5-air": .init(supportsVision: true, supportsTools: true)
            ],
            websiteURL: URL(string: "https://www.bigmodel.cn/")!
        ,
            apiKeyStorageKey: "DevAssistant_ApiKey_ZhipuAPI"
        )
    }

    public init() {
        super.init(
            configuration: LumiOpenAICompatibleProviderConfiguration(
                baseURL: "https://open.bigmodel.cn/api/paas/v4/chat/completions",
                additionalHeaders: [:],
                includeUsageInStreamOptions: false,
                returnsEmptyChunkWhenNoDelta: false,
                acceptsFunctionScopedToolCallID: false
            )
        )
    }

    public override func errorRenderKind(for error: Error) -> String? {
        if case LumiLLMProviderSupportError.missingAPIKey = error {
            return ZhipuRenderKind.apiKeyMissing
        }

        if let statusCode = LumiLLMHTTPErrorParsing.statusCode(from: error) {
            return ZhipuRenderKind.http(statusCode)
        }

        return ZhipuRenderKind.requestFailed
    }

    public override func checkAvailability(model: String) async -> LumiModelAvailabilityResult {
        await AvailabilityService.checkAvailability(model: model, check: { await self.checkAvailabilityUsingChatPing(model: $0) })
    }

    public override func providerStatus() -> LumiLLMProviderStatus? {
        LumiLLMProviderStatusSupport.statusForRemoteAPIKeyProvider(provider: self)
    }
}
