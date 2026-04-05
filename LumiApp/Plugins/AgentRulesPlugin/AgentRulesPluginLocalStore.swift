import Foundation

/// Agent 规则插件本地存储
///
/// 负责管理插件的配置持久化
final class AgentRulesPluginLocalStore: @unchecked Sendable {
    static let shared = AgentRulesPluginLocalStore()

    private let fileManager = FileManager.default
    private let queue = DispatchQueue(label: "com.coffic.lumi.agent-rules.store", qos: .userInitiated)
    private let settingsDirectory: URL
    private let settingsFileURL: URL

    // MARK: - 配置键

    enum Key: String {
        case rulesDirectoryPath
        case defaultSortOrder
        case showFileSizes
        case lastSyncTime
    }

    // MARK: - 初始化

    private init() {
        // 获取应用支持目录
        let applicationSupportURL = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? fileManager.homeDirectoryForCurrentUser

        let lumiDirectory = applicationSupportURL.appending(path: "Lumi")
        let settingsDir = lumiDirectory.appending(path: "PluginSettings")

        // 确保目录存在
        try? fileManager.createDirectory(at: settingsDir, withIntermediateDirectories: true)

        self.settingsDirectory = settingsDir
        self.settingsFileURL = settingsDir.appending(path: "AgentRules.plist")
    }

    // MARK: - 公共 API

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

    func object(forKey key: String) -> Any? {
        queue.sync { readDict()[key] }
    }

    func string(forKey key: String) -> String? {
        object(forKey: key) as? String
    }

    func bool(forKey key: String) -> Bool {
        (object(forKey: key) as? Bool) ?? false
    }

    func integer(forKey key: String) -> Int {
        (object(forKey: key) as? Int) ?? 0
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
        let tmp = settingsDirectory.appending(path: "AgentRules.tmp")
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
