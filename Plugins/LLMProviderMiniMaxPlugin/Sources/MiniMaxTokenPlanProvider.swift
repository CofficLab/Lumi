import Foundation
import HttpKit
import LumiCoreKit
import LumiLLMProviderSupport

/// MiniMax Token Plan 提供商。
///
/// MiniMax（MiniMax）的 Token Plan 是面向开发者与企业的统一订阅计划，
/// 通过 Anthropic 兼容接口暴露给第三方调用。本插件复用
/// `AnthropicCompatibleLumiProvider`，仅负责：
///
/// 1. 暴露 MiniMax Token Plan 支持的模型清单（`MiniMax-M2.7` 等）。
/// 2. 维护 API Key 的本地存取（`LumiAPIKeyStore`）。
/// 3. 错误信息映射为 `MiniMaxRenderKind`，便于 UI 渲染。
public final class MiniMaxTokenPlanProvider: AnthropicCompatibleProvider, @unchecked Sendable {
    /// 在错误卡片上显示的短名。
    public static let shortName = "MiniMax"

    /// 获取 API Key 的帮助页面（MiniMax 开放平台 Token Plan 管理）。
    public static let apiKeyHelpURL: String? = "https://platform.minimaxi.com/user-center/basic-information/Interface-key"

    public override class var info: LumiLLMProviderInfo {
        LumiLLMProviderInfo(
            id: "minimax-tokenplan",
            displayName: LumiPluginLocalization.string("MiniMax TokenPlan", bundle: .module),
            description: LumiPluginLocalization.string("MiniMax Token Plan (Anthropic-compatible)", bundle: .module),
            defaultModel: "MiniMax-M2.7",
            availableModels: [
                "MiniMax-M3",
                "MiniMax-M2.7",
                "MiniMax-M2.7-highspeed",
                "MiniMax-M2.5",
                "MiniMax-M2",
                "MiniMax-Text-01"
            ],
            contextWindowSizes: [
                "MiniMax-M3": 204_800,
                "MiniMax-M2.7": 204_800,
                "MiniMax-M2.7-highspeed": 204_800,
                "MiniMax-M2.5": 204_800,
                "MiniMax-M2": 131_072,
                "MiniMax-Text-01": 4_000_000
            ],
            modelCapabilities: [
                "MiniMax-M3": .init(supportsVision: true, supportsTools: true),
                "MiniMax-M2.7": .init(supportsVision: true, supportsTools: true),
                "MiniMax-M2.7-highspeed": .init(supportsVision: true, supportsTools: true),
                "MiniMax-M2.5": .init(supportsVision: false, supportsTools: true),
                "MiniMax-M2": .init(supportsVision: false, supportsTools: true),
                "MiniMax-Text-01": .init(supportsVision: false, supportsTools: false)
            ],
            websiteURL: URL(string: "https://platform.minimaxi.com/")!
        ,
            apiKeyStorageKey: "DevAssistant_ApiKey_MiniMax"
        )
    }

    public init() {
        super.init(
            configuration: LumiAnthropicCompatibleProviderConfiguration(
                baseURL: "https://api.minimax.chat/anthropic/v1/messages"
            )
        )
    }

    public override func errorRenderKind(for error: Error) -> String? {
        if case LumiLLMProviderSupportError.missingAPIKey = error {
            return MiniMaxRenderKind.apiKeyMissing
        }

        if let statusCode = LumiLLMHTTPErrorParsing.statusCode(from: error) {
            return MiniMaxRenderKind.http(statusCode)
        }

        return MiniMaxRenderKind.requestFailed
    }

    public override func checkAvailability(model: String) async -> LumiModelAvailabilityResult {
        await AvailabilityService.checkAvailability(provider: self, model: model)
    }

    public override func providerStatus() -> LumiLLMProviderStatus? {
        LumiLLMProviderStatusSupport.statusForRemoteAPIKeyProvider(provider: self)
    }
}
