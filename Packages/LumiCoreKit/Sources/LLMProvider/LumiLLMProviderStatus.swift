import Foundation

public struct LumiLLMProviderStatus: Equatable, Sendable {
    public enum Level: Equatable, Sendable {
        case info
        case warning
        case error
    }

    public let message: String
    public let level: Level

    public init(message: String, level: Level) {
        self.message = message
        self.level = level
    }
}

public enum LumiLLMProviderStatusSupport {
    public static func missingAPIKeyStatus(providerName: String) -> LumiLLMProviderStatus {
        LumiLLMProviderStatus(
            message: LumiPluginLocalization.string("API Key not configured", bundle: .module),
            level: .warning
        )
    }

    /// Default status for remote providers that require an API key.
    ///
    /// 必须传 `any LumiLLMProvider` 实例；存储策略由 Provider 自己决定。
    /// 不再提供 `providerInfo:` 重载：避免外部代码绕开 Provider 封装直接读存储键。
    public static func statusForRemoteAPIKeyProvider(
        provider: any LumiLLMProvider
    ) -> LumiLLMProviderStatus? {
        let info = type(of: provider).info
        guard !info.isLocal else { return nil }
        guard hasConfiguredAPIKey(provider: provider) else {
            return missingAPIKeyStatus(providerName: info.displayName)
        }
        return nil
    }

    /// 基于 `provider.hasApiKey()` 判定。
    public static func hasConfiguredAPIKey(provider: any LumiLLMProvider) -> Bool {
        provider.hasApiKey()
    }
}
