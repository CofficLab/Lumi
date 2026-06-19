import Foundation
import LumiCoreKit

@MainActor
public extension RAGPlugin {
    static func bootstrapRuntime() {
        let ragDirectory = LumiCore.pluginDataDirectory(for: "RAG")
        RAGPluginRuntime.databaseDirectoryProvider = { ragDirectory }
    }
}
