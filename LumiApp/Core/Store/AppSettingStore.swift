import Foundation

/// 应用级通用设置（plist 字典存取 + 旧版 `db/app_settings` 兼容迁移）。
///
/// 设计目标：
/// - 调用方尽量用简单的 `loadX/saveX` 接口
/// - 不依赖 Keychain（仅用于非敏感配置）
/// - 写入使用原子替换，避免半写状态
enum AppSettingStore {
    private static let pluginDirName = "AppSettings"
    private static let settingsFileName = "app_settings.plist"
    private static let tmpFileName = "app_settings.tmp"

    private static let settingsDirURL: URL = {
        AppConfig.getDBFolderURL()
            .appendingPathComponent("Core", isDirectory: true)
            .appendingPathComponent(pluginDirName, isDirectory: true)
            .appendingPathComponent("settings", isDirectory: true)
    }()

    private static func settingsFileURL() -> URL {
        settingsDirURL.appendingPathComponent(settingsFileName, isDirectory: false)
    }

    // MARK: - Public (Generic)

    static func object(forKey key: String) -> Any? {
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

    static func set(_ value: Any?, forKey key: String) {
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
            // 不影响 UI 展示：仅用于持久化应用级非敏感配置。
        }
    }

    // MARK: - Public (Typed)

    static func loadString(forKey key: String) -> String? {
        object(forKey: key) as? String
    }

    static func saveString(_ value: String, forKey key: String) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            set(nil, forKey: key)
        } else {
            set(trimmed, forKey: key)
        }
    }

    static func loadBool(forKey key: String) -> Bool? {
        if let b = object(forKey: key) as? Bool { return b }
        if let n = object(forKey: key) as? NSNumber { return n.boolValue }
        return nil
    }

    static func saveBool(_ value: Bool, forKey key: String) {
        set(value, forKey: key)
    }

    // MARK: - Legacy Migration

    /// 若新存储不存在该 key，则从旧版 `db/app_settings/<key>.plist` 迁移一次。
    static func migrateLegacyValueIfMissing(forKey key: String) {
        guard object(forKey: key) == nil else { return }
        guard let legacy = readLegacyObject(forKey: key) else { return }
        set(legacy, forKey: key)
    }

    private static func readLegacyObject(forKey key: String) -> Any? {
        let legacyDir = AppConfig.getDBFolderURL().appendingPathComponent("app_settings", isDirectory: true)
        let legacyFile = legacyDir.appendingPathComponent(sanitizeLegacyFileName(key) + ".plist", isDirectory: false)
        guard FileManager.default.fileExists(atPath: legacyFile.path),
              let data = try? Data(contentsOf: legacyFile),
              let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) else {
            return nil
        }

        // 兼容：部分旧数据可能是 dict 包裹的 `_data`（Data 形式）。
        if let dict = plist as? [String: Any], let dataVal = dict["_data"] as? Data {
            return dataVal
        }

        return plist
    }

    private static func sanitizeLegacyFileName(_ key: String) -> String {
        let safe = key.unicodeScalars
            .map { CharacterSet.alphanumerics.contains($0) || $0 == "_" ? String($0) : "_" }
            .joined()
        return safe.isEmpty ? "key" : safe
    }

    // MARK: - AppSetting (Typed)

    /// 与旧版 `AgentModePersistencePlugin` 一致，保证迁移可用。
    private static let modeKey = "App_SelectedMode"

    static func loadAppSetting() -> AppSetting {
        let mode = loadMode() ?? .agent
        return AppSetting(mode: mode)
    }

    static func saveAppSetting(_ setting: AppSetting) {
        set(setting.mode.rawValue, forKey: modeKey)
    }

    static func loadMode() -> AppMode? {
        // 先做一次 legacy 迁移（如果新存储没值）。
        migrateLegacyValueIfMissing(forKey: modeKey)

        guard let raw = object(forKey: modeKey) else { return nil }
        if let s = raw as? String {
            return AppMode(rawValue: s)
        }
        if let n = raw as? NSNumber {
            return AppMode(rawValue: n.stringValue)
        }
        if let data = raw as? Data, let s = String(data: data, encoding: .utf8) {
            return AppMode(rawValue: s)
        }
        return nil
    }

    static func saveMode(_ mode: AppMode) {
        set(mode.rawValue, forKey: modeKey)
    }
}

