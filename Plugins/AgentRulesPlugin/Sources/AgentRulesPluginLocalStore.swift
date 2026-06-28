import Foundation
import os
import SuperLogKit

/// Agent 规则插件本地存储
///
/// 负责管理插件的配置持久化
public final class AgentRulesPluginLocalStore: SuperLog, @unchecked Sendable {
    private static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.agent-rules.local-store")

    public static let shared = AgentRulesPluginLocalStore()

    private let fileManager = FileManager.default
    private let queue = DispatchQueue(label: "com.coffic.lumi.agent-rules.store", qos: .userInitiated)
    private let settingsDirectory: URL
    private let settingsFileURL: URL
    private let corruptSettingsFileURL: URL

    // MARK: - 配置键

    enum Key: String {
        case rulesDirectoryPath
        case defaultSortOrder
        case showFileSizes
        case lastSyncTime
    }

    // MARK: - 初始化

    public convenience init() {
        // 获取应用支持目录
        let applicationSupportURL = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.homeDirectoryForCurrentUser

        let lumiDirectory = applicationSupportURL.appending(path: "Lumi")
        let settingsDir = lumiDirectory.appending(path: "PluginSettings")

        self.init(settingsDirectory: settingsDir)
    }

    init(settingsDirectory settingsDir: URL) {
        self.settingsDirectory = settingsDir
        self.settingsFileURL = settingsDir.appending(path: "AgentRules.plist")
        self.corruptSettingsFileURL = settingsDir.appending(path: "AgentRules.corrupt.plist")

        do {
            try fileManager.createDirectory(at: settingsDir, withIntermediateDirectories: true)
        } catch {
            Self.logger.error("\(self.t)Create Agent Rules settings directory failed: \(error.localizedDescription)")
        }
    }

    // MARK: - 公共 API

    @discardableResult
    public func set(_ value: Any?, forKey key: String) -> Bool {
        queue.sync {
            var dict = readDict()
            if let value {
                dict[key] = value
            } else {
                dict.removeValue(forKey: key)
            }
            return writeDict(dict)
        }
    }

    public func object(forKey key: String) -> Any? {
        queue.sync { readDict()[key] }
    }

    public func string(forKey key: String) -> String? {
        object(forKey: key) as? String
    }

    public func bool(forKey key: String) -> Bool {
        (object(forKey: key) as? Bool) ?? false
    }

    public func integer(forKey key: String) -> Int {
        (object(forKey: key) as? Int) ?? 0
    }

    // MARK: - 私有辅助方法

    private func readDict() -> [String: Any] {
        guard fileManager.fileExists(atPath: settingsFileURL.path) else { return [:] }

        do {
            let data = try Data(contentsOf: settingsFileURL)
            let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
            guard let dict = plist as? [String: Any] else {
                Self.logger.error("\(self.t)Read Agent Rules settings failed: root plist is not a dictionary")
                quarantineCorruptSettings()
                return [:]
            }
            return dict
        } catch {
            Self.logger.error("\(self.t)Read Agent Rules settings failed: \(error.localizedDescription)")
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
            Self.logger.error("\(self.t)Encode Agent Rules settings failed: \(error.localizedDescription)")
            return false
        }

        let tmp = settingsDirectory.appending(path: "AgentRules.tmp")
        do {
            try fileManager.createDirectory(at: settingsDirectory, withIntermediateDirectories: true)
            try data.write(to: tmp, options: .atomic)
            if fileManager.fileExists(atPath: settingsFileURL.path) {
                _ = try fileManager.replaceItemAt(settingsFileURL, withItemAt: tmp)
            } else {
                try fileManager.moveItem(at: tmp, to: settingsFileURL)
            }
            return true
        } catch {
            Self.logger.error("\(self.t)Persist Agent Rules settings failed: \(error.localizedDescription)")
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
            Self.logger.error("\(self.t)Quarantine corrupt Agent Rules settings failed: \(error.localizedDescription)")
        }
    }
}
