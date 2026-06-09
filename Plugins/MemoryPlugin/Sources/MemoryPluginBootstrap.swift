import Foundation
import LumiCoreKit

@MainActor
public extension MemoryPlugin {
    static func bootstrapFromLumiCoreIfNeeded() {
        guard !didBootstrapFromLumiCore else { return }

        let defaultRoot = MemoryPluginConfig.default.memoryRootURL.standardizedFileURL
        if config.memoryRootURL.standardizedFileURL != defaultRoot {
            didBootstrapFromLumiCore = true
            return
        }

        MemoryPlugin.config = MemoryPluginConfig(
            memoryRootURL: LumiCore.pluginDataDirectory(for: "Memory")
        )
        didBootstrapFromLumiCore = true
    }
}

private nonisolated(unsafe) var didBootstrapFromLumiCore = false
