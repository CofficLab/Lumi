import Foundation
import LumiKernel

public protocol FileLogConfiguration: Sendable {
    func logsDirectory() -> URL
}

struct DefaultFileLogConfiguration: FileLogConfiguration {
    func logsDirectory() -> URL {
        FileLogPluginRuntimeBridge.pluginSubdirectory
            ?? FileLogPluginRuntimeBridge.fallbackRootDirectory.appendingPathComponent("FileLog", isDirectory: true)
    }
}
