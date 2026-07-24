import Foundation

/// Lightweight persistence for ModelSelector settings pages.
/// Stores selected provider IDs in UserDefaults.
@MainActor
final class ProviderSettingsStore {
    static let shared = ProviderSettingsStore()

    private let defaults = UserDefaults.standard

    private enum Keys {
        static let selectedLocalProviderID = "ModelSelector.selectedLocalProviderID"
        static let selectedRemoteProviderID = "ModelSelector.selectedRemoteProviderID"
    }

    private init() {}

    func saveSelectedLocalProviderID(_ id: String) {
        defaults.set(id, forKey: Keys.selectedLocalProviderID)
    }

    func loadSelectedLocalProviderID() -> String? {
        defaults.string(forKey: Keys.selectedLocalProviderID)
    }

    func saveSelectedRemoteProviderID(_ id: String) {
        defaults.set(id, forKey: Keys.selectedRemoteProviderID)
    }

    func loadSelectedRemoteProviderID() -> String? {
        defaults.string(forKey: Keys.selectedRemoteProviderID)
    }
}
