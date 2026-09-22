import Foundation
import EditorKernel

/// Editor plugin config persistence store
enum EditorConfigStore {
    private static var pluginDirName: String { EditorHostEnvironment.current.storageDirectoryName }
    private static let settingsFileName = "editor_config.plist"

    private static func resolvedSettingsDirectoryURL() -> URL {
        settingsDirectoryURL(
            persistenceRootURL: EditorSettingsLifecycle.hostPersistenceRootURL?(),
            applicationSupportURL: FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? FileManager.default.temporaryDirectory,
            storageDirectoryName: pluginDirName
        )
    }

    static func settingsDirectoryURL(
        persistenceRootURL: URL?,
        applicationSupportURL: URL,
        storageDirectoryName: String
    ) -> URL {
        let base = persistenceRootURL ?? applicationSupportURL
        return base
            .appendingPathComponent(storageDirectoryName, isDirectory: true)
            .appendingPathComponent("settings", isDirectory: true)
    }

    private static let store = EditorConfigFileStore(
        settingsDirectoryURL: resolvedSettingsDirectoryURL(),
        settingsFileName: settingsFileName
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
    static let autoSaveModeKey = "autoSaveMode"
    static let autoSaveDelayKey = "autoSaveDelay"

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

}
