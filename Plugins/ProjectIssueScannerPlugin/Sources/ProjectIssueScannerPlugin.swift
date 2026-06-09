import LumiCoreKit

/// 空闲时扫描项目问题，并在发送消息时向 LLM 提示已知问题。
public enum ProjectIssueScannerPlugin: LumiPlugin {
    public static let policy: LumiPluginPolicy = .disabled
    public static let category: LumiPluginCategory = .development
    public static let iconName = "scope"

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.project-issue-scanner",
        displayName: "Project Issue Scanner",
        description: "Scans for project issues during idle time and hints them to the LLM.",
        order: 97
    )

    @MainActor
    public static func sendMiddlewares(context: LumiPluginContext) -> [any LumiSendMiddleware] {
        bootstrapFromLumiCoreIfNeeded()
        return [IssueHintChatMiddleware()]
    }
}
