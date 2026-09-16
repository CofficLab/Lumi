import Foundation

public enum ClipboardManagerRuntime {
    nonisolated(unsafe) public static var databaseDirectoryProvider: () -> URL = {
        fallbackDataRootDirectory
            .appendingPathComponent("com.coffic.lumi.plugin.clipboard-manager", isDirectory: true)
    }

    private static let fallbackDataRootDirectory: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        #if DEBUG
        let versionedRoot = "db_debug_v6"
        #else
        let versionedRoot = "db_production_v6"
        #endif
        return base
            .appendingPathComponent("com.coffic.Lumi", isDirectory: true)
            .appendingPathComponent(versionedRoot, isDirectory: true)
    }()

    public static func databaseDirectory() -> URL {
        databaseDirectoryProvider()
    }
}
