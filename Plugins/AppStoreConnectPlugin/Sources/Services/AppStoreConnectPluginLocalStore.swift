import Foundation
import LumiKernel

/// Persists App Store Connect plugin preferences.
///
/// Storage: `<LumiCore.dataRootDirectory>/AppStoreConnectPlugin/settings.plist`
final class AppStoreConnectPluginLocalStore: @unchecked Sendable {
    static let shared = AppStoreConnectPluginLocalStore()

    private let fileManager = FileManager.default
    private let queue = DispatchQueue(label: "AppStoreConnectPluginLocalStore.queue", qos: .userInitiated)
    private let pluginDirectory: URL
    private let settingsFileURL: URL

    init(pluginDirectory: URL? = nil) {
        let root = pluginDirectory ?? (AppStoreConnectPluginRuntimeBridge.dataRootDirectory
            ?? AppStoreConnectPluginRuntimeBridge.fallbackRootDirectory)
            .appendingPathComponent("AppStoreConnectPlugin", isDirectory: true)
        self.pluginDirectory = root
        self.settingsFileURL = root.appendingPathComponent("settings.plist")
        try? fileManager.createDirectory(at: root, withIntermediateDirectories: true)
    }

    func selectedAppID(for credentials: AppStoreConnectCredentials) -> String? {
        guard credentials.isComplete else { return nil }
        return string(forKey: Self.selectedAppKey(for: credentials))
    }

    func setSelectedAppID(_ appID: String?, for credentials: AppStoreConnectCredentials) {
        guard credentials.isComplete else { return }
        set(appID, forKey: Self.selectedAppKey(for: credentials))
    }

    func selectedCoverArtSlug(appID: String) -> String? {
        string(forKey: Self.selectedCoverArtSlugKey(appID: appID))
    }

    func setSelectedCoverArtSlug(_ slug: String?, appID: String) {
        set(slug, forKey: Self.selectedCoverArtSlugKey(appID: appID))
    }

    private static func selectedAppKey(for credentials: AppStoreConnectCredentials) -> String {
        "selectedAppID.\(credentials.issuerID).\(credentials.keyID)"
    }

    private static func selectedCoverArtSlugKey(appID: String) -> String {
        "selectedCoverArtSlug.\(appID)"
    }

    private func set(_ value: Any?, forKey key: String) {
        queue.sync {
            var dict = readDict()
            if let value {
                dict[key] = value
            } else {
                dict.removeValue(forKey: key)
            }
            writeDict(dict)
        }
    }

    private func string(forKey key: String) -> String? {
        queue.sync { readDict()[key] as? String }
    }

    private func readDict() -> [String: Any] {
        guard let data = try? Data(contentsOf: settingsFileURL),
              let dict = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] else {
            return [:]
        }
        return dict
    }

    private func writeDict(_ dict: [String: Any]) {
        guard let data = try? PropertyListSerialization.data(fromPropertyList: dict, format: .binary, options: 0) else {
            return
        }
        try? fileManager.createDirectory(at: pluginDirectory, withIntermediateDirectories: true)
        let temporaryURL = pluginDirectory.appendingPathComponent("settings.tmp")
        do {
            try data.write(to: temporaryURL, options: .atomic)
            if fileManager.fileExists(atPath: settingsFileURL.path) {
                try fileManager.removeItem(at: settingsFileURL)
            }
            try fileManager.moveItem(at: temporaryURL, to: settingsFileURL)
        } catch {
            try? fileManager.removeItem(at: temporaryURL)
        }
    }
}
