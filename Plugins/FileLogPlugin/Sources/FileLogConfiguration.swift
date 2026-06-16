import Foundation
import LumiCoreKit

public protocol FileLogConfiguration: Sendable {
    func logsDirectory() -> URL
}

struct DefaultFileLogConfiguration: FileLogConfiguration {
    func logsDirectory() -> URL {
        AppConfig.getPluginDBFolderURL(pluginName: "FileLog")
    }
}
