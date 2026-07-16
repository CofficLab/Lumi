import Foundation
import LumiCoreKit

/// Memory Plugin：持久化记忆系统。
public enum MemoryPlugin: LumiPlugin {
    public static var verbose: Bool { false }

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.memory",
        displayName: PluginMemoryLocalization.string("Memory"),
        description: PluginMemoryLocalization.string("Persistent memory system for cross-session context"),
        order: 15,
        category: .agent,
        policy: .alwaysOn,
        stage: .beta,
        iconName: "brain.head.profile",
    )

    nonisolated(unsafe) public static var config: MemoryPluginConfig = .default

    @MainActor
    public static func sendMiddlewares(context: LumiPluginContext) -> [any LumiSendMiddleware] {
        Self.bootstrapFromLumiCoreIfNeeded(context: context)
        return [MemoryChatMiddleware()]
    }

    @MainActor
    public static func agentTools(context: LumiPluginContext) -> [any LumiAgentTool] {
        Self.bootstrapFromLumiCoreIfNeeded(context: context)
        return [
            SaveMemoryTool(),
            RecallMemoryTool(),
            ListMemoriesTool(),
            DeleteMemoryTool()
        ]
    }
}

enum PluginMemoryLocalization {
    static let table = "Localizable"
    static let bundle = Bundle.module

    static func string(_ key: String) -> String {
        LumiPluginLocalization.string(key, bundle: Bundle.module, table: "Localizable")
    }
}
