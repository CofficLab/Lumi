import Foundation

/// Editor plugin config persistence store
enum EditorConfigStore {
    private static let pluginDirName = "LumiEditor"
    private static let settingsFileName = "editor_config.plist"
    private static let tmpFileName = "editor_config.tmp"

    private static let settingsDirURL: URL = {
        AppConfig.getDBFolderURL()
            .appendingPathComponent(pluginDirName, isDirectory: true)
            .appendingPathComponent("settings", isDirectory: true)
    }()

    private static func settingsFileURL() -> URL {
        settingsDirURL.appendingPathComponent(settingsFileName, isDirectory: false)
    }

    // MARK: - Keys

    static let fontSizeKey = "fontSize"
    static let tabWidthKey = "tabWidth"
    static let useSpacesKey = "useSpaces"
    static let formatOnSaveKey = "formatOnSave"
    static let organizeImportsOnSaveKey = "organizeImportsOnSave"
    static let fixAllOnSaveKey = "fixAllOnSave"
    static let trimTrailingWhitespaceOnSaveKey = "trimTrailingWhitespaceOnSave"
    static let insertFinalNewlineOnSaveKey = "insertFinalNewlineOnSave"
    static let wrapLinesKey = "wrapLines"
    static let showMinimapKey = "showMinimap"
    static let showGutterKey = "showGutter"
    static let showFoldingRibbonKey = "showFoldingRibbon"
    static let themeNameKey = "themeName"
    private static let editorPluginEnabledPrefix = "editorPluginEnabled."

    // MARK: - Load / Save

    private static func loadDict() -> [String: Any] {
        let fileURL = settingsFileURL()
        guard FileManager.default.fileExists(atPath: fileURL.path),
              let data = try? Data(contentsOf: fileURL),
              let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
              let dict = plist as? [String: Any] else {
            return [:]
        }
        return dict
    }

    private static func saveDict(_ dict: [String: Any]) {
        guard let data = try? PropertyListSerialization.data(fromPropertyList: dict, format: .binary, options: 0) else { return }
        do {
            try FileManager.default.createDirectory(at: settingsDirURL, withIntermediateDirectories: true, attributes: nil)
            let tmpURL = settingsDirURL.appendingPathComponent(tmpFileName, isDirectory: false)
            try data.write(to: tmpURL, options: .atomic)
            let fileURL = settingsFileURL()
            if FileManager.default.fileExists(atPath: fileURL.path) {
                _ = try? FileManager.default.replaceItemAt(fileURL, withItemAt: tmpURL)
            } else {
                try FileManager.default.moveItem(at: tmpURL, to: fileURL)
            }
        } catch {
            // 配置保存失败不影响主流程
        }
    }

    static func loadDouble(forKey key: String) -> Double? {
        loadDict()[key] as? Double
    }

    static func loadInt(forKey key: String) -> Int? {
        loadDict()[key] as? Int
    }

    static func loadBool(forKey key: String) -> Bool? {
        loadDict()[key] as? Bool
    }

    static func loadString(forKey key: String) -> String? {
        loadDict()[key] as? String
    }

    static func loadDictionary(forKey key: String) -> [String: Any]? {
        loadDict()[key] as? [String: Any]
    }

    static func saveValue(_ value: Any, forKey key: String) {
        var dict = loadDict()
        dict[key] = value
        saveDict(dict)
    }

    static func removeValue(forKey key: String) {
        var dict = loadDict()
        dict.removeValue(forKey: key)
        saveDict(dict)
    }

    static func loadEditorPluginEnabled(_ pluginID: String) -> Bool? {
        loadBool(forKey: editorPluginEnabledPrefix + pluginID)
    }

    /// @deprecated 使用 `PluginSettingsVM.setPluginEnabled` 替代
    @available(*, deprecated, message: "Use PluginSettingsVM.setPluginEnabled instead")
    static func saveEditorPluginEnabled(_ pluginID: String, enabled: Bool) {
        saveValue(enabled, forKey: editorPluginEnabledPrefix + pluginID)
    }

    // MARK: - Migration Support

    /// 加载所有旧版设置（仅用于迁移到 PluginSettingsVM）
    static func loadAllSettings() -> [String: Any] {
        loadDict()
    }
}
