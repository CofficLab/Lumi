import Foundation

public enum ConversationListRuntime {
    nonisolated(unsafe) public static var databaseDirectoryProvider: () -> URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("Lumi", isDirectory: true)
    }

    public static func databaseDirectory() -> URL {
        databaseDirectoryProvider()
    }
}
