import Foundation

/// 应用核心设置的存储管理（plist 字典存取）。
///
/// 设计目标：
/// - 简单的 `loadX/saveX` 接口
/// - 不依赖 Keychain（仅用于非敏感配置）
/// - 写入使用原子替换，避免半写状态
enum AppSettingStore {
    private static let settingsFileName = "app_settings.plist"
    private static let tmpFileName = "app_settings.tmp"

    private static let settingsDirURL: URL = {
        AppConfig.getDBFolderURL()
            .appendingPathComponent("Core", isDirectory: true)
            .appendingPathComponent("AppSettings", isDirectory: true)
    }()

    private static func settingsFileURL() -> URL {
        settingsDirURL.appendingPathComponent(settingsFileName, isDirectory: false)
    }

    // MARK: - Private (Core)

    private static func object(forKey key: String) -> Any? {
        guard !key.isEmpty else { return nil }
        let fileURL = settingsFileURL()
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        guard let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
              let dict = plist as? [String: Any] else {
            return nil
        }
        return dict[key]
    }

    private static func set(_ value: Any?, forKey key: String) {
        guard !key.isEmpty else { return }
        let fileURL = settingsFileURL()

        var dict: [String: Any] = [:]
        if FileManager.default.fileExists(atPath: fileURL.path),
           let data = try? Data(contentsOf: fileURL),
           let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
           let existing = plist as? [String: Any] {
            dict = existing
        }

        if let value {
            dict[key] = value
        } else {
            dict.removeValue(forKey: key)
        }

        guard let data = try? PropertyListSerialization.data(fromPropertyList: dict, format: .binary, options: 0) else { return }

        do {
            try FileManager.default.createDirectory(at: settingsDirURL, withIntermediateDirectories: true, attributes: nil)
            let tmpURL = settingsDirURL.appendingPathComponent(tmpFileName, isDirectory: false)
            try data.write(to: tmpURL, options: .atomic)

            if FileManager.default.fileExists(atPath: fileURL.path) {
                _ = try? FileManager.default.replaceItemAt(fileURL, withItemAt: tmpURL)
            } else {
                try FileManager.default.moveItem(at: tmpURL, to: fileURL)
            }
        } catch {
            // 静默失败：仅用于持久化应用级非敏感配置
        }
    }

    // MARK: - Mode

    private static let modeKey = "App_SelectedMode"

    /// 加载当前模式
    static func loadMode() -> AppMode? {
        guard let raw = object(forKey: modeKey) as? String else { return nil }
        return AppMode(rawValue: raw)
    }

    /// 保存模式
    static func saveMode(_ mode: AppMode) {
        set(mode.rawValue, forKey: modeKey)
    }

    // MARK: - Navigation

    private static let selectedNavigationIdKey = "App_SelectedNavigationId"

    /// 加载 App 模式下的上次选中导航入口 ID
    static func loadSelectedNavigationId() -> String? {
        object(forKey: selectedNavigationIdKey) as? String
    }

    /// 保存 App 模式下的上次选中导航入口 ID
    static func saveSelectedNavigationId(_ id: String?) {
        set(id, forKey: selectedNavigationIdKey)
    }

    // MARK: - Settings Selection

    private static let settingsSelectionTypeKey = "App_SettingsSelectionType"
    private static let settingsSelectionValueKey = "App_SettingsSelectionValue"

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
    static func saveSettingsSelection(type: String, value: String) {
        set(type, forKey: settingsSelectionTypeKey)
        set(value, forKey: settingsSelectionValueKey)
    }

    /// 清除设置界面的选中项
    static func clearSettingsSelection() {
        set(nil, forKey: settingsSelectionTypeKey)
        set(nil, forKey: settingsSelectionValueKey)
    }

    // MARK: - Remote Provider

    private static let selectedRemoteProviderIdKey = "App_SelectedRemoteProviderId"

    /// 加载上次选中的云端供应商 ID
    static func loadSelectedRemoteProviderId() -> String? {
        object(forKey: selectedRemoteProviderIdKey) as? String
    }

    /// 保存选中的云端供应商 ID
    /// - Parameter id: 供应商 ID，为 nil 时清除保存的值
    static func saveSelectedRemoteProviderId(_ id: String?) {
        set(id, forKey: selectedRemoteProviderIdKey)
    }
}
