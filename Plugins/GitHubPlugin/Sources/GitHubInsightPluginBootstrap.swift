import Foundation
import LumiKernel

enum GitHubInsightRuntimeBridge {
    nonisolated(unsafe) static var rootDirectory: URL?
}

@MainActor
public extension GitHubPlugin {
    static func bootstrapFromLumiCoreIfNeeded(context: any LumiCoreAccessing) {
        guard !didBootstrapFromLumiCore else { return }
        if let core = context.lumiCore {
            GitHubInsightRuntimeBridge.rootDirectory = core.storage.pluginDataDirectory(for: "GitHubInsight")
            didBootstrapFromLumiCore = true
        }
    }
}

private nonisolated(unsafe) var didBootstrapFromLumiCore = false
