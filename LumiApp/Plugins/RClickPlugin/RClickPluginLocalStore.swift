import Foundation

/// RClickPlugin 插件本地存储
///
/// 负责持久化插件的配置和设置项。
/// 存储位置：AppConfig.getDBFolderURL()/RClickPlugin/settings.plist
final class RClickPluginLocalStore: @unchecked Sendable {
    
    // MARK: - Singleton
    
    static let shared = RClickPluginLocalStore()
    
    // MARK: - Properties
    
    private let fileManager = FileManager.default
    private let queue = DispatchQueue(label: "RClickPluginLocalStore.queue", qos: .userInitiated)
    private let pluginDirectory: URL
    private let settingsFileURL: URL
    
    // MARK: - Initialization
    
    private init() {
        let root = AppConfig.getDBFolderURL()
            .appendingPathComponent("RClickPlugin", isDirectory: true)
        self.pluginDirectory = root
        self.settingsFileURL = root.appendingPathComponent("settings.plist")
        try? fileManager.createDirectory(at: pluginDirectory, withIntermediateDirectories: true)
    }
    
    // MARK: - Public API
    
    /// 存储值
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
    
    /// 获取值
    func object(forKey key: String) -> Any? {
        queue.sync { readDict()[key] }
    }
    
    /// 获取布尔值
    func bool(forKey key: String) -> Bool {
        (object(forKey: key) as? Bool) ?? false
    }
    
    /// 获取字符串
    func string(forKey key: String) -> String? {
        object(forKey: key) as? String
    }
    
    /// 获取整数
    func integer(forKey key: String) -> Int {
        (object(forKey: key) as? Int) ?? 0
    }
    
    /// 获取双精度浮点数
    func double(forKey key: String) -> Double {
        (object(forKey: key) as? Double) ?? 0.0
    }
    
    /// 获取数据
    func data(forKey key: String) -> Data? {
        object(forKey: key) as? Data
    }
    
    /// 删除指定键
    func remove(forKey key: String) {
        set(nil, forKey: key)
    }
    
    /// 清空所有配置
    func clearAll() {
        queue.sync {
            writeDict([:])
        }
    }
    
    // MARK: - Private Helpers
    
    /// 从文件读取字典
    private func readDict() -> [String: Any] {
        guard fileManager.fileExists(atPath: settingsFileURL.path),
              let data = try? Data(contentsOf: settingsFileURL),
              let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
              let dict = plist as? [String: Any] else {
            return [:]
        }
        return dict
    }
    
    /// 写入字典到文件（原子操作）
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
            // 原子写入临时文件
            try data.write(to: tmpURL, options: .atomic)
            
            // 替换原文件
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
