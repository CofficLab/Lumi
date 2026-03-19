import Foundation

/// 统一插件态存储。
/// 所有键值数据存放在 getDBFolderURL()/StatePersistencePlugin/settings/state.plist
final class PluginStateStore: @unchecked Sendable {
    static let shared = PluginStateStore()

    private let fileManager = FileManager.default
    private let queue = DispatchQueue(label: "PluginStateStore.queue", qos: .userInitiated)
    private let settingsDir: URL
    private let stateFileURL: URL

    private init() {
        let root = AppConfig.getDBFolderURL()
            .appendingPathComponent("StatePersistencePlugin", isDirectory: true)
            .appendingPathComponent("settings", isDirectory: true)
        self.settingsDir = root
        self.stateFileURL = root.appendingPathComponent("state.plist")
        try? fileManager.createDirectory(at: settingsDir, withIntermediateDirectories: true)
    }

    func set(_ value: Any?, forKey key: String) {
        queue.sync {
            var dict = readAll()
            if let value {
                dict[key] = value
            } else {
                dict.removeValue(forKey: key)
            }
            writeAll(dict)
        }
    }

    func removeObject(forKey key: String) {
        set(nil, forKey: key)
    }

    func removeLegacyValue(forKey key: String) {
        let legacyDir = AppConfig.getDBFolderURL().appendingPathComponent("app_settings", isDirectory: true)
        let legacyFile = legacyDir.appendingPathComponent(sanitizeLegacyKey(key) + ".plist")
        if fileManager.fileExists(atPath: legacyFile.path) {
            try? fileManager.removeItem(at: legacyFile)
        }
    }

    func object(forKey key: String) -> Any? {
        queue.sync {
            var dict = readAll()
            if let existing = dict[key] {
                return existing
            }

            // 兼容迁移：若新存储没有该 key，尝试从旧 app_settings 单文件读取一次
            if let legacy = readLegacyValue(forKey: key) {
                dict[key] = legacy
                writeAll(dict)
                return legacy
            }

            return nil
        }
    }

    func string(forKey key: String) -> String? {
        object(forKey: key) as? String
    }

    func data(forKey key: String) -> Data? {
        object(forKey: key) as? Data
    }

    func bool(forKey key: String) -> Bool {
        (object(forKey: key) as? Bool) ?? false
    }

    func array(forKey key: String) -> [Any]? {
        object(forKey: key) as? [Any]
    }

    private func readAll() -> [String: Any] {
        guard fileManager.fileExists(atPath: stateFileURL.path),
              let data = try? Data(contentsOf: stateFileURL),
              let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
              let dict = plist as? [String: Any] else {
            return [:]
        }
        return dict
    }

    private func writeAll(_ dict: [String: Any]) {
        guard let data = try? PropertyListSerialization.data(fromPropertyList: dict, format: .binary, options: 0) else {
            return
        }

        let tmp = settingsDir.appendingPathComponent("state.tmp")
        do {
            try data.write(to: tmp, options: .atomic)
            if fileManager.fileExists(atPath: stateFileURL.path) {
                _ = try? fileManager.replaceItemAt(stateFileURL, withItemAt: tmp)
            } else {
                try fileManager.moveItem(at: tmp, to: stateFileURL)
            }
        } catch {
            try? fileManager.removeItem(at: tmp)
        }
    }

    private func readLegacyValue(forKey key: String) -> Any? {
        let legacyDir = AppConfig.getDBFolderURL().appendingPathComponent("app_settings", isDirectory: true)
        let legacyFile = legacyDir.appendingPathComponent(sanitizeLegacyKey(key) + ".plist")

        guard fileManager.fileExists(atPath: legacyFile.path),
              let data = try? Data(contentsOf: legacyFile),
              let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) else {
            return nil
        }

        if let dict = plist as? [String: Any], let dataVal = dict["_data"] as? Data {
            return dataVal
        }

        return plist
    }

    private func sanitizeLegacyKey(_ key: String) -> String {
        let safe = key.unicodeScalars
            .map { CharacterSet.alphanumerics.contains($0) || $0 == "_" ? String($0) : "_" }
            .joined()
        return safe.isEmpty ? "key" : safe
    }
}
