import AgentToolKit
import LibGit2Swift
import LumiCoreKit
import SwiftUI
import SuperLogKit
import os

/// Git plugin: panel, commit history, status bar, and agent tools.
public enum GitPlugin: LumiPlugin, SuperLog {
    public static let policy: LumiPluginPolicy = .alwaysOn
    public static let stage: LumiPluginStage = .beta
    public static let category: LumiPluginCategory = .development
    public static let iconName = "arrow.triangle.branch"
    public static var verbose: Bool { false }
    public static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.git")

    public static let info = LumiPluginInfo(
        id: "GitPlugin",
        displayName: LumiPluginLocalization.string("Git", bundle: .module),
        description: String(
            localized: "Git version control panel, commit history, status bar, and agent tools.",
            bundle: .module
        ),
        order: 11
    )

    public static var id: String { info.id }
    public static var displayName: String { info.displayName }
    public static var order: Int { info.order }

    @MainActor
    public static func bootstrap(
        chatServiceProvider: @escaping @MainActor () -> (any LumiChatServicing)?
    ) {
        LibGit2.initialize()
        GitRuntimeBridge.chatServiceProvider = chatServiceProvider
    }

    @MainActor
    public static func agentTools(context: LumiPluginContext) -> [any LumiAgentTool] {
        [
            GitStatusTool().asLumiAgentTool(),
            GitDiffTool().asLumiAgentTool(),
            GitLogTool().asLumiAgentTool(),
            GitCommitTool().asLumiAgentTool(),
            GitShowTool().asLumiAgentTool(),
            GitBranchTool().asLumiAgentTool(),
            GitUnpushedTool().asLumiAgentTool(),
        ]
    }

    @MainActor
    public static func viewContainers(context: LumiPluginContext) -> [LumiViewContainerItem] {
        guard let projectPathStore = context.resolve(LumiCurrentProjectPathStoring.self) as? LumiCurrentProjectPathStore else {
            return []
        }

        return [
            LumiViewContainerItem(
                id: info.id,
                title: info.displayName,
                systemImage: iconName
            ) {
                GitPanelHostView(projectPathStore: projectPathStore)
            }
        ]
    }

    @MainActor
    public static func statusBarItems(context: LumiPluginContext) -> [LumiStatusBarItem] {
        guard context.activeSectionID == info.id else { return [] }

        return [
            LumiStatusBarItem(
                id: "\(info.id).branch",
                title: "Git Branch",
                systemImage: iconName,
                placement: .trailing,
                statusBarView: {
                    GitPluginStatusBarView()
                }
            )
        ]
    }

    @MainActor
    public static func rootOverlays(context: LumiPluginContext) -> [LumiRootOverlayItem] {
        guard let projectPathStore = context.resolve(LumiCurrentProjectPathStoring.self) as? LumiCurrentProjectPathStore else {
            return []
        }

        return [
            LumiRootOverlayItem(id: "\(info.id).commit-history", order: info.order) { content in
                GitPanelRootOverlay(content: content, projectPathStore: projectPathStore)
            }
        ]
    }
}
