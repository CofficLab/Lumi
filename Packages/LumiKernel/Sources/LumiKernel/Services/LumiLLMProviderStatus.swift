import Foundation

public struct LumiLLMProviderStatus: Sendable, Equatable {
    public let message: String
    public let level: Level
    public let isBlocking: Bool

    public init(message: String, level: Level, isBlocking: Bool = false) {
        self.message = message
        self.level = level
        self.isBlocking = isBlocking
    }

    public enum Level: Sendable, Equatable {
        case info
        case warning
        case error
    }
}

public enum LumiLLMProviderStatusSupport {
    public static func missingAPIKeyStatus(providerName: String) -> LumiLLMProviderStatus {
        LumiLLMProviderStatus(
            message: "API Key 未配置",
            level: .warning,
            isBlocking: true
        )
    }

    public static func statusForRemoteAPIKeyProvider(provider: LumiLLMProvider) -> LumiLLMProviderStatus? {
        provider.providerStatus()
    }

    public static func hasConfiguredAPIKey(provider: LumiLLMProvider) -> Bool {
        provider.hasApiKey()
    }
}
