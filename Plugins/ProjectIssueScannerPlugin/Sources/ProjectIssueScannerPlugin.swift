import LumiCoreKit
import SwiftUI
import os

/// 空闲时扫描项目问题，并在发送消息时向 LLM 提示已知问题。
public enum ProjectIssueScannerPlugin: LumiPlugin {
    public static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.project-issue-scanner")

    public static let info = LumiPluginInfo(
        id: "com.coffic.lumi.plugin.project-issue-scanner",
        displayName: LumiPluginLocalization.string("Project Issue Scanner", bundle: .module),
        description: LumiPluginLocalization.string("Scans for project issues during idle time and hints them to the LLM.", bundle: .module),
        order: 97,
        category: .development,
        policy: .disabled,
        stage: .beta,
        iconName: "scope",
    )

    @MainActor
    public static func sendMiddlewares(context: LumiPluginContext) -> [any LumiSendMiddleware] {
        bootstrapFromLumiCoreIfNeeded(context: context)
        return [IssueHintChatMiddleware()]
    }

    @MainActor
    public static func aboutView(context: LumiPluginContext) -> AnyView? {
        AnyView(ProjectIssueScannerAboutView())
    }
}
