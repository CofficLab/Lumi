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

    // MARK: - AppCoreSetting

    private static let modeKey = "App_SelectedMode"
    private static let selectedNavigationIdKey = "App_SelectedNavigationId"

    /// 加载应用核心设置
    static func loadAppSetting() -> AppCoreSetting {
        guard let raw = object(forKey: modeKey) as? String,
              let mode = AppMode(rawValue: raw) else {
            return AppCoreSetting(mode: .agent, selectedNavigationId: nil)
        }
        let selectedNavigationId = object(forKey: selectedNavigationIdKey) as? String
        return AppCoreSetting(mode: mode, selectedNavigationId: selectedNavigationId)
    }

    /// 保存应用核心设置
    static func saveAppSetting(_ setting: AppCoreSetting) {
        set(setting.mode.rawValue, forKey: modeKey)
        set(setting.selectedNavigationId, forKey: selectedNavigationIdKey)
    }

    // MARK: - Convenience

    /// 加载 App 模式下的上次选中导航入口 ID
    static func loadSelectedNavigationId() -> String? {
        object(forKey: selectedNavigationIdKey) as? String
    }

    /// 保存 App 模式下的上次选中导航入口 ID
    static func saveSelectedNavigationId(_ id: String?) {
        set(id, forKey: selectedNavigationIdKey)
    }

    /// 加载当前模式
    static func loadMode() -> AppMode? {
        guard let raw = object(forKey: modeKey) as? String else { return nil }
        return AppMode(rawValue: raw)
    }

    /// 保存模式
    static func saveMode(_ mode: AppMode) {
        set(mode.rawValue, forKey: modeKey)
    }
}
