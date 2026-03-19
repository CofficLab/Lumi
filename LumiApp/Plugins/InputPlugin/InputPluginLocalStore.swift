import Foundation

final class InputPluginLocalStore: @unchecked Sendable {
    private let fileManager = FileManager.default
    private let queue = DispatchQueue(label: "InputPluginLocalStore.queue", qos: .userInitiated)
    private let settingsDirectory: URL
    private let settingsFileURL: URL

    init() {
        let root = AppConfig.getDBFolderURL()
            .appendingPathComponent("InputPlugin", isDirectory: true)
            .appendingPathComponent("settings", isDirectory: true)
        self.settingsDirectory = root
        self.settingsFileURL = root.appendingPathComponent("settings.plist")
        try? fileManager.createDirectory(at: settingsDirectory, withIntermediateDirectories: true)
    }

    func migrateLegacyValueIfMissing(forKey key: String) {
        guard data(forKey: key) == nil else { return }
        guard let legacy = readLegacyObject(forKey: key) else { return }
        set(legacy, forKey: key)
    }

    func set(_ value: Any?, forKey key: String) {
        queue.sync {
            var dict = readDict()
            if let value { dict[key] = value } else { dict.removeValue(forKey: key) }
            writeDict(dict)
        }
    }

    func data(forKey key: String) -> Data? { object(forKey: key) as? Data }
    func object(forKey key: String) -> Any? { queue.sync { readDict()[key] } }

    private func readDict() -> [String: Any] {
        guard fileManager.fileExists(atPath: settingsFileURL.path),
              let data = try? Data(contentsOf: settingsFileURL),
              let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
              let dict = plist as? [String: Any] else { return [:] }
        return dict
    }

    private func writeDict(_ dict: [String: Any]) {
        guard let data = try? PropertyListSerialization.data(fromPropertyList: dict, format: .binary, options: 0) else { return }
        let tmp = settingsDirectory.appendingPathComponent("settings.tmp")
        do {
            try data.write(to: tmp, options: .atomic)
            if fileManager.fileExists(atPath: settingsFileURL.path) { _ = try? fileManager.replaceItemAt(settingsFileURL, withItemAt: tmp) }
            else { try fileManager.moveItem(at: tmp, to: settingsFileURL) }
        } catch { try? fileManager.removeItem(at: tmp) }
    }

    private func readLegacyObject(forKey key: String) -> Any? {
        let legacyDir = AppConfig.getDBFolderURL().appendingPathComponent("app_settings", isDirectory: true)
        let legacyFile = legacyDir.appendingPathComponent(sanitize(key) + ".plist")
        guard fileManager.fileExists(atPath: legacyFile.path),
              let data = try? Data(contentsOf: legacyFile),
              let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) else { return nil }
        if let dict = plist as? [String: Any], let dataVal = dict["_data"] as? Data { return dataVal }
        return plist
    }

    private func sanitize(_ key: String) -> String {
        let safe = key.unicodeScalars.map { CharacterSet.alphanumerics.contains($0) || $0 == "_" ? String($0) : "_" }.joined()
        return safe.isEmpty ? "key" : safe
    }
}
