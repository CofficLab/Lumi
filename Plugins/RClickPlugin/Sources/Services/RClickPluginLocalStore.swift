import Foundation
import os
import SuperLogKit

/// RClickPlugin 插件本地存储
///
/// 负责持久化插件的配置和设置项。
/// 存储位置：<LumiCore.dataRootDirectory>/RClickPlugin/settings.plist
public final class RClickPluginLocalStore: SuperLog, @unchecked Sendable {
    private static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.rclick.local-store")
    
    // MARK: - Singleton
    
    public static let shared = RClickPluginLocalStore()
    
    // MARK: - Properties
    
    private let fileManager = FileManager.default
    private let queue = DispatchQueue(label: "RClickPluginLocalStore.queue", qos: .userInitiated)
    private let pluginDirectory: URL
    private let settingsFileURL: URL
    private let corruptSettingsFileURL: URL
    
    // MARK: - Initialization
    
    public convenience init() {
        let root = (RClickPluginRuntimeBridge.dataRootDirectory ?? RClickPluginRuntimeBridge.fallbackRootDirectory)
            .appendingPathComponent("RClickPlugin", isDirectory: true)
        self.init(pluginDirectory: root)
    }

    init(pluginDirectory: URL) {
        self.pluginDirectory = pluginDirectory
        self.settingsFileURL = pluginDirectory.appendingPathComponent("settings.plist")
        self.corruptSettingsFileURL = pluginDirectory.appendingPathComponent("settings.corrupt.plist")

        do {
            try fileManager.createDirectory(at: pluginDirectory, withIntermediateDirectories: true)
        } catch {
            Self.logger.error("\(self.t)Create RClick settings directory failed: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Public API

    /// 存储值
    @discardableResult
    public func set(_ value: Any?, forKey key: String) -> Bool {
        queue.sync { [self] in
            var dict = self.readDict()
            if let value {
                dict[key] = value
            } else {
                dict.removeValue(forKey: key)
            }
            return self.writeDict(dict)
        }
    }

    /// 获取值（同步，需要返回值）
    public func object(forKey key: String) -> Any? {
        queue.sync { self.readDict()[key] }
    }

    /// 获取布尔值
    public func bool(forKey key: String) -> Bool {
        (object(forKey: key) as? Bool) ?? false
    }

    /// 获取字符串
    public func string(forKey key: String) -> String? {
        object(forKey: key) as? String
    }

    /// 获取整数
    public func integer(forKey key: String) -> Int {
        (object(forKey: key) as? Int) ?? 0
    }

    /// 获取双精度浮点数
    public func double(forKey key: String) -> Double {
        (object(forKey: key) as? Double) ?? 0.0
    }

    /// 获取数据
    public func data(forKey key: String) -> Data? {
        object(forKey: key) as? Data
    }

    /// 删除指定键
    public func remove(forKey key: String) {
        set(nil, forKey: key)
    }

    /// 清空所有配置
    @discardableResult
    public func clearAll() -> Bool {
        queue.sync { [self] in self.writeDict([:]) }
    }
    
    // MARK: - Private Helpers
    
    /// 从文件读取字典
    private func readDict() -> [String: Any] {
        guard fileManager.fileExists(atPath: settingsFileURL.path) else { return [:] }

        do {
            let data = try Data(contentsOf: settingsFileURL)
            let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
            guard let dict = plist as? [String: Any] else {
                Self.logger.error("\(self.t)Read RClick settings failed: root plist is not a dictionary")
                quarantineCorruptSettings()
                return [:]
            }
            return dict
        } catch {
            Self.logger.error("\(self.t)Read RClick settings failed: \(error.localizedDescription)")
            quarantineCorruptSettings()
            return [:]
        }
    }
    
    /// 写入字典到文件（原子操作）
    @discardableResult
    private func writeDict(_ dict: [String: Any]) -> Bool {
        let data: Data
        do {
            data = try PropertyListSerialization.data(fromPropertyList: dict, format: .binary, options: 0)
        } catch {
            Self.logger.error("\(self.t)Encode RClick settings failed: \(error.localizedDescription)")
            return false
        }
        
        let tmpURL = pluginDirectory.appendingPathComponent("settings.tmp")
        
        do {
            try fileManager.createDirectory(at: pluginDirectory, withIntermediateDirectories: true)

            // 原子写入临时文件
            try data.write(to: tmpURL, options: .atomic)
            
            // 替换原文件
            if fileManager.fileExists(atPath: settingsFileURL.path) {
                _ = try fileManager.replaceItemAt(settingsFileURL, withItemAt: tmpURL)
            } else {
                try fileManager.moveItem(at: tmpURL, to: settingsFileURL)
            }
            return true
        } catch {
            Self.logger.error("\(self.t)Persist RClick settings failed: \(error.localizedDescription)")
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
            Self.logger.error("\(self.t)Quarantine corrupt RClick settings failed: \(error.localizedDescription)")
        }
    }
}
