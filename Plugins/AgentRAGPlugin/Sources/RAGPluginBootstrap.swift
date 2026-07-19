import Foundation
import LumiKernel

@MainActor
public extension RAGPlugin {
    static func bootstrapRuntime(context: any LumiCoreAccessing) {
        RAGPluginRuntime.lumiCore = context.lumiCore
        let ragDirectory = context.lumiCore?.storage.pluginDataDirectory(for: "RAG") ?? URL(fileURLWithPath: NSTemporaryDirectory())
        RAGPluginRuntime.databaseDirectoryProvider = { ragDirectory }
    }
}
