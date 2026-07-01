import Foundation
import LumiCoreKit

/// Layout 持久化实现（供 LayoutPlugin 使用）
/// 负责将布局数据写入磁盘
public final class LayoutPluginLocalStore: @unchecked Sendable, LumiLayoutPersistence {

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
        let root = AppConfig.getDBFolderURL()
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

    // MARK: - LumiLayoutPersistence Implementation

    public func loadActiveViewContainerID() -> String? {
        string(forKey: Keys.activeViewContainerID)
    }

    public func saveActiveViewContainerID(_ id: String?) {
        queue.sync {
            var dict = self.readDict()
            if let id {
                dict[Keys.activeViewContainerID] = id
            } else {
                dict.removeValue(forKey: Keys.activeViewContainerID)
            }
            self.writeDict(dict)
        }
    }

    public func loadRightSidebarVisible() -> Bool? {
        object(forKey: Keys.rightSidebarVisible) as? Bool
    }

    public func saveRightSidebarVisible(_ visible: Bool) {
        set(visible, forKey: Keys.rightSidebarVisible)
    }

    public func loadBottomPanelVisible() -> Bool? {
        object(forKey: Keys.bottomPanelVisible) as? Bool
    }

    public func saveBottomPanelVisible(_ visible: Bool) {
        set(visible, forKey: Keys.bottomPanelVisible)
    }

    public func loadSplitDimension(forKey key: String) -> Double? {
        loadSplitDimensions()[key]
    }

    public func saveSplitDimension(_ value: Double, forKey key: String) {
        queue.async { [self] in
            var dict = self.readDict()
            var dimensions = dict[Keys.splitDimensions] as? [String: Double] ?? [:]
            dimensions[key] = value
            dict[Keys.splitDimensions] = dimensions
            self.writeDict(dict)
        }
    }

    public func loadSplitDimensions() -> [String: Double] {
        queue.sync {
            guard let dict = readDict()[Keys.splitDimensions] as? [String: Any] else {
                return [:]
            }
            return dict.compactMapValues { $0 as? Double }
        }
    }

    public func loadLayoutRatios() -> [String: Double] {
        queue.sync {
            guard let dict = readDict()[Keys.layoutRatios] as? [String: Any] else {
                return [:]
            }
            return dict.compactMapValues { $0 as? Double }
        }
    }

    public func saveLayoutRatios(_ ratios: [String: Double]) {
        queue.async { [self] in
            var dict = self.readDict()
            dict[Keys.layoutRatios] = ratios
            self.writeDict(dict)
        }
    }

    public func loadEditorBottomPanelHeight() -> Double? {
        queue.sync {
            self.readDict()[Keys.editorBottomPanelHeight] as? Double
        }
    }

    public func saveEditorBottomPanelHeight(_ height: Double) {
        queue.async { [self] in
            var dict = self.readDict()
            dict[Keys.editorBottomPanelHeight] = height
            self.writeDict(dict)
        }
    }

    public func loadContentPanelVisible() -> Bool? {
        object(forKey: Keys.contentPanelVisible) as? Bool
    }

    public func saveContentPanelVisible(_ visible: Bool) {
        set(visible, forKey: Keys.contentPanelVisible)
    }

    public func loadEditorVisible() -> Bool? {
        object(forKey: Keys.editorVisible) as? Bool
    }

    public func saveEditorVisible(_ visible: Bool) {
        set(visible, forKey: Keys.editorVisible)
    }

    public func loadRailVisible() -> Bool? {
        object(forKey: Keys.railVisible) as? Bool
    }

    public func saveRailVisible(_ visible: Bool) {
        set(visible, forKey: Keys.railVisible)
    }

    // MARK: - Keys

    private enum Keys {
        static let activeViewContainerID = "activeViewContainerID"
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
