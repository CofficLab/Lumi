import Foundation
import LumiKernel

@MainActor
public extension ProjectRAGPlugin {
    static func bootstrapRuntime(kernel: LumiKernel) {
        let ragDirectory = kernel.storage?.pluginDataDirectory(for: "RAG")
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        RAGPluginRuntime.databaseDirectoryProvider = { ragDirectory }
    }
}
