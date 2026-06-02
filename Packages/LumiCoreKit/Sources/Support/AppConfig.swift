import Foundation

/// Package-safe subset of app configuration used by plugin packages.
public enum AppConfig {
    public static func getDBFolderURL() -> URL {
        let appSupport = getCurrentAppSupportDir()
        let versionSuffix = getVersionSuffix(from: getAppVersion())

        #if DEBUG
        let dbDirectoryName = "db_debug_\(versionSuffix)"
        #else
        let dbDirectoryName = "db_production_\(versionSuffix)"
        #endif

        let dbDirectory = appSupport.appendingPathComponent(dbDirectoryName, isDirectory: true)
        try? FileManager.default.createDirectory(at: dbDirectory, withIntermediateDirectories: true)
        return dbDirectory
    }

    public static func getPluginDBFolderURL(pluginName: String) -> URL {
        let sanitized = pluginName.trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "_")
        let name = sanitized.isEmpty ? "Plugin" : sanitized
        let directory = getDBFolderURL().appendingPathComponent(name, isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    public static func getCurrentAppSupportDir() -> URL {
        let fileManager = FileManager.default
        let appDirectory = currentAppSupportDir(
            appSupportURL: fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first,
            homeDirectory: fileManager.homeDirectoryForCurrentUser,
            bundleID: Bundle.main.bundleIdentifier
        )
        try? fileManager.createDirectory(at: appDirectory, withIntermediateDirectories: true)
        return appDirectory
    }

    static func currentAppSupportDir(appSupportURL: URL?, homeDirectory: URL, bundleID: String?) -> URL {
        let base = appSupportURL
            ?? homeDirectory.appendingPathComponent("Library/Application Support", isDirectory: true)
        return base.appendingPathComponent(bundleID ?? "com.coffic.Lumi", isDirectory: true)
    }

    private static func getAppVersion() -> String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private static func getVersionSuffix(from version: String) -> String {
        "v\(getMajorVersion(from: version))"
    }

    private static func getMajorVersion(from version: String) -> Int {
        let components = version.split(separator: ".")
        return Int(components.first ?? "1") ?? 1
    }
}
