import Foundation
import EditorKernelCore

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
    private static let store = EditorConfigFileStore(
        settingsDirectoryURL: settingsDirURL,
        settingsFileName: settingsFileName,
        temporaryFileName: tmpFileName
    )

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
    private static let editorPluginEnabledPrefix = "editorPluginEnabled."

    // MARK: - Load / Save

    static func loadDouble(forKey key: String) -> Double? {
        store.loadingValue(forKey: key)
    }

    static func loadInt(forKey key: String) -> Int? {
        store.loadingValue(forKey: key)
    }

    static func loadBool(forKey key: String) -> Bool? {
        store.loadingValue(forKey: key)
    }

    static func loadString(forKey key: String) -> String? {
        store.loadingValue(forKey: key)
    }

    static func loadDictionary(forKey key: String) -> [String: Any]? {
        store.loadingValue(forKey: key)
    }

    static func saveValue(_ value: Any, forKey key: String) {
        store.savingValue(value, forKey: key)
    }

    static func removeValue(forKey key: String) {
        store.removingValue(forKey: key)
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
        store.loadDict()
    }
}
