import Foundation
import LLMKit

extension SuperLLMProvider {
    /// 是否需要持久化存储 API Key（`apiKeyStorageKey` 为空时不需要，如 Codex CLI）
    public static var requiresStoredApiKey: Bool {
        !apiKeyStorageKey.isEmpty
    }

    public static func getApiKey() -> String {
        guard requiresStoredApiKey else { return "" }
        return ProviderCredentialStore.shared.string(forKey: apiKeyStorageKey) ?? ""
    }

    public static func setApiKey(_ value: String) {
        guard requiresStoredApiKey else { return }
        ProviderCredentialStore.shared.set(value, forKey: apiKeyStorageKey)
    }

    public static func removeApiKey() {
        guard requiresStoredApiKey else { return }
        ProviderCredentialStore.shared.remove(forKey: apiKeyStorageKey)
    }

    public static var hasApiKey: Bool {
        !requiresStoredApiKey || !getApiKey().isEmpty
    }

    /// 远程供应商在发起请求前校验凭证是否已配置
    public static func validateCredentials() throws {
        guard requiresStoredApiKey else { return }
        if getApiKey().trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw LLMServiceError.apiKeyEmpty
        }
    }
}
