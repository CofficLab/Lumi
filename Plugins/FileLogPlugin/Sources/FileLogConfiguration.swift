import Foundation
import LumiCoreKit

public protocol FileLogConfiguration: Sendable {
    func logsDirectory() -> URL
}

struct DefaultFileLogConfiguration: FileLogConfiguration {
    func logsDirectory() -> URL {
        lumiCorePluginDataDirectory(for: "FileLog")
            ?? lumiCoreFallbackDataRootDirectory.appendingPathComponent("FileLog", isDirectory: true)
    }
}
