import Foundation

/// 已存在的设置文件无法读取或解析。
///
/// 与「配置不存在」严格区分：前者不能静默回退到默认值，否则会按错误的
/// 保留天数提前清理仍然有效的临时文件。
enum AgentTempStorageSettingsError: LocalizedError, Equatable {
    case unreadable(String)

    var errorDescription: String? {
        switch self {
        case .unreadable(let reason):
            "Failed to read temp storage settings: \(reason)"
        }
    }
}

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

    /// 临时文件保留天数（展示用）。
    ///
    /// 读取失败时回退到默认值仅用于文案展示；真正决定删除范围时请使用
    /// `resolvedRetentionDays()`，避免把读取故障当成默认配置。
    var retentionDays: Int {
        get {
            (try? resolvedRetentionDays()) ?? Self.defaultRetentionDays
        }
        set {
            let clamped = max(1, newValue)
            queue.sync {
                var dict = (try? readDict()) ?? [:]
                dict[Key.retentionDays] = clamped
                writeDict(dict)
            }
        }
    }

    /// 临时文件保留天数；配置缺失时使用默认值，配置存在但不可读时抛错。
    func resolvedRetentionDays() throws -> Int {
        try queue.sync {
            let dict = try readDict()
            let value = dict[Key.retentionDays] as? Int ?? 0
            return value > 0 ? value : Self.defaultRetentionDays
        }
    }

    // MARK: - 私有辅助

    private func readDict() throws -> [String: Any] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return [:]
        }
        do {
            let data = try Data(contentsOf: fileURL)
            let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
            if let dict = plist as? [String: Any] {
                return dict
            }
        } catch {
            throw AgentTempStorageSettingsError.unreadable(error.localizedDescription)
        }
        throw AgentTempStorageSettingsError.unreadable("settings.plist is not a dictionary")
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
