import Foundation
import os

/// 应用核心设置的存储管理（plist 字典存取）。
///
/// 设计目标：
/// - 简单的 `loadX/saveX` 接口
/// - 不依赖 Keychain（仅用于非敏感配置）
/// - 写入使用原子替换，避免半写状态
enum AppSettingStore {
    private static let logger = Logger(subsystem: "com.coffic.lumi", category: "core.app-setting-store")
    private static let settingsFileName = "app_settings.plist"

    nonisolated(unsafe) private static var settingsDirectoryProvider: () -> URL = {
        AppConfig.getDBFolderURL()
            .appendingPathComponent("Core", isDirectory: true)
            .appendingPathComponent("AppSettings", isDirectory: true)
    }

    private static func settingsFileURL() -> URL {
        settingsDirURL().appendingPathComponent(settingsFileName, isDirectory: false)
    }

    private static func corruptSettingsFileURL() -> URL {
        settingsDirURL().appendingPathComponent("app_settings.corrupt.plist", isDirectory: false)
    }

    // MARK: - Private (Core)

    private static func object(forKey key: String) -> Any? {
        guard !key.isEmpty else { return nil }
        let fileURL = settingsFileURL()
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        let data: Data
        do {
            data = try Data(contentsOf: fileURL)
        } catch {
            logger.error("Read app settings failed: \(error.localizedDescription)")
            return nil
        }

        do {
            let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
            guard let dict = plist as? [String: Any] else {
                logger.error("Read app settings failed: root plist is not a dictionary")
                quarantineCorruptSettingsFile()
                return nil
            }
            return dict[key]
        } catch {
            logger.error("Decode app settings failed: \(error.localizedDescription)")
            quarantineCorruptSettingsFile()
            return nil
        }
    }

    @discardableResult
    private static func set(_ value: Any?, forKey key: String) -> Bool {
        guard !key.isEmpty else { return false }
        let fileURL = settingsFileURL()

        var dict: [String: Any] = [:]
        if FileManager.default.fileExists(atPath: fileURL.path) {
            let data: Data
            do {
                data = try Data(contentsOf: fileURL)
            } catch {
                logger.error("Read existing app settings before save failed: \(error.localizedDescription)")
                return false
            }

            do {
                let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
                if let existing = plist as? [String: Any] {
                    dict = existing
                } else {
                    logger.error("Save app setting failed: root plist is not a dictionary")
                    quarantineCorruptSettingsFile()
                    dict = [:]
                }
            } catch {
                logger.error("Decode existing app settings before save failed: \(error.localizedDescription)")
                quarantineCorruptSettingsFile()
                dict = [:]
            }
        }

        if let value {
            dict[key] = value
        } else {
            dict.removeValue(forKey: key)
        }

        let data: Data
        do {
            data = try PropertyListSerialization.data(fromPropertyList: dict, format: .binary, options: 0)
        } catch {
            logger.error("Encode app settings failed: \(error.localizedDescription)")
            return false
        }

        do {
            try FileManager.default.createDirectory(at: settingsDirURL(), withIntermediateDirectories: true, attributes: nil)
            try data.write(to: fileURL, options: .atomic)
            return true
        } catch {
            logger.error("Persist app settings failed: \(error.localizedDescription)")
            return false
        }
    }

    private static func settingsDirURL() -> URL {
        settingsDirectoryProvider()
    }

    private static func quarantineCorruptSettingsFile() {
        let sourceURL = settingsFileURL()
        let quarantineURL = corruptSettingsFileURL()
        guard FileManager.default.fileExists(atPath: sourceURL.path) else { return }

        do {
            if FileManager.default.fileExists(atPath: quarantineURL.path) {
                try FileManager.default.removeItem(at: quarantineURL)
            }
            try FileManager.default.moveItem(at: sourceURL, to: quarantineURL)
        } catch {
            logger.error("Quarantine corrupt app settings failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Settings Selection

    private static let settingsSelectionTypeKey = "App_SettingsSelectionType"
    private static let settingsSelectionValueKey = "App_SettingsSelectionValue"
    private static let pendingEditorSettingsSearchQueryKey = "App_PendingEditorSettingsSearchQuery"
    private static let editorRecentCommandIDsKey = "App_EditorRecentCommandIDs"
    private static let editorCommandUsageCountsKey = "App_EditorCommandUsageCounts"
    private static let editorCommandPaletteCategoryKey = "App_EditorCommandPaletteCategory"

    /// 加载设置界面的上次选中项
    /// - Returns: 元组 (类型，值)，类型为 "core" 或 "plugin"
    static func loadSettingsSelection() -> (type: String, value: String)? {
        guard let type = object(forKey: settingsSelectionTypeKey) as? String,
              let value = object(forKey: settingsSelectionValueKey) as? String else {
            return nil
        }
        return (type, value)
    }

    /// 保存设置界面的选中项
    /// - Parameters:
    ///   - type: 类型，"core" 或 "plugin"
    ///   - value: 值，核心设置的 tab rawValue 或插件 id
    @discardableResult
    static func saveSettingsSelection(type: String, value: String) -> Bool {
        let typeSaved = set(type, forKey: settingsSelectionTypeKey)
        let valueSaved = set(value, forKey: settingsSelectionValueKey)
        return typeSaved && valueSaved
    }

    /// 清除设置界面的选中项
    @discardableResult
    static func clearSettingsSelection() -> Bool {
        let typeCleared = set(nil, forKey: settingsSelectionTypeKey)
        let valueCleared = set(nil, forKey: settingsSelectionValueKey)
        return typeCleared && valueCleared
    }

    static func loadPendingEditorSettingsSearchQuery() -> String? {
        object(forKey: pendingEditorSettingsSearchQueryKey) as? String
    }

    @discardableResult
    static func savePendingEditorSettingsSearchQuery(_ query: String?) -> Bool {
        set(query, forKey: pendingEditorSettingsSearchQueryKey)
    }

    static func consumePendingEditorSettingsSearchQuery() -> String? {
        let query = loadPendingEditorSettingsSearchQuery()
        savePendingEditorSettingsSearchQuery(nil)
        return query
    }

    static func loadEditorRecentCommandIDs() -> [String] {
        object(forKey: editorRecentCommandIDsKey) as? [String] ?? []
    }

    @discardableResult
    static func saveEditorRecentCommandIDs(_ ids: [String]) -> Bool {
        set(ids, forKey: editorRecentCommandIDsKey)
    }

    static func loadEditorCommandUsageCounts() -> [String: Int] {
        object(forKey: editorCommandUsageCountsKey) as? [String: Int] ?? [:]
    }

    @discardableResult
    static func saveEditorCommandUsageCounts(_ counts: [String: Int]) -> Bool {
        set(counts, forKey: editorCommandUsageCountsKey)
    }

    static func loadEditorCommandPaletteCategory() -> String? {
        object(forKey: editorCommandPaletteCategoryKey) as? String
    }

    @discardableResult
    static func saveEditorCommandPaletteCategory(_ rawValue: String?) -> Bool {
        set(rawValue, forKey: editorCommandPaletteCategoryKey)
    }

    // MARK: - Plugin Settings

    private static let pluginSettingsKey = "App_PluginSettings"

    /// 加载插件启用状态
    /// - Returns: 插件 ID 到启用状态的字典
    static func loadPluginSettings() -> [String: Bool] {
        object(forKey: pluginSettingsKey) as? [String: Bool] ?? [:]
    }

    /// 保存插件启用状态
    /// - Parameter settings: 插件 ID 到启用状态的字典
    @discardableResult
    static func savePluginSettings(_ settings: [String: Bool]) -> Bool {
        set(settings, forKey: pluginSettingsKey)
    }

    /// 加载单个插件的启用状态
    /// - Parameter pluginId: 插件 ID
    /// - Returns: 启用状态，如果没有记录则返回 nil
    static func loadPluginEnabled(_ pluginId: String) -> Bool? {
        let settings = loadPluginSettings()
        return settings[pluginId]
    }

    /// 保存单个插件的启用状态
    /// - Parameters:
    ///   - pluginId: 插件 ID
    ///   - enabled: 启用状态
    @discardableResult
    static func savePluginEnabled(_ pluginId: String, enabled: Bool) -> Bool {
        var settings = loadPluginSettings()
        settings[pluginId] = enabled
        return savePluginSettings(settings)
    }

    // MARK: - Remote Provider

    private static let selectedRemoteProviderIdKey = "App_SelectedRemoteProviderId"
    private static let remoteProviderModelsKey = "App_RemoteProviderModels"

    // MARK: - Remote Provider (continued)

    /// 加载上次选中的云端供应商 ID
    static func loadSelectedRemoteProviderId() -> String? {
        object(forKey: selectedRemoteProviderIdKey) as? String
    }

    /// 保存选中的云端供应商 ID
    /// - Parameter id: 供应商 ID，为 nil 时清除保存的值
    @discardableResult
    static func saveSelectedRemoteProviderId(_ id: String?) -> Bool {
        set(id, forKey: selectedRemoteProviderIdKey)
    }

    /// 加载指定云端供应商的默认模型
    /// - Parameter providerId: 供应商 ID
    /// - Returns: 保存的模型 ID，如果没有则返回 nil
    static func loadRemoteProviderModel(providerId: String) -> String? {
        guard let modelsDict = object(forKey: remoteProviderModelsKey) as? [String: String] else {
            return nil
        }
        return modelsDict[providerId]
    }

    /// 保存指定云端供应商的默认模型
    /// - Parameters:
    ///   - providerId: 供应商 ID
    ///   - modelId: 模型 ID
    @discardableResult
    static func saveRemoteProviderModel(providerId: String, modelId: String?) -> Bool {
        var modelsDict: [String: String] = [:]
        if let existing = object(forKey: remoteProviderModelsKey) as? [String: String] {
            modelsDict = existing
        }

        if let modelId {
            modelsDict[providerId] = modelId
        } else {
            modelsDict.removeValue(forKey: providerId)
        }

        return set(modelsDict, forKey: remoteProviderModelsKey)
    }

    // MARK: - Last Selected Model

    private static let lastSelectedProviderIdKey = "App_LastSelectedProviderId"
    private static let lastSelectedModelKey = "App_LastSelectedModel"

    /// 加载上次选择的供应商 ID
    /// - Returns: 供应商 ID，如果没有记录则返回 nil
    static func loadLastSelectedProviderId() -> String? {
        object(forKey: lastSelectedProviderIdKey) as? String
    }

    /// 保存上次选择的供应商 ID
    /// - Parameter providerId: 供应商 ID，为 nil 时清除
    @discardableResult
    static func saveLastSelectedProviderId(_ providerId: String?) -> Bool {
        set(providerId, forKey: lastSelectedProviderIdKey)
    }

    /// 加载上次选择的模型 ID
    /// - Returns: 模型 ID，如果没有记录则返回 nil
    static func loadLastSelectedModel() -> String? {
        object(forKey: lastSelectedModelKey) as? String
    }

    /// 保存上次选择的模型 ID
    /// - Parameter model: 模型 ID，为 nil 时清除
    @discardableResult
    static func saveLastSelectedModel(_ model: String?) -> Bool {
        set(model, forKey: lastSelectedModelKey)
    }

    static func configureForTesting(settingsDirectory: URL) {
        settingsDirectoryProvider = { settingsDirectory }
    }

    static func resetTestingConfiguration() {
        settingsDirectoryProvider = {
            AppConfig.getDBFolderURL()
                .appendingPathComponent("Core", isDirectory: true)
                .appendingPathComponent("AppSettings", isDirectory: true)
        }
    }
}
