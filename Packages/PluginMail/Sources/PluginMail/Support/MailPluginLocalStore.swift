import Foundation
import os
import LumiLoggingKit

/// PluginMail 插件级本地设置存储。
///
/// 与账户数据（`MailAccountStore`）分离：这里只放 UI 级偏好
/// （如远程图片加载确认、未读角标开关等）。
///
/// ## 存储位置
///
/// 落在插件数据目录的 `preferences.plist`（二进制 plist，原子写 + 损坏隔离），
/// 目录由 `StorageProviding.pluginDataDirectory(for:)` 在 `onBoot` 解析后注入。
///
/// - Note: 早期实现用 `UserDefaults(suiteName:)` 硬编码 suite 名，单元测试
///   无法隔离（会写进测试宿主的真实偏好域）。改为目录注入后，
///   测试传临时目录即可完全隔离。
public final class MailPluginLocalStore: SuperLog, @unchecked Sendable {
    nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi.plugin.mail",
        category: "mail-local-store"
    )

    private static let confirmKey = "confirmBeforeLoadingHTML"
    private static let badgeKey = "unreadBadgeEnabled"

    private let settingsFileURL: URL
    private let fileManager: FileManager
    private let queue: DispatchQueue

    /// 在指定插件数据目录下构造。
    ///
    /// - Parameter directory: 插件数据目录（`<dbRoot>/<pluginID>/`）。
    public init(directory: URL) {
        self.settingsFileURL = directory.appendingPathComponent("preferences.plist", isDirectory: false)
        self.fileManager = .default
        self.queue = DispatchQueue(label: "com.coffic.lumi.plugin.mail.local-store", qos: .userInitiated)
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    // MARK: - 偏好项

    /// 加载 HTML 邮件正文前是否要求用户确认（病毒防护：禁 JS、默认不加载远程图片）。
    public var confirmBeforeLoadingHTML: Bool {
        get { bool(forKey: Self.confirmKey) }
        set { set(newValue, forKey: Self.confirmKey) }
    }

    /// 邮件列表未读角标开关。缺省为「开」。
    public var unreadBadgeEnabled: Bool {
        get {
            object(forKey: Self.badgeKey) == nil ? true : bool(forKey: Self.badgeKey)
        }
        set { set(newValue, forKey: Self.badgeKey) }
    }

    // MARK: - 读写

    public func object(forKey key: String) -> Any? {
        queue.sync { readPlist()[key] }
    }

    public func bool(forKey key: String) -> Bool {
        (object(forKey: key) as? Bool) ?? false
    }

    public func set(_ value: Any?, forKey key: String) {
        queue.sync {
            var plist = readPlist()
            if let value {
                plist[key] = value
            } else {
                plist.removeValue(forKey: key)
            }
            writePlist(plist)
        }
    }

    // MARK: - 私有辅助

    private func readPlist() -> [String: Any] {
        guard fileManager.fileExists(atPath: settingsFileURL.path) else { return [:] }
        do {
            let data = try Data(contentsOf: settingsFileURL)
            let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
            guard let dict = plist as? [String: Any] else {
                Self.logger.error("\(Self.t)preferences.plist 根节点不是字典")
                quarantineCorruptSettings()
                return [:]
            }
            return dict
        } catch {
            Self.logger.error("\(Self.t)读取 preferences.plist 失败: \(error.localizedDescription)")
            quarantineCorruptSettings()
            return [:]
        }
    }

    private func writePlist(_ plist: [String: Any]) {
        let plistData: Data
        do {
            plistData = try PropertyListSerialization.data(
                fromPropertyList: plist,
                format: .binary,
                options: 0
            )
        } catch {
            Self.logger.error("\(Self.t)编码 preferences.plist 失败: \(error.localizedDescription)")
            return
        }

        let parent = settingsFileURL.deletingLastPathComponent()
        let tmp = parent.appendingPathComponent("preferences.tmp", isDirectory: false)
        do {
            try fileManager.createDirectory(at: parent, withIntermediateDirectories: true)
            try plistData.write(to: tmp, options: .atomic)
            if fileManager.fileExists(atPath: settingsFileURL.path) {
                _ = try fileManager.replaceItemAt(settingsFileURL, withItemAt: tmp)
            } else {
                try fileManager.moveItem(at: tmp, to: settingsFileURL)
            }
        } catch {
            Self.logger.error("\(Self.t)持久化 preferences.plist 失败: \(error.localizedDescription)")
            try? fileManager.removeItem(at: tmp)
        }
    }

    private func quarantineCorruptSettings() {
        let corrupt = settingsFileURL.deletingLastPathComponent()
            .appendingPathComponent("preferences.corrupt.plist", isDirectory: false)
        guard fileManager.fileExists(atPath: settingsFileURL.path) else { return }
        try? fileManager.removeItem(at: corrupt)
        try? fileManager.moveItem(at: settingsFileURL, to: corrupt)
    }
}
