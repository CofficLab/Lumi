import Foundation
import KernelLumi
import LLMKit

@MainActor
final class CustomProviderStore {
    static let shared = CustomProviderStore()
    static let didChange = Notification.Name("LLMProviderManager.CustomProvidersDidChange")
    private let defaultsKey = "LLMProviderManager.customProviderConfigurations"

    func load() -> [CustomProviderConfiguration] {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let values = try? JSONDecoder().decode([CustomProviderConfiguration].self, from: data) else { return [] }
        return values
    }

    func save(_ configurations: [CustomProviderConfiguration]) {
        if let data = try? JSONEncoder().encode(configurations) {
            UserDefaults.standard.set(data, forKey: defaultsKey)
            NotificationCenter.default.post(name: Self.didChange, object: nil)
        }
    }

    func apiKey(for configuration: CustomProviderConfiguration) -> String {
        LumiAPIKeyTools.get(storageKey: configuration.apiKeyStorageKey)
    }

    func saveAPIKey(_ apiKey: String, for configuration: CustomProviderConfiguration) {
        LumiAPIKeyTools.set(apiKey.trimmingCharacters(in: .whitespacesAndNewlines), storageKey: configuration.apiKeyStorageKey)
    }

    func removeAPIKey(for configuration: CustomProviderConfiguration) {
        LumiAPIKeyTools.remove(storageKey: configuration.apiKeyStorageKey)
    }
}
