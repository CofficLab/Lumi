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
    public static func statusForRemoteAPIKeyProvider(
        providerInfo: LumiLLMProviderInfo
    ) -> LumiLLMProviderStatus? {
        guard !providerInfo.isLocal else { return nil }
        guard hasConfiguredAPIKey(providerInfo: providerInfo) else {
            return missingAPIKeyStatus(providerName: providerInfo.displayName)
        }
        return nil
    }

    public static func hasConfiguredAPIKey(providerInfo: LumiLLMProviderInfo) -> Bool {
        guard !providerInfo.isLocal,
              let storageKey = providerInfo.apiKeyStorageKey
        else {
            return true
        }

        let key = LumiAPIKeyStore.shared.loadMigratingLegacyUserDefaults(forKey: storageKey)
        return key?.isEmpty == false
    }
}
