import Foundation
import os
import LumiLoggingKit
public final class InputPluginLocalStore: SuperLog, @unchecked Sendable {
    private static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.input.local-store")
    private let fileManager = FileManager.default
    private let queue = DispatchQueue(label: "InputPluginLocalStore.queue", qos: .userInitiated)
    private let pluginDirectory: URL
    private let settingsFileURL: URL
    private let corruptSettingsFileURL: URL
    private let legacySettingsFileURL: URL

    public convenience init() {
        self.init(pluginDirectory: InputPluginRuntimeBridge.resolvedPluginDirectory)
    }

    init(pluginDirectory root: URL) {
        self.pluginDirectory = root
        self.settingsFileURL = root.appendingPathComponent("settings.plist")
        self.corruptSettingsFileURL = root.appendingPathComponent("settings.corrupt.plist")
        self.legacySettingsFileURL = root.appendingPathComponent("settings/settings.plist")
        do {
            try fileManager.createDirectory(at: pluginDirectory, withIntermediateDirectories: true)
        } catch {
            Self.logger.error("\(self.t)Create input plugin settings directory failed: \(error.localizedDescription)")
        }
        migrateLegacyNestedSettingsIfNeeded()
    }

    /// 把旧版本嵌套的 `settings/settings.plist` 前移到当前读取位置。
    ///
    /// 历史提交把读写路径从 `settings/settings.plist` 改成根目录的 `settings.plist`，
    /// 但通用插件数据迁移只原样拷贝目录、不会扁平化嵌套文件，导致升级后旧规则与
    /// 偏好被静默丢弃（issue #784）。仅在根文件不存在且旧文件存在时迁移一次；
    /// 拷贝成功后才清理旧文件，失败时保留旧文件以免数据丢失。
    private func migrateLegacyNestedSettingsIfNeeded() {
        guard !fileManager.fileExists(atPath: settingsFileURL.path),
              fileManager.fileExists(atPath: legacySettingsFileURL.path) else { return }
        do {
            try fileManager.copyItem(at: legacySettingsFileURL, to: settingsFileURL)
            try? fileManager.removeItem(at: legacySettingsFileURL)
            let legacyDirectory = legacySettingsFileURL.deletingLastPathComponent()
            if let contents = try? fileManager.contentsOfDirectory(atPath: legacyDirectory.path),
               contents.isEmpty {
                try? fileManager.removeItem(at: legacyDirectory)
            }
        } catch {
            Self.logger.error("\(self.t)Migrate legacy nested input settings failed: \(error.localizedDescription)")
        }
    }

    @discardableResult
    public func set(_ value: Any?, forKey key: String) -> Bool {
        queue.sync {
            guard var dict = readDict() else {
                return false
            }
            if let value { dict[key] = value } else { dict.removeValue(forKey: key) }
            return writeDict(dict)
        }
    }

    public func data(forKey key: String) -> Data? { object(forKey: key) as? Data }
    public func object(forKey key: String) -> Any? { queue.sync { readDict()?[key] } }

    private func readDict() -> [String: Any]? {
        guard fileManager.fileExists(atPath: settingsFileURL.path) else { return [:] }
        do {
            let data = try Data(contentsOf: settingsFileURL)
            let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
            guard let dict = plist as? [String: Any] else {
                Self.logger.error("\(self.t)Read input plugin settings failed: root plist is not a dictionary")
                quarantineCorruptSettings()
                return [:]
            }
            return dict
        } catch {
            Self.logger.error("\(self.t)Read input plugin settings failed: \(error.localizedDescription)")
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
            Self.logger.error("\(self.t)Encode input plugin settings failed: \(error.localizedDescription)")
            return false
        }

        let tmp = pluginDirectory.appendingPathComponent("settings.tmp")
        do {
            try fileManager.createDirectory(at: pluginDirectory, withIntermediateDirectories: true)
            try data.write(to: tmp, options: .atomic)
            if fileManager.fileExists(atPath: settingsFileURL.path) { _ = try fileManager.replaceItemAt(settingsFileURL, withItemAt: tmp) }
            else { try fileManager.moveItem(at: tmp, to: settingsFileURL) }
            return true
        } catch {
            Self.logger.error("\(self.t)Persist input plugin settings failed: \(error.localizedDescription)")
            try? fileManager.removeItem(at: tmp)
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
            Self.logger.error("\(self.t)Quarantine corrupt input plugin settings failed: \(error.localizedDescription)")
        }
    }

}
