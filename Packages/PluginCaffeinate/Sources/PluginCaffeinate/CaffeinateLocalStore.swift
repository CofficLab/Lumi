import Foundation
import os
import ProviderStorage
import KitSuperLog

/// Caffeinate 插件本地存储
///
/// 负责持久化 Caffeinate 插件的用户配置（默认启动模式等）。
/// 存储位置：kernel.storage.pluginDataDirectory(for: "Caffeinate")/settings.plist
@MainActor
public final class CaffeinateLocalStore: SuperLog, @unchecked Sendable {
    private static let logger = Logger(
        subsystem: "com.coffic.lumi",
        category: "plugin.caffeinate.local-store"
    )

    // MARK: - Singleton

    public static let shared = CaffeinateLocalStore()

    // MARK: - Properties

    private let fileManager = FileManager.default
    private let queue = DispatchQueue(label: "CaffeinateLocalStore.queue", qos: .userInitiated)
    private var settingsDirectory: URL?
    private var settingsFileURL: URL?
    private var corruptSettingsFileURL: URL?

    /// 是否已经绑定到 kernel 的存储目录（`configure(kernel:)` 调用后为 true）。
    private(set) var isConfigured = false

    // MARK: - Initialization

    public convenience init() {
        self.init(settingsDirectory: nil)
    }

    init(settingsDirectory root: URL?) {
        if let root {
            self.settingsDirectory = root
            self.settingsFileURL = root.appendingPathComponent("settings.plist")
            self.corruptSettingsFileURL = root.appendingPathComponent("settings.corrupt.plist")
            do {
                try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
            } catch {
                Self.logger.error("\(self.t)Create caffeinate settings directory failed: \(error.localizedDescription)")
            }
            self.isConfigured = true
        }
    }

    // MARK: - Configuration

    /// 使用内核提供的存储目录完成懒加载。
    ///
    /// 必须在第一次写入/读取前调用一次。可以重复调用以更换目录（仅用于测试）。
    func configure(storage: (any StorageProviding)?) {
        guard let storage else {
            Self.logger.error("\(self.t)storage is nil; caffeinate local store stays unconfigured")
            return
        }
        let root = storage.pluginDataDirectory(for: "Caffeinate")
            .appendingPathComponent("settings", isDirectory: true)
        do {
            try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
        } catch {
            Self.logger.error("\(self.t)Create caffeinate settings directory failed: \(error.localizedDescription)")
        }
        self.settingsDirectory = root
        self.settingsFileURL = root.appendingPathComponent("settings.plist")
        self.corruptSettingsFileURL = root.appendingPathComponent("settings.corrupt.plist")
        self.isConfigured = true
    }

    // MARK: - Public API

    /// 默认启动模式（`SleepMode` 字符串）。未配置时返回 `nil`。
    var defaultModeRaw: String? {
        string(forKey: Keys.defaultMode)
    }

    /// 设置默认启动模式（持久化）。传 `nil` 表示清除。
    @discardableResult
    func setDefaultModeRaw(_ value: String?) -> Bool {
        set(value, forKey: Keys.defaultMode)
    }

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

    // MARK: - Private Helpers

    private func readDict() -> [String: Any] {
        guard let settingsFileURL else { return [:] }
        guard fileManager.fileExists(atPath: settingsFileURL.path) else { return [:] }
        do {
            let data = try Data(contentsOf: settingsFileURL)
            let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
            guard let dict = plist as? [String: Any] else {
                Self.logger.error("\(self.t)Read caffeinate settings failed: root plist is not a dictionary")
                quarantineCorruptSettings()
                return [:]
            }
            return dict
        } catch {
            Self.logger.error("\(self.t)Read caffeinate settings failed: \(error.localizedDescription)")
            quarantineCorruptSettings()
            return [:]
        }
    }

    @discardableResult
    private func writeDict(_ dict: [String: Any]) -> Bool {
        guard let settingsDirectory, let settingsFileURL else {
            // 未配置：写入操作静默失败并记录日志。
            Self.logger.error("\(self.t)Persist caffeinate settings skipped: store not configured")
            return false
        }
        let data: Data
        do {
            data = try PropertyListSerialization.data(fromPropertyList: dict, format: .binary, options: 0)
        } catch {
            Self.logger.error("\(self.t)Encode caffeinate settings failed: \(error.localizedDescription)")
            return false
        }

        let tmp = settingsDirectory.appendingPathComponent("settings.tmp")
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
            Self.logger.error("\(self.t)Persist caffeinate settings failed: \(error.localizedDescription)")
            try? fileManager.removeItem(at: tmp)
            return false
        }
    }

    private func quarantineCorruptSettings() {
        guard let settingsFileURL, let corruptSettingsFileURL,
              fileManager.fileExists(atPath: settingsFileURL.path) else {
            return
        }
        do {
            if fileManager.fileExists(atPath: corruptSettingsFileURL.path) {
                try fileManager.removeItem(at: corruptSettingsFileURL)
            }
            try fileManager.moveItem(at: settingsFileURL, to: corruptSettingsFileURL)
        } catch {
            Self.logger.error("\(self.t)Quarantine corrupt caffeinate settings failed: \(error.localizedDescription)")
        }
    }
}

// MARK: - Storage Keys

extension CaffeinateLocalStore {
    enum Keys {
        static let defaultMode = "defaultMode"
    }
}