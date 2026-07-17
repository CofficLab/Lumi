import Foundation
import LumiCoreKit

@MainActor
public extension RAGPlugin {
    static func bootstrapRuntime(context: LumiPluginContext) {
        RAGPluginRuntime.lumiCore = context.lumiCore
        let ragDirectory = context.lumiCore?.storage.pluginDataDirectory(for: "RAG") ?? URL(fileURLWithPath: NSTemporaryDirectory())
        RAGPluginRuntime.databaseDirectoryProvider = { ragDirectory }
    }
}
