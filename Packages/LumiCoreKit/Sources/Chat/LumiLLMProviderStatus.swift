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
        providerID: String,
        displayName: String,
        isLocal: Bool = false
    ) -> LumiLLMProviderStatus? {
        guard !isLocal else { return nil }
        guard hasConfiguredAPIKey(providerID: providerID) else {
            return missingAPIKeyStatus(providerName: displayName)
        }
        return nil
    }

    public static func hasConfiguredAPIKey(providerID: String) -> Bool {
        guard !LumiLLMProviderKeys.isLocalProvider(id: providerID),
              let storageKey = LumiLLMProviderKeys.apiKeyStorageKey(forProviderID: providerID)
        else {
            return true
        }

        let key = LumiAPIKeyStore.shared.loadMigratingLegacyUserDefaults(forKey: storageKey)
        return key?.isEmpty == false
    }
}
