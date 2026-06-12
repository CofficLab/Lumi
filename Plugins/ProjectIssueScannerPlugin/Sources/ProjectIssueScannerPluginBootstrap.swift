import Foundation
import LumiCoreKit

enum ProjectIssueScannerRuntimeBridge {
    nonisolated(unsafe) static var dataDirectory: URL?
}

@MainActor
public extension ProjectIssueScannerPlugin {
    static func bootstrapFromLumiCoreIfNeeded() {
        guard !didBootstrapFromLumiCore else { return }
        ProjectIssueScannerRuntimeBridge.dataDirectory = LumiCore.pluginDataDirectory(for: "ProjectIssueScanner")
        didBootstrapFromLumiCore = true
    }
}

private nonisolated(unsafe) var didBootstrapFromLumiCore = false
