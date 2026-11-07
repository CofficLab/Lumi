import Foundation

/// Resolves the shared application data-root convention without requiring a
/// `KernelCoreContainer`. Legacy hosts can use this while they migrate to the
/// kernel-based `StorageSuperPlugin` lifecycle.
public enum StoragePathResolver {
    public static func defaultDataRootDirectory(
        bundle: Bundle = .main,
        fallbackBundleID: String = "com.coffic.lumi",
        fallbackMajorVersion: Int = 1
    ) throws -> URL {
        let applicationSupport = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )

        let bundleID = bundle.bundleIdentifier ?? fallbackBundleID
        let version = bundle.infoDictionary?["CFBundleShortVersionString"] as? String
        let majorVersion = version?
            .split(separator: ".")
            .first
            .flatMap { Int($0) } ?? fallbackMajorVersion

        #if DEBUG
        let databaseDirectoryName = "db_debug_v\(majorVersion)"
        #else
        let databaseDirectoryName = "db_production_v\(majorVersion)"
        #endif

        let dataRoot = applicationSupport
            .appendingPathComponent(bundleID, isDirectory: true)
            .appendingPathComponent(databaseDirectoryName, isDirectory: true)

        try FileManager.default.createDirectory(
            at: dataRoot,
            withIntermediateDirectories: true
        )
        return dataRoot.standardizedFileURL
    }
}
