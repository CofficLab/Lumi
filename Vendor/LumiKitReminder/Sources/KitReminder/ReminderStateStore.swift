import Foundation

/// 提醒插件的本地状态存储。
///
/// 按 CofficLab 兄弟项目（Lumi）的存储规范实现：
/// - 数据落在插件专属目录下的 `settings.plist`（Binary Plist），
///   而不是 `UserDefaults.standard`；
/// - 目录由宿主的 `StorageProviding` 通过 `pluginDataDirectory(for:)` 分配，
///   各插件互不干扰；
/// - 用串行队列保证并发安全。
///
/// 本类只负责读写，不含业务语义；跨日归零等规则由 `DailyCounter` 负责。
public final class ReminderStateStore: @unchecked Sendable {
    /// 状态文件名（与 Lumi 插件偏好存储一致）。
    public static let fileName = "settings.plist"

    private let queue = DispatchQueue(label: "com.coffic.wakey.reminder.state-store")
    private let fileURL: URL?
    private var memoryStorage: [String: Any] = [:]

    /// - Parameter directory: 插件数据目录（由 `StorageProviding` 分配）。
    public init(directory: URL) {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        fileURL = directory.appendingPathComponent(Self.fileName)
    }

    private init(inMemory: Bool) {
        fileURL = nil
    }

    /// 纯内存存储，不落盘。
    ///
    /// 用于宿主尚未注入 `StorageProviding` 的场景（例如测试进程，
    /// 或插件在 `onBoot` 之前被提前访问）。
    public static func inMemory() -> ReminderStateStore {
        ReminderStateStore(inMemory: true)
    }

    /// 读取一个整数值；键不存在或类型不匹配时返回 nil。
    public func integer(forKey key: String) -> Int? {
        queue.sync { readDict()[key] as? Int }
    }

    /// 写入一个整数值。
    public func setInteger(_ value: Int, forKey key: String) {
        queue.sync {
            var dict = readDict()
            dict[key] = value
            writeDict(dict)
        }
    }

    /// 读取一个布尔值；键不存在或类型不匹配时返回 nil。
    public func bool(forKey key: String) -> Bool? {
        queue.sync { readDict()[key] as? Bool }
    }

    /// 写入一个布尔值。
    public func setBool(_ value: Bool, forKey key: String) {
        queue.sync {
            var dict = readDict()
            dict[key] = value
            writeDict(dict)
        }
    }

    /// 移除一个键。
    public func removeValue(forKey key: String) {
        queue.sync {
            var dict = readDict()
            dict.removeValue(forKey: key)
            writeDict(dict)
        }
    }

    /// 读取全部键值对（只读快照）。
    public func allValues() -> [String: Any] {
        queue.sync { readDict() }
    }

    // MARK: - 私有辅助

    private func readDict() -> [String: Any] {
        guard let fileURL else {
            return memoryStorage
        }
        guard let data = try? Data(contentsOf: fileURL),
              let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
              let dict = plist as? [String: Any]
        else {
            return [:]
        }
        return dict
    }

    private func writeDict(_ dict: [String: Any]) {
        guard let fileURL else {
            memoryStorage = dict
            return
        }
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
