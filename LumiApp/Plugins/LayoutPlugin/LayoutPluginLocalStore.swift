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

    /// 存储值（异步，不阻塞调用线程）
    func set(_ value: Any?, forKey key: String) {
        queue.async { [self] in
            var dict = self.readDict()
            if let value {
                dict[key] = value
            } else {
                dict.removeValue(forKey: key)
            }
            self.writeDict(dict)
        }
    }

    /// 获取值（同步，需要返回值）
    func object(forKey key: String) -> Any? {
        queue.sync { self.readDict()[key] }
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

    /// 保存分栏布局比例（异步，不阻塞调用线程）
    /// - Parameter ratios: key -> ratio 的字典
    func saveLayoutRatios(_ ratios: [String: Double]) {
        queue.async { [self] in
            var dict = self.readDict()
            dict[Keys.layoutRatios] = ratios
            self.writeDict(dict)
        }
    }

    // MARK: - Editor Bottom Panel Height

    /// 加载已保存的底部面板高度（同步，需要返回值）
    /// - Returns: 高度值，默认返回 nil 表示未保存过
    func loadEditorBottomPanelHeight() -> Double? {
        queue.sync {
            self.readDict()[Keys.editorBottomPanelHeight] as? Double
        }
    }

    /// 保存底部面板高度（异步，不阻塞调用线程）
    /// - Parameter height: 高度值
    func saveEditorBottomPanelHeight(_ height: Double) {
        queue.async { [self] in
            var dict = self.readDict()
            dict[Keys.editorBottomPanelHeight] = height
            self.writeDict(dict)
        }
    }

    // MARK: - Bottom Panel Visibility

    /// 加载已保存的底部面板可见性（同步，需要返回值）
    /// - Returns: 可见性，默认返回 nil 表示未保存过
    func loadBottomPanelVisible() -> Bool? {
        object(forKey: Keys.bottomPanelVisible) as? Bool
    }

    /// 保存底部面板可见性（异步，不阻塞调用线程）
    func saveBottomPanelVisible(_ visible: Bool) {
        set(visible, forKey: Keys.bottomPanelVisible)
    }

    // MARK: - Content Panel Visibility

    /// 加载已保存的内容面板可见性（同步，需要返回值）
    /// - Returns: 可见性，默认返回 nil 表示未保存过
    func loadContentPanelVisible() -> Bool? {
        object(forKey: Keys.contentPanelVisible) as? Bool
    }

    /// 保存内容面板可见性（异步，不阻塞调用线程）
    func saveContentPanelVisible(_ visible: Bool) {
        set(visible, forKey: Keys.contentPanelVisible)
    }

    // MARK: - Editor Visibility

    /// 加载已保存的编辑器区域可见性（同步，需要返回值）
    /// - Returns: 可见性，默认返回 nil 表示未保存过
    func loadEditorVisible() -> Bool? {
        object(forKey: Keys.editorVisible) as? Bool
    }

    /// 保存编辑器区域可见性（异步，不阻塞调用线程）
    func saveEditorVisible(_ visible: Bool) {
        set(visible, forKey: Keys.editorVisible)
    }

    // MARK: - Rail Visibility

    /// 加载已保存的 Rail 区域可见性（同步，需要返回值）
    /// - Returns: 可见性，默认返回 nil 表示未保存过
    func loadRailVisible() -> Bool? {
        object(forKey: Keys.railVisible) as? Bool
    }

    /// 保存 Rail 区域可见性（异步，不阻塞调用线程）
    func saveRailVisible(_ visible: Bool) {
        set(visible, forKey: Keys.railVisible)
    }

    // MARK: - Keys

    private enum Keys {
        static let activePanelIcon = "activePanelIcon"
        static let selectedAgentSidebarTabId = "selectedAgentSidebarTabId"
        static let selectedAgentDetailId = "selectedAgentDetailId"
        static let layoutRatios = "layoutRatios"
        static let editorBottomPanelHeight = "editorBottomPanelHeight"
        static let bottomPanelVisible = "bottomPanelVisible"
        static let contentPanelVisible = "contentPanelVisible"
        static let editorVisible = "editorVisible"
        static let railVisible = "railVisible"
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
