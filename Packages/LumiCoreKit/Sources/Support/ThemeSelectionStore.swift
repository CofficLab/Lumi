import Foundation
import os

/// Stores the selected app theme in the same location used by the theme status bar plugin.
public final class ThemeSelectionStore: @unchecked Sendable {
    private static let logger = Logger(subsystem: "com.coffic.lumi", category: "theme-selection-store")

    public static let shared = ThemeSelectionStore()

    private let fileManager = FileManager.default
    private let queue = DispatchQueue(label: "ThemeSelectionStore.queue", qos: .userInitiated)
    private let settingsFileURL: URL
    private let pluginDirectory: URL
    private let corruptSettingsFileURL: URL

    public convenience init() {
        let root = AppConfig.getDBFolderURL()
            .appendingPathComponent("ThemeStatusBarPlugin", isDirectory: true)
        self.init(pluginDirectory: root)
    }

    public init(pluginDirectory: URL) {
        self.pluginDirectory = pluginDirectory
        self.settingsFileURL = pluginDirectory.appendingPathComponent("settings.plist")
        self.corruptSettingsFileURL = pluginDirectory.appendingPathComponent("settings.corrupt.plist")

        do {
            try fileManager.createDirectory(at: pluginDirectory, withIntermediateDirectories: true)
        } catch {
            Self.logger.error("Create theme settings directory failed: \(error.localizedDescription)")
        }
    }

    public func loadSelectedThemeID() -> String? {
        queue.sync { readDict()[Keys.selectedThemeID] as? String }
    }

    @discardableResult
    public func saveSelectedThemeID(_ themeID: String) -> Bool {
        queue.sync { [self] in
            var dict = readDict()
            dict[Keys.selectedThemeID] = themeID
            return writeDict(dict)
        }
    }

    private func readDict() -> [String: Any] {
        guard fileManager.fileExists(atPath: settingsFileURL.path) else { return [:] }

        do {
            let data = try Data(contentsOf: settingsFileURL)
            let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
            guard let dict = plist as? [String: Any] else {
                Self.logger.error("Read theme settings failed: root plist is not a dictionary")
                quarantineCorruptSettings()
                return [:]
            }
            return dict
        } catch {
            Self.logger.error("Read theme settings failed: \(error.localizedDescription)")
            quarantineCorruptSettings()
            return [:]
        }
    }

    @discardableResult
    private func writeDict(_ dict: [String: Any]) -> Bool {
        let data: Data
        do {
            data = try PropertyListSerialization.data(fromPropertyList: dict, format: .binary, options: 0)
        } catch {
            Self.logger.error("Encode theme settings failed: \(error.localizedDescription)")
            return false
        }

        let tmpURL = pluginDirectory.appendingPathComponent("settings.tmp")
        do {
            try fileManager.createDirectory(at: pluginDirectory, withIntermediateDirectories: true)
            try data.write(to: tmpURL, options: .atomic)
            if fileManager.fileExists(atPath: settingsFileURL.path) {
                _ = try fileManager.replaceItemAt(settingsFileURL, withItemAt: tmpURL)
            } else {
                try fileManager.moveItem(at: tmpURL, to: settingsFileURL)
            }
            return true
        } catch {
            Self.logger.error("Persist theme settings failed: \(error.localizedDescription)")
            try? fileManager.removeItem(at: tmpURL)
            return false
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
            Self.logger.error("Quarantine corrupt theme settings failed: \(error.localizedDescription)")
        }
    }

    private enum Keys {
        static let selectedThemeID = "selectedThemeID"
    }
}
