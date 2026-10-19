import Foundation

/// AgentTempStoragePlugin 本地存储配置
///
/// 落盘在插件专属目录（Binary Plist），不再使用 UserDefaults。
final class AgentTempStoragePluginLocalStore: @unchecked Sendable {
    static let shared = AgentTempStoragePluginLocalStore()

    private enum Key {
        static let retentionDays = "AgentTempStorage.retentionDays"
    }

    private static let defaultRetentionDays = 7

    private let queue = DispatchQueue(label: "com.coffic.lumi.plugin.agent-temp-storage.store", qos: .userInitiated)
    private let fileURL: URL

    private init() {
        let directory = AgentTempStoragePluginRuntimeBridge.resolvedPluginDirectory
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        fileURL = directory.appendingPathComponent("settings.plist")
    }

    /// 测试用：以临时目录构造隔离实例。
    init(settingsDirectory: URL) {
        try? FileManager.default.createDirectory(at: settingsDirectory, withIntermediateDirectories: true)
        fileURL = settingsDirectory.appendingPathComponent("settings.plist")
    }

    /// 临时文件保留天数
    var retentionDays: Int {
        get {
            let value = queue.sync { readDict()[Key.retentionDays] as? Int ?? 0 }
            return value > 0 ? value : Self.defaultRetentionDays
        }
        set {
            let clamped = max(1, newValue)
            queue.sync {
                var dict = readDict()
                dict[Key.retentionDays] = clamped
                writeDict(dict)
            }
        }
    }

    // MARK: - 私有辅助

    private func readDict() -> [String: Any] {
        guard let data = try? Data(contentsOf: fileURL),
              let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
              let dict = plist as? [String: Any]
        else {
            return [:]
        }
        return dict
    }

    private func writeDict(_ dict: [String: Any]) {
        guard let data = try? PropertyListSerialization.data(
            fromPropertyList: dict,
            format: .binary,
            options: 0
        ) else {
            return
        }
        try? data.write(to: fileURL, options: .atomic)
    }
}
