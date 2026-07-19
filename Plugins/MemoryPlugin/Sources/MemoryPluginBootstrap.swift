import Foundation
import LumiCoreKit

@MainActor
public extension MemoryPlugin {
    static func bootstrapFromLumiCoreIfNeeded(context: any LumiCoreAccessing) {
        guard !didBootstrapFromLumiCore else { return }

        let defaultRoot = MemoryPluginConfig.default.memoryRootURL.standardizedFileURL
        if config.memoryRootURL.standardizedFileURL != defaultRoot {
            didBootstrapFromLumiCore = true
            return
        }

        if let lumiCore = context.lumiCore {
            MemoryPlugin.config = MemoryPluginConfig(
                memoryRootURL: lumiCore.storage.pluginDataDirectory(for: "Memory")
            )
        }
        didBootstrapFromLumiCore = true
    }
}

private nonisolated(unsafe) var didBootstrapFromLumiCore = false
