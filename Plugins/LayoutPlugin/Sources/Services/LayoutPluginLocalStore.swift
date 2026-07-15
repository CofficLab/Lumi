import Foundation
import LumiCoreKit

/// LayoutPlugin 插件本地存储
///
/// 负责持久化布局相关的配置数据，包括：
/// - 活动栏选中的图标名称
/// - Agent 模式侧边栏选中的 Tab ID
/// - Agent 模式 Detail 视图 ID
/// - 分栏布局宽度比例（SplitView 各列的比例）
///
/// 存储位置：<LumiCore.dataRootDirectory>/LayoutPlugin/settings.plist
public final class LayoutPluginLocalStore: @unchecked Sendable {

    // MARK: - Singleton

    public static let shared = LayoutPluginLocalStore()

    // MARK: - Properties

    private let fileManager = FileManager.default
    private let queue = DispatchQueue(label: "LayoutPluginLocalStore.queue", qos: .userInitiated)
    private let pluginDirectory: URL
    private let settingsFileURL: URL
    private let corruptSettingsFileURL: URL

    // MARK: - Initialization

    convenience private init() {
        let root = (currentLumiCoreDataRootDirectory ?? lumiCoreFallbackDataRootDirectory)
            .appendingPathComponent("LayoutPlugin", isDirectory: true)
        self.init(pluginDirectory: root)
    }

    init(pluginDirectory: URL) {
        self.pluginDirectory = pluginDirectory
        self.settingsFileURL = pluginDirectory.appendingPathComponent("settings.plist")
        self.corruptSettingsFileURL = pluginDirectory.appendingPathComponent("settings.corrupt.plist")
        try? fileManager.createDirectory(at: pluginDirectory, withIntermediateDirectories: true)
    }

    // MARK: - Public API

    /// 存储值（异步，不阻塞调用线程）
    public func set(_ value: Any?, forKey key: String) {
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
    public func object(forKey key: String) -> Any? {
        queue.sync { self.readDict()[key] }
    }

    /// 获取字符串
    public func string(forKey key: String) -> String? {
        object(forKey: key) as? String
    }

    /// 删除指定键
    public func remove(forKey key: String) {
        set(nil, forKey: key)
    }

    // MARK: - Convenience API

    /// 加载已保存的视图容器图标名称
    public func loadActiveViewContainerIcon() -> String? {
        string(forKey: LayoutStorageKey.activeViewContainerIcon)
            ?? string(forKey: Keys.legacyActivePanelIcon)
    }

    /// 保存视图容器图标名称
    public func saveActiveViewContainerIcon(_ icon: String?) {
        set(icon, forKey: LayoutStorageKey.activeViewContainerIcon)
    }

    /// 加载已保存的视图容器 ID
    public func loadActiveViewContainerID() -> String? {
        string(forKey: LayoutStorageKey.activeViewContainerID)
    }

    /// 保存视图容器 ID
    public func saveActiveViewContainerID(_ id: String?) {
        queue.sync {
            var dict = self.readDict()
            if let id {
                dict[LayoutStorageKey.activeViewContainerID] = id
            } else {
                dict.removeValue(forKey: LayoutStorageKey.activeViewContainerID)
            }
            self.writeDict(dict)
        }
    }

    /// 加载已保存的侧边栏 Tab ID
    public func loadSelectedAgentSidebarTabId() -> String? {
        string(forKey: LayoutStorageKey.activeRailTabID)
    }

    /// 保存侧边栏 Tab ID
    public func saveSelectedAgentSidebarTabId(_ id: String?) {
        set(id, forKey: LayoutStorageKey.activeRailTabID)
    }

    /// 加载已保存的 Detail 视图 ID
    public func loadSelectedAgentDetailId() -> String? {
        string(forKey: Keys.selectedAgentDetailId)
    }

    /// 保存 Detail 视图 ID
    public func saveSelectedAgentDetailId(_ id: String?) {
        set(id, forKey: Keys.selectedAgentDetailId)
    }

    // MARK: - Split Dimensions

    /// 加载已保存的分栏尺寸（宽度或高度）
    public func loadSplitDimension(forKey key: String) -> Double? {
        loadSplitDimensions()[key]
    }

    /// 保存分栏尺寸（宽度或高度）
    public func saveSplitDimension(_ value: Double, forKey key: String) {
        queue.async { [self] in
            var dict = self.readDict()
            var dimensions = dict[Keys.splitDimensions] as? [String: Double] ?? [:]
            dimensions[key] = value
            dict[Keys.splitDimensions] = dimensions
            self.writeDict(dict)
        }
    }

    /// 删除单个分栏尺寸 key。子字典为空时一并移除 `splitDimensions` 键，避免空 dict 残留。
    public func removeSplitDimension(forKey key: String) {
        queue.async { [self] in
            var dict = self.readDict()
            var dimensions = dict[Keys.splitDimensions] as? [String: Double] ?? [:]
            guard dimensions.removeValue(forKey: key) != nil else { return }
            if dimensions.isEmpty {
                dict.removeValue(forKey: Keys.splitDimensions)
            } else {
                dict[Keys.splitDimensions] = dimensions
            }
            self.writeDict(dict)
        }
    }

    /// 加载全部分栏尺寸
    public func loadSplitDimensions() -> [String: Double] {
        queue.sync {
            guard let dict = readDict()[Keys.splitDimensions] as? [String: Any] else {
                return [:]
            }
            return dict.compactMapValues { $0 as? Double }
        }
    }

    // MARK: - Layout Ratios

    /// 加载已保存的分栏布局比例
    /// - Returns: key -> ratio 的字典
    public func loadLayoutRatios() -> [String: Double] {
        queue.sync {
            guard let dict = readDict()[Keys.layoutRatios] as? [String: Any] else {
                return [:]
            }
            return dict.compactMapValues { $0 as? Double }
        }
    }

    /// 保存分栏布局比例（异步，不阻塞调用线程）
    /// - Parameter ratios: key -> ratio 的字典
    public func saveLayoutRatios(_ ratios: [String: Double]) {
        queue.async { [self] in
            var dict = self.readDict()
            dict[Keys.layoutRatios] = ratios
            self.writeDict(dict)
        }
    }

    // MARK: - Editor Bottom Panel Height

    /// 加载已保存的底部面板高度（同步，需要返回值）
    /// - Returns: 高度值，默认返回 nil 表示未保存过
    public func loadEditorBottomPanelHeight() -> Double? {
        queue.sync {
            self.readDict()[Keys.editorBottomPanelHeight] as? Double
        }
    }

    /// 保存底部面板高度（异步，不阻塞调用线程）
    /// - Parameter height: 高度值
    public func saveEditorBottomPanelHeight(_ height: Double) {
        queue.async { [self] in
            var dict = self.readDict()
            dict[Keys.editorBottomPanelHeight] = height
            self.writeDict(dict)
        }
    }

    // MARK: - Bottom Panel Visibility

    /// 加载已保存的底部面板可见性（同步，需要返回值）
    /// - Returns: 可见性，默认返回 nil 表示未保存过
    public func loadBottomPanelVisible() -> Bool? {
        object(forKey: LayoutStorageKey.bottomPanelVisible) as? Bool
    }

    /// 保存底部面板可见性（异步，不阻塞调用线程）
    public func saveBottomPanelVisible(_ visible: Bool) {
        set(visible, forKey: LayoutStorageKey.bottomPanelVisible)
    }

    // MARK: - Content Panel Visibility

    /// 加载已保存的内容面板可见性（同步，需要返回值）
    /// - Returns: 可见性，默认返回 nil 表示未保存过
    public func loadContentPanelVisible() -> Bool? {
        object(forKey: LayoutStorageKey.chatSectionVisible) as? Bool
    }

    /// 保存内容面板可见性（异步，不阻塞调用线程）
    public func saveContentPanelVisible(_ visible: Bool) {
        set(visible, forKey: LayoutStorageKey.chatSectionVisible)
    }

    // MARK: - Editor Visibility

    /// 加载已保存的编辑器区域可见性（同步，需要返回值）
    /// - Returns: 可见性，默认返回 nil 表示未保存过
    public func loadEditorVisible() -> Bool? {
        object(forKey: Keys.editorVisible) as? Bool
    }

    /// 保存编辑器区域可见性（异步，不阻塞调用线程）
    public func saveEditorVisible(_ visible: Bool) {
        set(visible, forKey: Keys.editorVisible)
    }

    // MARK: - Rail Visibility

    /// 加载已保存的 Rail 区域可见性（同步，需要返回值）
    /// - Returns: 可见性，默认返回 nil 表示未保存过
    public func loadRailVisible() -> Bool? {
        object(forKey: Keys.railVisible) as? Bool
    }

    /// 保存 Rail 区域可见性（异步，不阻塞调用线程）
    public func saveRailVisible(_ visible: Bool) {
        set(visible, forKey: Keys.railVisible)
    }

    // MARK: - Right Sidebar Visibility

    /// 加载已保存的右侧栏可见性（同步，需要返回值）
    /// - Returns: 可见性，默认返回 nil 表示未保存过
    public func loadRightSidebarVisible() -> Bool? {
        object(forKey: Keys.rightSidebarVisible) as? Bool
    }

    /// 保存右侧栏可见性（异步，不阻塞调用线程）
    public func saveRightSidebarVisible(_ visible: Bool) {
        set(visible, forKey: Keys.rightSidebarVisible)
    }

    // MARK: - Keys

    private enum Keys {
        static let activeViewContainerIcon = "activeViewContainerIcon"
        static let legacyActivePanelIcon = "activePanelIcon"
        static let selectedAgentSidebarTabId = "selectedAgentSidebarTabId"
        static let selectedAgentDetailId = "selectedAgentDetailId"
        static let splitDimensions = "splitDimensions"
        static let layoutRatios = "layoutRatios"
        static let editorBottomPanelHeight = "editorBottomPanelHeight"
        static let bottomPanelVisible = "bottomPanelVisible"
        static let contentPanelVisible = "contentPanelVisible"
        static let editorVisible = "editorVisible"
        static let railVisible = "railVisible"
        static let rightSidebarVisible = "rightSidebarVisible"
    }

    // MARK: - Private Helpers

    /// 从文件读取字典
    private func readDict() -> [String: Any] {
        guard fileManager.fileExists(atPath: settingsFileURL.path) else {
            return [:]
        }

        let data: Data
        do {
            data = try Data(contentsOf: settingsFileURL)
        } catch {
            return [:]
        }

        do {
            let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
            guard let dict = plist as? [String: Any] else {
                quarantineCorruptSettings()
                return [:]
            }
            return dict
        } catch {
            quarantineCorruptSettings()
            return [:]
        }
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

    private func quarantineCorruptSettings() {
        guard fileManager.fileExists(atPath: settingsFileURL.path) else { return }

        do {
            if fileManager.fileExists(atPath: corruptSettingsFileURL.path) {
                try fileManager.removeItem(at: corruptSettingsFileURL)
            }
            try fileManager.moveItem(at: settingsFileURL, to: corruptSettingsFileURL)
        } catch {
            try? fileManager.removeItem(at: corruptSettingsFileURL)
        }
    }
}
