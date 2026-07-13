import Foundation
import LumiCoreKit

enum GitHubInsightRuntimeBridge {
    nonisolated(unsafe) static var rootDirectory: URL?
}

@MainActor
public extension GitHubPlugin {
    static func bootstrapFromLumiCoreIfNeeded(context: LumiPluginContext) {
        guard !didBootstrapFromLumiCore else { return }
        if let core = context.lumiCore {
            GitHubInsightRuntimeBridge.rootDirectory = core.pluginDataDirectory(for: "GitHubInsight")
            didBootstrapFromLumiCore = true
        }
    }
}

private nonisolated(unsafe) var didBootstrapFromLumiCore = false
