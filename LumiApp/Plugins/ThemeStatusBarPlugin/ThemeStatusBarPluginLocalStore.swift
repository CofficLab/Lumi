import Foundation

/// ThemeStatusBarPlugin 插件本地存储
///
/// 负责持久化用户选择的应用主题。
/// 存储位置：AppConfig.getDBFolderURL()/ThemeStatusBarPlugin/settings.plist
final class ThemeStatusBarPluginLocalStore: @unchecked Sendable {

    // MARK: - Singleton

    static let shared = ThemeStatusBarPluginLocalStore()

    // MARK: - Properties

    private let fileManager = FileManager.default
    private let queue = DispatchQueue(label: "ThemeStatusBarPluginLocalStore.queue", qos: .userInitiated)
    private let settingsFileURL: URL
    private let pluginDirectory: URL

    // MARK: - Initialization

    private init() {
        let pluginDirName = "ThemeStatusBarPlugin"
        let root = AppConfig.getDBFolderURL()
            .appendingPathComponent(pluginDirName, isDirectory: true)
        self.pluginDirectory = root
        self.settingsFileURL = root.appendingPathComponent("settings.plist")
        try? fileManager.createDirectory(at: pluginDirectory, withIntermediateDirectories: true)
    }

    // MARK: - Public API

    /// 加载已保存的主题 ID（同步，需要返回值）
    /// - Returns: 保存的主题 ID，如果没有则返回 nil
    func loadSelectedThemeID() -> String? {
        queue.sync { [self] in
            guard self.fileManager.fileExists(atPath: self.settingsFileURL.path),
                  let data = try? Data(contentsOf: self.settingsFileURL),
                  let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
                  let dict = plist as? [String: Any] else {
                return nil
            }
            return dict[Keys.selectedThemeID] as? String
        }
    }

    /// 保存主题 ID（异步，不阻塞调用线程）
    /// - Parameter themeID: 主题 ID
    func saveSelectedThemeID(_ themeID: String) {
        queue.async { [self] in
            var dict: [String: Any] = [:]
            if self.fileManager.fileExists(atPath: self.settingsFileURL.path),
               let data = try? Data(contentsOf: self.settingsFileURL),
               let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
               let existing = plist as? [String: Any] {
                dict = existing
            }
            dict[Keys.selectedThemeID] = themeID

            guard let newData = try? PropertyListSerialization.data(
                fromPropertyList: dict,
                format: .binary,
                options: 0
            ) else { return }

            let tmpURL = self.pluginDirectory.appendingPathComponent("settings.tmp")

            do {
                // 原子写入临时文件
                try newData.write(to: tmpURL, options: .atomic)

                // 替换原文件
                if self.fileManager.fileExists(atPath: self.settingsFileURL.path) {
                    _ = try? self.fileManager.replaceItemAt(self.settingsFileURL, withItemAt: tmpURL)
                } else {
                    try self.fileManager.moveItem(at: tmpURL, to: self.settingsFileURL)
                }
            } catch {
                try? self.fileManager.removeItem(at: tmpURL)
            }
        }
    }

    // MARK: - Keys

    private enum Keys {
        static let selectedThemeID = "selectedThemeID"
    }
}
