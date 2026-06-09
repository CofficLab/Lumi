import Foundation
import LumiCoreKit

enum GitHubInsightRuntimeBridge {
    nonisolated(unsafe) static var rootDirectory: URL?
}

@MainActor
public extension GitHubPlugin {
    static func bootstrapFromLumiCoreIfNeeded() {
        guard !didBootstrapFromLumiCore else { return }
        GitHubInsightRuntimeBridge.rootDirectory = LumiCore.pluginDataDirectory(for: "GitHubInsight")
        didBootstrapFromLumiCore = true
    }
}

private nonisolated(unsafe) var didBootstrapFromLumiCore = false
