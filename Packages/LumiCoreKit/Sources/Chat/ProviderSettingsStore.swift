import Foundation

@MainActor
public final class ProviderSettingsStore {
    public static let shared = ProviderSettingsStore()

    private let settingsURL: URL

    private enum Keys {
        static let selectedRemoteProviderID = "App_SelectedRemoteProviderId"
        static let selectedLocalProviderID = "App_SelectedLocalProviderId"
        static let remoteProviderModels = "App_RemoteProviderModels"
        static let localProviderModels = "App_LocalProviderModels"
    }

    private init() {
        let directory = LumiCore.pluginDataDirectory(for: "ProviderSettings")
        self.settingsURL = directory.appendingPathComponent("settings.plist")
    }

    public func loadSelectedRemoteProviderID() -> String? {
        string(forKey: Keys.selectedRemoteProviderID)
    }

    public func saveSelectedRemoteProviderID(_ id: String?) {
        set(id, forKey: Keys.selectedRemoteProviderID)
    }

    public func loadSelectedLocalProviderID() -> String? {
        string(forKey: Keys.selectedLocalProviderID)
    }

    public func saveSelectedLocalProviderID(_ id: String?) {
        set(id, forKey: Keys.selectedLocalProviderID)
    }

    public func loadRemoteProviderModel(providerID: String) -> String? {
        dictionary(forKey: Keys.remoteProviderModels)[providerID]
    }

    public func saveRemoteProviderModel(providerID: String, modelID: String?) {
        var models = dictionary(forKey: Keys.remoteProviderModels)
        if let modelID {
            models[providerID] = modelID
        } else {
            models.removeValue(forKey: providerID)
        }
        set(models, forKey: Keys.remoteProviderModels)
    }

    public func loadLocalProviderModel(providerID: String) -> String? {
        dictionary(forKey: Keys.localProviderModels)[providerID]
    }

    public func saveLocalProviderModel(providerID: String, modelID: String?) {
        var models = dictionary(forKey: Keys.localProviderModels)
        if let modelID {
            models[providerID] = modelID
        } else {
            models.removeValue(forKey: providerID)
        }
        set(models, forKey: Keys.localProviderModels)
    }

    private func string(forKey key: String) -> String? {
        dictionary()[key] as? String
    }

    private func dictionary(forKey key: String) -> [String: String] {
        dictionary()[key] as? [String: String] ?? [:]
    }

    private func dictionary() -> [String: Any] {
        guard let data = try? Data(contentsOf: settingsURL),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil),
              let dictionary = plist as? [String: Any]
        else {
            return [:]
        }
        return dictionary
    }

    private func set(_ value: Any?, forKey key: String) {
        var dictionary = dictionary()
        if let value {
            dictionary[key] = value
        } else {
            dictionary.removeValue(forKey: key)
        }
        persist(dictionary)
    }

    private func persist(_ dictionary: [String: Any]) {
        guard let data = try? PropertyListSerialization.data(
            fromPropertyList: dictionary,
            format: .xml,
            options: 0
        ) else {
            return
        }

        do {
            try FileManager.default.createDirectory(
                at: settingsURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try data.write(to: settingsURL, options: .atomic)
        } catch {
            assertionFailure("Failed to save provider settings: \(error)")
        }
    }
}
