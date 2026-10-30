import Foundation
import LumiLoggingKit
import os

/// Text Actions 插件本地存储
///
/// 负责持久化插件的配置（当前仅「启用选中文本操作」开关）。
/// 存储位置：由 `onBoot` 注入的 `pluginDataDirectory(for: id)/settings.plist`
final class TextActionsPluginLocalStore: SuperLog, @unchecked Sendable {
    private static let logger = Logger(subsystem: "com.coffic.lumi.plugin.text-actions", category: "TextActions.local-store")

    static let shared = TextActionsPluginLocalStore()

    private enum Key {
        static let enabled = "TextActions.enabled"
    }

    private let fileManager = FileManager.default
    private let queue = DispatchQueue(label: "com.coffic.lumi.plugin.text-actions.store", qos: .userInitiated)
    private let settingsFileURL: URL

    private init() {
        let directory = TextActionsRuntime.settingsDirectory()
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        settingsFileURL = directory.appendingPathComponent("settings.plist")
    }

    /// 测试用：以临时目录构造隔离实例。
    init(settingsDirectory: URL) {
        try? fileManager.createDirectory(at: settingsDirectory, withIntermediateDirectories: true)
        settingsFileURL = settingsDirectory.appendingPathComponent("settings.plist")
    }

    // MARK: - 配置项

    var isEnabled: Bool {
        bool(forKey: Key.enabled)
    }

    func setEnabled(_ enabled: Bool) {
        set(enabled, forKey: Key.enabled)
    }

    // MARK: - 泛型访问

    @discardableResult
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

    func bool(forKey key: String) -> Bool {
        (object(forKey: key) as? Bool) ?? false
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
