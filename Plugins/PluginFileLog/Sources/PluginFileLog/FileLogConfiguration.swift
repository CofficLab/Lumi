import Foundation

public protocol FileLogConfiguration: Sendable {
    func logsDirectory() -> URL
}

struct DefaultFileLogConfiguration: FileLogConfiguration {
    func logsDirectory() -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let bundleID = Bundle.main.bundleIdentifier ?? "com.coffic.lumi"
        return appSupport
            .appendingPathComponent(bundleID, isDirectory: true)
            .appendingPathComponent("FileLog", isDirectory: true)
    }
}
