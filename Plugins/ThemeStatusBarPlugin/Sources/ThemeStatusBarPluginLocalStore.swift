import Foundation
import LumiCoreKit
import os

/// ThemeStatusBarPlugin 插件本地存储
///
/// 负责持久化用户选择的应用主题。
/// 存储位置：AppConfig.getDBFolderURL()/ThemeStatusBarPlugin/settings.plist
public final class ThemeStatusBarPluginLocalStore: @unchecked Sendable {
    private static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.theme-status-bar.local-store")

    // MARK: - Singleton

    public static let shared = ThemeStatusBarPluginLocalStore()

    // MARK: - Properties

    private let fileManager = FileManager.default
    private let queue = DispatchQueue(label: "ThemeStatusBarPluginLocalStore.queue", qos: .userInitiated)
    private let settingsFileURL: URL
    private let pluginDirectory: URL
    private let corruptSettingsFileURL: URL

    // MARK: - Initialization

    public convenience init() {
        let pluginDirName = "ThemeStatusBarPlugin"
        let root = AppConfig.getDBFolderURL()
            .appendingPathComponent(pluginDirName, isDirectory: true)
        self.init(pluginDirectory: root)
    }

    init(pluginDirectory: URL) {
        self.pluginDirectory = pluginDirectory
        self.settingsFileURL = pluginDirectory.appendingPathComponent("settings.plist")
        self.corruptSettingsFileURL = pluginDirectory.appendingPathComponent("settings.corrupt.plist")

        do {
            try fileManager.createDirectory(at: pluginDirectory, withIntermediateDirectories: true)
        } catch {
            Self.logger.error("Create theme status bar settings directory failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Public API

    /// 加载已保存的主题 ID（同步，需要返回值）
    /// - Returns: 保存的主题 ID，如果没有则返回 nil
    public func loadSelectedThemeID() -> String? {
        queue.sync { readDict()[Keys.selectedThemeID] as? String }
    }

    /// 保存主题 ID
    /// - Parameter themeID: 主题 ID
    @discardableResult
    public func saveSelectedThemeID(_ themeID: String) -> Bool {
        queue.sync { [self] in
            var dict = readDict()
            dict[Keys.selectedThemeID] = themeID
            return writeDict(dict)
        }
    }

    // MARK: - Private Helpers

    private func readDict() -> [String: Any] {
        guard fileManager.fileExists(atPath: settingsFileURL.path) else { return [:] }

        do {
            let data = try Data(contentsOf: settingsFileURL)
            let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
            guard let dict = plist as? [String: Any] else {
                Self.logger.error("Read theme status bar settings failed: root plist is not a dictionary")
                quarantineCorruptSettings()
                return [:]
            }
            return dict
        } catch {
            Self.logger.error("Read theme status bar settings failed: \(error.localizedDescription)")
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
            Self.logger.error("Encode theme status bar settings failed: \(error.localizedDescription)")
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
            Self.logger.error("Persist theme status bar settings failed: \(error.localizedDescription)")
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
            Self.logger.error("Quarantine corrupt theme status bar settings failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Keys

    private enum Keys {
        static let selectedThemeID = "selectedThemeID"
    }
}
