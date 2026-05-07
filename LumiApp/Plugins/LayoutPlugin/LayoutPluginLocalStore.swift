import Foundation

/// LayoutPlugin 插件本地存储
///
/// 负责持久化布局相关的配置数据，包括：
/// - 活动栏选中的图标名称
/// - Agent 模式侧边栏选中的 Tab ID
/// - Agent 模式 Detail 视图 ID
/// - 分栏布局宽度比例（SplitView 各列的比例）
///
/// 存储位置：AppConfig.getDBFolderURL()/LayoutPlugin/settings.plist
final class LayoutPluginLocalStore: @unchecked Sendable {

    // MARK: - Singleton

    static let shared = LayoutPluginLocalStore()

    // MARK: - Properties

    private let fileManager = FileManager.default
    private let queue = DispatchQueue(label: "LayoutPluginLocalStore.queue", qos: .userInitiated)
    private let pluginDirectory: URL
    private let settingsFileURL: URL

    // MARK: - Initialization

    private init() {
        let root = AppConfig.getDBFolderURL()
            .appendingPathComponent("LayoutPlugin", isDirectory: true)
        self.pluginDirectory = root
        self.settingsFileURL = root.appendingPathComponent("settings.plist")
        try? fileManager.createDirectory(at: pluginDirectory, withIntermediateDirectories: true)
    }

    // MARK: - Public API

    /// 存储值
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

    /// 获取值
    func object(forKey key: String) -> Any? {
        queue.sync { readDict()[key] }
    }

    /// 获取字符串
    func string(forKey key: String) -> String? {
        object(forKey: key) as? String
    }

    /// 删除指定键
    func remove(forKey key: String) {
        set(nil, forKey: key)
    }

    // MARK: - Convenience API

    /// 加载已保存的活动栏图标名称
    func loadActivePanelIcon() -> String? {
        string(forKey: Keys.activePanelIcon)
    }

    /// 保存活动栏图标名称
    func saveActivePanelIcon(_ icon: String?) {
        set(icon, forKey: Keys.activePanelIcon)
    }

    /// 加载已保存的侧边栏 Tab ID
    func loadSelectedAgentSidebarTabId() -> String? {
        string(forKey: Keys.selectedAgentSidebarTabId)
    }

    /// 保存侧边栏 Tab ID
    func saveSelectedAgentSidebarTabId(_ id: String?) {
        set(id, forKey: Keys.selectedAgentSidebarTabId)
    }

    /// 加载已保存的 Detail 视图 ID
    func loadSelectedAgentDetailId() -> String? {
        string(forKey: Keys.selectedAgentDetailId)
    }

    /// 保存 Detail 视图 ID
    func saveSelectedAgentDetailId(_ id: String?) {
        set(id, forKey: Keys.selectedAgentDetailId)
    }

    // MARK: - Layout Ratios

    /// 加载已保存的分栏布局比例
    /// - Returns: key -> ratio 的字典
    func loadLayoutRatios() -> [String: Double] {
        queue.sync {
            guard let dict = readDict()[Keys.layoutRatios] as? [String: Any] else {
                return [:]
            }
            return dict.compactMapValues { $0 as? Double }
        }
    }

    /// 保存分栏布局比例
    /// - Parameter ratios: key -> ratio 的字典
    func saveLayoutRatios(_ ratios: [String: Double]) {
        queue.sync {
            var dict = readDict()
            dict[Keys.layoutRatios] = ratios
            writeDict(dict)
        }
    }

    // MARK: - Keys

    private enum Keys {
        static let activePanelIcon = "activePanelIcon"
        static let selectedAgentSidebarTabId = "selectedAgentSidebarTabId"
        static let selectedAgentDetailId = "selectedAgentDetailId"
        static let layoutRatios = "layoutRatios"
    }

    // MARK: - Private Helpers

    /// 从文件读取字典
    private func readDict() -> [String: Any] {
        guard fileManager.fileExists(atPath: settingsFileURL.path),
              let data = try? Data(contentsOf: settingsFileURL),
              let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
              let dict = plist as? [String: Any] else {
            return [:]
        }
        return dict
    }

    /// 写入字典到文件（原子操作）
    private func writeDict(_ dict: [String: Any]) {
        guard let data = try? PropertyListSerialization.data(
            fromPropertyList: dict,
            format: .binary,
            options: 0
        ) else {
            return
        }

        let tmpURL = pluginDirectory.appendingPathComponent("settings.tmp")

        do {
            try data.write(to: tmpURL, options: .atomic)

            if fileManager.fileExists(atPath: settingsFileURL.path) {
                _ = try? fileManager.replaceItemAt(settingsFileURL, withItemAt: tmpURL)
            } else {
                try fileManager.moveItem(at: tmpURL, to: settingsFileURL)
            }
        } catch {
            try? fileManager.removeItem(at: tmpURL)
        }
    }
}
