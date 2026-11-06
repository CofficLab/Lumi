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

    /// 划词功能是否启用。
    ///
    /// - Important: **缺省为 true**。这个开关控制的划词功能，其失效方式是
    ///   **完全静默**的——不弹菜单、不报错、不留任何痕迹。若缺省关闭，
    ///   新装用户会得到一个「装上却像没装」的功能，且没有任何线索指向
    ///   「去设置里把它打开」。
    ///
    ///   只有用户**显式**关掉它（写入 `false`）时才关闭。
    ///   注意这与 `bool(forKey:)` 的通用语义（缺省 false）相反，
    ///   因此这里不复用通用读取，而是单独处理「键不存在」这一情形。
    var isEnabled: Bool {
        guard let value = object(forKey: Key.enabled) else { return true }
        return (value as? Bool) ?? true
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
