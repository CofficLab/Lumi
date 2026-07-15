import Foundation
import LumiCoreKit

/// AgentTempStorage 插件本地存储
///
/// 存储位置：<LumiCore.dataRootDirectory>/AgentTempStorage/settings.plist
final class AgentTempStoragePluginLocalStore: @unchecked Sendable {
    static let shared = AgentTempStoragePluginLocalStore()

    static let defaultRetentionDays = 7

    private let fileManager = FileManager.default
    private let queue = DispatchQueue(label: "AgentTempStoragePluginLocalStore.queue", qos: .userInitiated)
    private let pluginDirectory: URL
    private let settingsFileURL: URL

    private init() {
        let root = lumiCorePluginDataDirectory(for: "AgentTempStorage")
            ?? lumiCoreFallbackDataRootDirectory.appendingPathComponent("AgentTempStorage", isDirectory: true)
        self.pluginDirectory = root
        self.settingsFileURL = root.appendingPathComponent("settings.plist")
        try? fileManager.createDirectory(at: pluginDirectory, withIntermediateDirectories: true)
    }

    var retentionDays: Int {
        let stored = queue.sync { integer(forKey: Keys.retentionDays) }
        return stored > 0 ? stored : Self.defaultRetentionDays
    }

    func setRetentionDays(_ days: Int) {
        queue.sync {
            set(max(1, days), forKey: Keys.retentionDays)
        }
    }

    // MARK: - Private

    private enum Keys {
        static let retentionDays = "retention_days"
    }

    private func set(_ value: Any?, forKey key: String) {
        var dict = readDict()
        if let value {
            dict[key] = value
        } else {
            dict.removeValue(forKey: key)
        }
        writeDict(dict)
    }

    private func integer(forKey key: String) -> Int {
        (readDict()[key] as? Int) ?? 0
    }

    private func readDict() -> [String: Any] {
        guard fileManager.fileExists(atPath: settingsFileURL.path),
              let data = try? Data(contentsOf: settingsFileURL),
              let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
              let dict = plist as? [String: Any]
        else {
            return [:]
        }
        return dict
    }

    private func writeDict(_ dict: [String: Any]) {
        guard let data = try? PropertyListSerialization.data(
            fromPropertyList: dict,
            format: .binary,
            options: 0
        ) else {
            return
        }

        let tmpURL = pluginDirectory.appendingPathComponent("settings.tmp")
        do {
            try data.write(to: tmpURL, options: .atomic)
            if fileManager.fileExists(atPath: settingsFileURL.path) {
                _ = try? fileManager.replaceItemAt(settingsFileURL, withItemAt: tmpURL)
            } else {
                try fileManager.moveItem(at: tmpURL, to: settingsFileURL)
            }
        } catch {
            try? fileManager.removeItem(at: tmpURL)
        }
    }
}
