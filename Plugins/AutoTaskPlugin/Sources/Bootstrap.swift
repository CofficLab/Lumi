import Foundation
import LumiCoreKit

@MainActor
public extension AutoTaskPlugin {
    static func bootstrapFromLumiCoreIfNeeded(context: LumiPluginContext) {
        guard !didBootstrapFromLumiCore else { return }

        configuration = LumiCoreConfiguration(
            rootURL: context.lumiCore?.pluginDataDirectory(for: "AutoTask") ?? URL(fileURLWithPath: NSTemporaryDirectory())
        )
        didBootstrapFromLumiCore = true
    }

    static func bootstrapTurnCheck(chatServiceProvider: @escaping @MainActor () -> (any LumiChatServicing)?, context: LumiPluginContext) {
        bootstrapFromLumiCoreIfNeeded(context: context)
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
