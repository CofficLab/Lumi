import Foundation

public enum AppConfig {
    nonisolated(unsafe) private static var configuredDataRootDirectory: URL?

    public static var isConfigured: Bool {
        configuredDataRootDirectory != nil
    }

    @MainActor
    public static func configure(dataRootDirectory: URL) {
        let directory = dataRootDirectory.standardizedFileURL
        try? FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        configuredDataRootDirectory = directory
        LumiCore.configure(dataRootDirectory: directory)
        LumiStorageMigration.migrateMisplacedPluginDirectories(to: directory)
    }

    /// 当前版本/环境下的插件数据根目录，例如 `.../com.coffic.lumi/db_debug_v4/`
    public static func getDBFolderURL() -> URL {
        if let configuredDataRootDirectory {
            return configuredDataRootDirectory
        }
        return unresolvedApplicationSupportDirectory()
    }

    public static func getPluginDBFolderURL(pluginName: String) -> URL {
        if let configuredDataRootDirectory {
            let directory = configuredDataRootDirectory
                .appendingPathComponent(sanitizePluginDirectoryName(pluginName), isDirectory: true)
            try? FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )
            return directory
        }

        let pluginDirectory = unresolvedApplicationSupportDirectory()
            .appendingPathComponent(pluginName, isDirectory: true)
        try? FileManager.default.createDirectory(
            at: pluginDirectory,
            withIntermediateDirectories: true
        )
        return pluginDirectory
    }

    private static func sanitizePluginDirectoryName(_ name: String) -> String {
        let sanitized = name.trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "_")
        return sanitized.isEmpty ? "Plugin" : sanitized
    }

    private static func unresolvedApplicationSupportDirectory() -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let bundleID = Bundle.main.bundleIdentifier ?? "com.coffic.lumi"
        return appSupport.appendingPathComponent(bundleID, isDirectory: true)
    }

    #if DEBUG
    static func resetForTesting() {
        configuredDataRootDirectory = nil
    }
    #endif
}
