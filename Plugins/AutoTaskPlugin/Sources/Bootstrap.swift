import Foundation
import LumiCoreKit

@MainActor
public extension AutoTaskPlugin {
    static func bootstrapFromLumiCoreIfNeeded() {
        guard !didBootstrapFromLumiCore else { return }

        configuration = LumiCoreConfiguration(
            rootURL: LumiCore.pluginDataDirectory(for: "AutoTask")
        )
        didBootstrapFromLumiCore = true
    }

    static func bootstrapTurnCheck(chatServiceProvider: @escaping @MainActor () -> (any LumiChatServicing)?) {
        bootstrapFromLumiCoreIfNeeded()
        TurnCheckRuntime.start(chatServiceProvider: chatServiceProvider)
    }
}

private nonisolated(unsafe) var didBootstrapFromLumiCore = false

private struct LumiCoreConfiguration: Configuration {
    let rootURL: URL

    func databaseDirectory() -> URL {
        rootURL
    }
}
