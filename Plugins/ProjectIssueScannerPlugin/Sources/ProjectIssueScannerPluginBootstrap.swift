import Foundation
import LumiKernel

enum ProjectIssueScannerRuntimeBridge {
    nonisolated(unsafe) static var dataDirectory: URL?
}

@MainActor
public extension ProjectIssueScannerPlugin {
    static func bootstrapFromLumiCoreIfNeeded(context: any LumiCoreAccessing) {
        guard !didBootstrapFromLumiCore else { return }
        if let lumiCore = context.lumiCore {
            ProjectIssueScannerRuntimeBridge.dataDirectory = lumiCore.storage.pluginDataDirectory(for: "ProjectIssueScanner")
        }
        didBootstrapFromLumiCore = true
    }
}

private nonisolated(unsafe) var didBootstrapFromLumiCore = false
