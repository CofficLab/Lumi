import Foundation
import os
import SuperLogKit

/// Memory Plugin 本地存储
///
/// 负责管理插件的配置持久化。
public final class MemoryPluginLocalStore: SuperLog, @unchecked Sendable {
    public static let shared = MemoryPluginLocalStore()

    private static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.memory.local-store")
    private let fileManager = FileManager.default
    private let queue = DispatchQueue(label: "com.coffic.lumi.memory.store", qos: .userInitiated)
    private let settingsDirectory: URL
    private let settingsFileURL: URL
    private let corruptSettingsFileURL: URL

    // MARK: - 配置键

    public enum Key: String {
        case enabled                // 插件启用/禁用（由框架自动管理）
        case verboseLogging         // 详细日志
        case maxRelevantMemories    // 每轮对话注入的最大相关记忆数
        case staleThresholdDays     // 记忆过期阈值（天）
        case halfLifeDays           // 时效衰减半衰期（天）
        case injectGlobalIndex      // 是否注入全局索引
        case injectProjectIndex     // 是否注入项目索引
        case autoSaveOnContextSwitch // 项目切换时自动保存上下文记忆
    }

    // MARK: - 初始化

    private convenience init() {
        let fileManager = FileManager.default
        let applicationSupportURL = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? fileManager.homeDirectoryForCurrentUser

        let lumiDirectory = applicationSupportURL.appending(path: "Lumi")
        let settingsDir = lumiDirectory.appending(path: "PluginSettings")
        self.init(settingsDirectory: settingsDir)
    }

    init(settingsDirectory: URL) {
        self.settingsDirectory = settingsDirectory
        self.settingsFileURL = settingsDirectory.appending(path: "Memory.plist")
        self.corruptSettingsFileURL = settingsDirectory.appending(path: "Memory.corrupt.plist")
        do {
            try fileManager.createDirectory(at: settingsDirectory, withIntermediateDirectories: true)
        } catch {
            Self.logger.error("\(self.t)Create memory settings directory failed: \(error.localizedDescription)")
        }
    }

    // MARK: - 公共 API

    @discardableResult
    public func set(_ value: Any?, forKey key: Key) -> Bool {
        queue.sync {
            guard var dict = readDict() else {
                return false
            }
            if let value {
                dict[key.rawValue] = value
            } else {
                dict.removeValue(forKey: key.rawValue)
            }
            return writeDict(dict)
        }
    }

    public func object(forKey key: Key) -> Any? {
        queue.sync { readDict()?[key.rawValue] }
    }

    public func bool(forKey key: Key, defaultValue: Bool = false) -> Bool {
        (object(forKey: key) as? Bool) ?? defaultValue
    }

    public func integer(forKey key: Key, defaultValue: Int = 0) -> Int {
        (object(forKey: key) as? Int) ?? defaultValue
    }

    public func double(forKey key: Key, defaultValue: Double = 0) -> Double {
        (object(forKey: key) as? Double) ?? defaultValue
    }

    public func string(forKey key: Key) -> String? {
        object(forKey: key) as? String
    }

    // MARK: - 便捷访问

    public var isVerbose: Bool {
        bool(forKey: .verboseLogging, defaultValue: false)
    }

    public var maxRelevantMemories: Int {
        integer(forKey: .maxRelevantMemories, defaultValue: 3)
    }

    public var staleThresholdDays: Int {
        integer(forKey: .staleThresholdDays, defaultValue: 7)
    }

    public var halfLifeDays: Double {
        double(forKey: .halfLifeDays, defaultValue: 30)
    }

    public var shouldInjectGlobalIndex: Bool {
        bool(forKey: .injectGlobalIndex, defaultValue: true)
    }

    public var shouldInjectProjectIndex: Bool {
        bool(forKey: .injectProjectIndex, defaultValue: true)
    }

    public var autoSaveOnContextSwitch: Bool {
        bool(forKey: .autoSaveOnContextSwitch, defaultValue: false)
    }

    // MARK: - 私有辅助方法

    private func readDict() -> [String: Any]? {
        guard fileManager.fileExists(atPath: settingsFileURL.path) else {
            return [:]
        }

        do {
            let data = try Data(contentsOf: settingsFileURL)
            let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
            guard let dict = plist as? [String: Any] else {
                Self.logger.error("\(self.t)Read memory settings failed: root plist is not a dictionary")
                quarantineCorruptSettings()
                return [:]
            }
            return dict
        } catch {
            Self.logger.error("\(self.t)Read memory settings failed: \(error.localizedDescription)")
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
            Self.logger.error("\(self.t)Encode memory settings failed: \(error.localizedDescription)")
            return false
        }

        let tmp = settingsDirectory.appending(path: "Memory.tmp")
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
            Self.logger.error("\(self.t)Persist memory settings failed: \(error.localizedDescription)")
            try? fileManager.removeItem(at: tmp)
            return false
        }
    }

    private func quarantineCorruptSettings() {
        do {
            if fileManager.fileExists(atPath: corruptSettingsFileURL.path) {
                try fileManager.removeItem(at: corruptSettingsFileURL)
            }
            try fileManager.moveItem(at: settingsFileURL, to: corruptSettingsFileURL)
        } catch {
            Self.logger.error("\(self.t)Quarantine corrupt memory settings failed: \(error.localizedDescription)")
        }
    }
}
