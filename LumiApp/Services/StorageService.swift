import Foundation

final class StorageService {
    static func makeDataRootDirectory() -> URL {
        let fileManager = FileManager.default
        guard let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            fatalError("Unable to resolve Application Support directory.")
        }

        let bundleID = Bundle.main.bundleIdentifier ?? "com.coffic.Lumi"
        let appDirectory = appSupportURL.appendingPathComponent(bundleID, isDirectory: true)
        let versionSuffix = "v\(majorVersion(from: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String))"

        #if DEBUG
        let databaseDirectoryName = "db_debug_\(versionSuffix)"
        #else
        let databaseDirectoryName = "db_production_\(versionSuffix)"
        #endif

        let dataRootDirectory = appDirectory.appendingPathComponent(databaseDirectoryName, isDirectory: true)
        try? fileManager.createDirectory(
            at: dataRootDirectory,
            withIntermediateDirectories: true,
            attributes: nil
        )

        return dataRootDirectory
    }

    static func makeCoreDatabaseDirectory(in dataRootDirectory: URL) -> URL {
        let coreDirectory = dataRootDirectory.appendingPathComponent("Core", isDirectory: true)
        try? FileManager.default.createDirectory(
            at: coreDirectory,
            withIntermediateDirectories: true,
            attributes: nil
        )
        return coreDirectory
    }

    static func majorVersion(from version: String?) -> Int {
        guard let version,
              let major = version.split(separator: ".").first,
              let value = Int(major)
        else {
            return 1
        }

        return value
    }
}
