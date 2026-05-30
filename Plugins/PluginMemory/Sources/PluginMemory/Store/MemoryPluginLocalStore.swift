import Foundation

/// Memory Plugin 本地存储
///
/// 负责管理插件的配置持久化。
public final class MemoryPluginLocalStore: @unchecked Sendable {
    public static let shared = MemoryPluginLocalStore()

    private let fileManager = FileManager.default
    private let queue = DispatchQueue(label: "com.coffic.lumi.memory.store", qos: .userInitiated)
    private let settingsDirectory: URL
    private let settingsFileURL: URL

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

    private init() {
        let applicationSupportURL = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? fileManager.homeDirectoryForCurrentUser

        let lumiDirectory = applicationSupportURL.appending(path: "Lumi")
        let settingsDir = lumiDirectory.appending(path: "PluginSettings")

        try? fileManager.createDirectory(at: settingsDir, withIntermediateDirectories: true)

        self.settingsDirectory = settingsDir
        self.settingsFileURL = settingsDir.appending(path: "Memory.plist")
    }

    // MARK: - 公共 API

    public func set(_ value: Any?, forKey key: Key) {
        queue.sync {
            var dict = readDict()
            if let value {
                dict[key.rawValue] = value
            } else {
                dict.removeValue(forKey: key.rawValue)
            }
            writeDict(dict)
        }
    }

    public func object(forKey key: Key) -> Any? {
        queue.sync { readDict()[key.rawValue] }
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

    private func readDict() -> [String: Any] {
        guard fileManager.fileExists(atPath: settingsFileURL.path),
              let data = try? Data(contentsOf: settingsFileURL),
              let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
              let dict = plist as? [String: Any] else {
            return [:]
        }
        return dict
    }

    private func writeDict(_ dict: [String: Any]) {
        guard let data = try? PropertyListSerialization.data(fromPropertyList: dict, format: .binary, options: 0) else {
            return
        }
        let tmp = settingsDirectory.appending(path: "Memory.tmp")
        do {
            try data.write(to: tmp, options: .atomic)
            if fileManager.fileExists(atPath: settingsFileURL.path) {
                _ = try? fileManager.replaceItemAt(settingsFileURL, withItemAt: tmp)
            } else {
                try fileManager.moveItem(at: tmp, to: settingsFileURL)
            }
        } catch {
            try? fileManager.removeItem(at: tmp)
        }
    }
}
