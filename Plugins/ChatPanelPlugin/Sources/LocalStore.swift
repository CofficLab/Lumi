import Foundation

/// 本地存储
///
/// 存储位置：ConversationListContext.databaseDirectory()/ChatPanelPlugin/settings.plist
final class LocalStore: @unchecked Sendable {
    private enum Keys {
        static let conversationListWidth = "conversation_list_width"
    }

    private let fileManager = FileManager.default
    private let queue = DispatchQueue(label: "ChatPanel.LocalStore.queue", qos: .userInitiated)
    private let pluginDirectory: URL
    private let settingsFileURL: URL
    private let corruptSettingsFileURL: URL

    convenience init(databaseDirectory: URL) {
        self.init(settingsDirectory: databaseDirectory.appendingPathComponent("ChatPanelPlugin", isDirectory: true))
    }

    init(settingsDirectory: URL) {
        self.pluginDirectory = settingsDirectory
        self.settingsFileURL = settingsDirectory.appendingPathComponent("settings.plist")
        self.corruptSettingsFileURL = settingsDirectory.appendingPathComponent("settings.corrupt.plist")
        try? fileManager.createDirectory(at: pluginDirectory, withIntermediateDirectories: true)
    }

    func loadConversationListWidth() -> Double {
        double(forKey: Keys.conversationListWidth)
    }

    func saveConversationListWidth(_ width: Double) {
        set(width, forKey: Keys.conversationListWidth)
    }

    func set(_ value: Any?, forKey key: String) {
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

    func double(forKey key: String) -> Double {
        (object(forKey: key) as? Double) ?? 0.0
    }

    func object(forKey key: String) -> Any? {
        queue.sync { readDict()[key] }
    }

    private func readDict() -> [String: Any] {
        guard fileManager.fileExists(atPath: settingsFileURL.path) else {
            return [:]
        }

        do {
            let data = try Data(contentsOf: settingsFileURL)
            let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
            guard let dict = plist as? [String: Any] else {
                quarantineCorruptSettings()
                return [:]
            }
            return dict
        } catch {
            quarantineCorruptSettings()
            return [:]
        }
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

    private func quarantineCorruptSettings() {
        guard fileManager.fileExists(atPath: settingsFileURL.path) else { return }

        do {
            if fileManager.fileExists(atPath: corruptSettingsFileURL.path) {
                try fileManager.removeItem(at: corruptSettingsFileURL)
            }
            try fileManager.moveItem(at: settingsFileURL, to: corruptSettingsFileURL)
        } catch {
            try? fileManager.removeItem(at: settingsFileURL)
        }
    }
}
