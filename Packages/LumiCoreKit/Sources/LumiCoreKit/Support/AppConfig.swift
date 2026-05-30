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
        guard let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            fatalError("Unable to locate Application Support directory")
        }

        let bundleID = Bundle.main.bundleIdentifier ?? "com.coffic.Lumi"
        let appDirectory = appSupportURL.appendingPathComponent(bundleID, isDirectory: true)
        try? fileManager.createDirectory(at: appDirectory, withIntermediateDirectories: true)
        return appDirectory
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
