import Foundation
import LumiKernel

@MainActor
public extension ProjectRAGPlugin {
    static func bootstrapRuntime(kernel: LumiKernel) {
        let core = kernel.lumiCore
        RAGPluginRuntime.lumiCore = core
        let ragDirectory = core?.storage.pluginDataDirectory(for: "RAG") ?? URL(fileURLWithPath: NSTemporaryDirectory())
        RAGPluginRuntime.databaseDirectoryProvider = { ragDirectory }
    }
}
