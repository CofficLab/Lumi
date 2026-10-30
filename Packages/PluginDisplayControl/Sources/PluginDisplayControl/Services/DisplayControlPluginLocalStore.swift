import Foundation
import LumiLoggingKit
import os

/// Display Control 插件本地存储
///
/// 负责持久化各显示器的亮度 / 音量 / 对比度记忆值。
/// 存储位置：由 `onBoot` 注入的 `pluginDataDirectory(for: id)/settings.plist`
///
/// 键名形如 `displayControl.value.<displayStorageID>.<kind>`，随显示器接入动态产生，
/// 因此这里只提供通用读写，不枚举具体键。
final class DisplayControlPluginLocalStore: SuperLog, @unchecked Sendable {
    private static let logger = Logger(subsystem: "com.coffic.lumi.plugin.display-control", category: "DisplayControl.local-store")

    static let shared = DisplayControlPluginLocalStore()

    private let fileManager = FileManager.default
    private let queue = DispatchQueue(label: "com.coffic.lumi.plugin.display-control.store", qos: .userInitiated)
    private let settingsFileURL: URL

    private init() {
        let directory = DisplayControlRuntime.settingsDirectory()
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        settingsFileURL = directory.appendingPathComponent("settings.plist")
    }

    /// 测试用：以临时目录构造隔离实例。
    init(settingsDirectory: URL) {
        try? fileManager.createDirectory(at: settingsDirectory, withIntermediateDirectories: true)
        settingsFileURL = settingsDirectory.appendingPathComponent("settings.plist")
    }

    // MARK: - 泛型访问

    func double(forKey key: String) -> Double? {
        object(forKey: key) as? Double
    }

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

    func removeObject(forKey key: String) {
        set(nil, forKey: key)
    }

    /// 键是否存在。用于区分「未记忆过」与「记忆值为 0」。
    func contains(_ key: String) -> Bool {
        queue.sync { readDict().keys.contains(key) }
    }

    // MARK: - 私有辅助

    private func readDict() -> [String: Any] {
        guard let data = try? Data(contentsOf: settingsFileURL),
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
            Self.logger.error("\(self.t)Encode settings failed")
            return
        }
        do {
            try data.write(to: settingsFileURL, options: .atomic)
        } catch {
            Self.logger.error("\(self.t)Persist settings failed: \(error.localizedDescription)")
        }
    }
}
