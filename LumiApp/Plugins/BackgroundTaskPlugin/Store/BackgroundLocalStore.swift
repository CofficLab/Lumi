import Foundation

final class BackgroundLocalStore: @unchecked Sendable {
    private let fileManager = FileManager.default
    private let queue = DispatchQueue(label: "BackgroundAgentTaskPlugin.LocalStore", qos: .userInitiated)
    private let settingsDirectory: URL
    private let settingsFileURL: URL

    init() {
        let root = AppConfig.getDBFolderURL()
            .appendingPathComponent("BackgroundAgentTaskPlugin", isDirectory: true)
            .appendingPathComponent("settings", isDirectory: true)
        self.settingsDirectory = root
        self.settingsFileURL = root.appendingPathComponent("settings.plist")
        try? fileManager.createDirectory(at: settingsDirectory, withIntermediateDirectories: true)
    }

    func set(_ value: Any?, forKey key: String) {
        queue.sync {
            var dict = readDict()
            if let value { dict[key] = value } else { dict.removeValue(forKey: key) }
            writeDict(dict)
        }
    }

    func string(forKey key: String) -> String? { object(forKey: key) as? String }
    func object(forKey key: String) -> Any? { queue.sync { readDict()[key] } }
    func removeObject(forKey key: String) { set(nil, forKey: key) }

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
}
