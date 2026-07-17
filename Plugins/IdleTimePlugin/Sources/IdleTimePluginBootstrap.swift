import Foundation
import LumiCoreKit

@MainActor
public extension IdleTimePlugin {
    static func bootstrapFromLumiCoreIfNeeded(context: LumiPluginContext) {
        guard !didBootstrapFromLumiCore else { return }
        if let core = context.lumiCore {
            IdleTimeRuntimeBridge.directoryURL = core.storage.pluginDataDirectory(for: "IdleTime")
            didBootstrapFromLumiCore = true
        }
    }
}

enum IdleTimeRuntimeBridge {
    nonisolated(unsafe) static var directoryURL: URL?
}

private nonisolated(unsafe) var didBootstrapFromLumiCore = false
