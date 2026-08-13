import SwiftUI
import KernelLumi
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
    public var name: String {
        LumiPluginLocalization.string("GitHub", bundle: .module)
    }
    public let order = 16
    public let policy: LumiPluginPolicy = .optIn
    public let category: LumiPluginCategory = .agent
    public let stage: LumiPluginStage = .beta
    public var pluginDescription: String {
        LumiPluginLocalization.string("GitHub integration for issues, repos, and code search.", bundle: .module)
    }

    public init() {}

    public func onBoot(kernel: KernelLumi) async throws {}

    public func onReady(kernel: KernelLumi) async throws {
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

    public func llmProviders(kernel: KernelLumi) -> [any LumiLLMProvider] { [] }
    public func messageRenderers(kernel: KernelLumi) -> [LumiMessageRendererItem] { [] }
    public func menuBarContentItems(kernel: KernelLumi) -> [LumiMenuBarContentItem] { [] }
    public func menuBarPopupItems(kernel: KernelLumi) -> [LumiMenuBarPopupItem] { [] }
    public func titleToolbarItems(kernel: KernelLumi) -> [LumiTitleToolbarItem] { [] }
    public func panelHeaderItems(kernel: KernelLumi) -> [PanelHeaderItem] { [] }
    public func panelBottomTabItems(kernel: KernelLumi) -> [PanelBottomTabItem] { [] }
    public func panelRailTabItems(kernel: KernelLumi) -> [PanelRailTabItem] { [] }
    public func statusBarItems(kernel: KernelLumi) -> [StatusBarItem] { [] }
    public func viewContainers(kernel: KernelLumi) -> [ViewContainerItem] { [] }
    public func chatSectionItems(kernel: KernelLumi) -> [ChatSectionItem] { [] }
    public func chatSectionToolbarItems(kernel: KernelLumi) -> [ChatSectionToolbarItem] { [] }
    public func chatSectionToolbarBarItems(kernel: KernelLumi) -> [ChatSectionToolbarBarItem] { [] }
    public func chatSectionHeaderItems(kernel: KernelLumi) -> [ChatSectionHeaderItem] { [] }
    public func chatSectionActionBarItems(kernel: KernelLumi) -> [ChatSectionActionBarItem] { [] }
    public func chatSectionRootWrapper(kernel: KernelLumi, content: AnyView) -> AnyView { content }
    public func settingsTabItems(kernel: KernelLumi) -> [SettingsTabItem] { [] }
    public func addSettingsView(kernel: KernelLumi) -> [AnyView] { [] }
    public func pluginAboutView(kernel: KernelLumi) -> AnyView? {
        AnyView(GitHubPluginAboutView())
    }
    public func llmProviderSettingsItems(kernel: KernelLumi) -> [LLMProviderSettingsItem] { [] }
    public func llmProviderSettingsViews(kernel: KernelLumi) -> [LumiLLMProviderSettingsViewItem] { [] }
    public func rootOverlays(kernel: KernelLumi) -> [LumiRootOverlayItem] { [] }
    public func onboardingPages(kernel: KernelLumi) -> [OnboardingPageItem] { [] }
    public func logoItems(kernel: KernelLumi) -> [LogoItem] { [] }
    public func onTurnFinished(kernel: KernelLumi, conversationID: UUID, reason: LumiTurnEndReason) async {}
    public func onContainerActivated(kernel: KernelLumi, containerID: String) {}
    public func registerEditorExtensions(into registry: AnyObject, kernel: KernelLumi) async {}
    public func configureEditorRuntime(kernel: KernelLumi) async {}
}
