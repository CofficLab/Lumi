import SwiftUI
import LumiKernel
import LumiUI
import os
import SuperLogKit

@MainActor
public final class GitHubPlugin: LumiPlugin, SuperLog {
    public nonisolated static let emoji = "🐙"
    public nonisolated static let verbose: Bool = false
    public nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi",
        category: "plugin.github"
    )

    public let id = "com.coffic.lumi.plugin.github"
    public let name = "GitHub"
    public let order = 16
    public let policy: LumiPluginPolicy = .optOut
    public let category: LumiPluginCategory = .agent
    public let stage: LumiPluginStage = .stable
    public let pluginDescription = "GitHub integration for issues, repos, and code search."

    public init() {}

    public func onBoot(kernel: LumiKernel) async throws {}

    public func onReady(kernel: LumiKernel) async throws {
        // 设置插件数据目录
        guard let storage = kernel.storage else {
            Self.logger.error("🐙 Storage service not available")
            return
        }
        GitHubInsightRuntimeBridge.rootDirectory = storage.pluginDataDirectory(for: "GitHubInsight")

        // 设置 LocalStore 的数据库目录（预先计算 URL 以避免 Sendable 问题）
        let pluginDataDir = storage.pluginDataDirectory(for: "GitHubPlugin")
        GitHubPluginLocalStore.dbFolderURLProvider = {
            pluginDataDir
        }

        if Self.verbose {
            Self.logger.info("🐙 GitHub 插件初始化完成")
        }
    }


    // MARK: - LumiPlugin stubs

    public func llmProviders(kernel: LumiKernel) -> [any LumiLLMProvider] { [] }
    public func subAgents(kernel: LumiKernel) -> [LumiSubAgentDefinition] { [] }
    public func messageRenderers(kernel: LumiKernel) -> [LumiMessageRendererItem] { [] }
    public func menuBarContentItems(kernel: LumiKernel) -> [LumiMenuBarContentItem] { [] }
    public func menuBarPopupItems(kernel: LumiKernel) -> [LumiMenuBarPopupItem] { [] }
    public func titleToolbarItems(kernel: LumiKernel) -> [LumiTitleToolbarItem] { [] }
    public func panelHeaderItems(kernel: LumiKernel) -> [PanelHeaderItem] { [] }
    public func panelBottomTabItems(kernel: LumiKernel) -> [PanelBottomTabItem] { [] }
    public func panelRailTabItems(kernel: LumiKernel) -> [PanelRailTabItem] { [] }
    public func statusBarItems(kernel: LumiKernel) -> [StatusBarItem] { [] }
    public func viewContainers(kernel: LumiKernel) -> [ViewContainerItem] { [] }
    public func chatSectionItems(kernel: LumiKernel) -> [ChatSectionItem] { [] }
    public func chatSectionToolbarItems(kernel: LumiKernel) -> [ChatSectionToolbarItem] { [] }
    public func chatSectionToolbarBarItems(kernel: LumiKernel) -> [ChatSectionToolbarBarItem] { [] }
    public func chatSectionHeaderItems(kernel: LumiKernel) -> [ChatSectionHeaderItem] { [] }
    public func chatSectionActionBarItems(kernel: LumiKernel) -> [ChatSectionActionBarItem] { [] }
    public func chatSectionRootWrapper(kernel: LumiKernel, content: AnyView) -> AnyView { content }
    public func settingsTabItems(kernel: LumiKernel) -> [SettingsTabItem] { [] }
    public func addSettingsView(kernel: LumiKernel) -> [AnyView] { [] }
    public func pluginAboutView(kernel: LumiKernel) -> AnyView? {
        AnyView(GitHubPluginAboutView())
    }
    public func llmProviderSettingsItems(kernel: LumiKernel) -> [LLMProviderSettingsItem] { [] }
    public func llmProviderSettingsViews(kernel: LumiKernel) -> [LumiLLMProviderSettingsViewItem] { [] }
    public func rootOverlays(kernel: LumiKernel) -> [LumiRootOverlayItem] { [] }
    public func onboardingPages(kernel: LumiKernel) -> [OnboardingPageItem] { [] }
    public func logoItems(kernel: LumiKernel) -> [LogoItem] { [] }
    public func onTurnFinished(kernel: LumiKernel, conversationID: UUID, reason: LumiTurnEndReason) async {}
    public func onContainerActivated(kernel: LumiKernel, containerID: String) {}
    public func registerEditorExtensions(into registry: AnyObject, kernel: LumiKernel) async {}
    public func configureEditorRuntime(kernel: LumiKernel) async {}
}
