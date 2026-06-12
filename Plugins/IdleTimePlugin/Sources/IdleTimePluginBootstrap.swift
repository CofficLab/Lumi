import Foundation
import LumiCoreKit

@MainActor
public extension IdleTimePlugin {
    static func bootstrapFromLumiCoreIfNeeded() {
        guard !didBootstrapFromLumiCore else { return }
        IdleTimeRuntimeBridge.directoryURL = LumiCore.pluginDataDirectory(for: "IdleTime")
        didBootstrapFromLumiCore = true
    }
}

enum IdleTimeRuntimeBridge {
    nonisolated(unsafe) static var directoryURL: URL?
}

private nonisolated(unsafe) var didBootstrapFromLumiCore = false
