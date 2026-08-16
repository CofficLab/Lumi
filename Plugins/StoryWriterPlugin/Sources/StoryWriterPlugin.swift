import Foundation
import KernelLumi
import os
import SuperLogKit
import SwiftUI

/// Story Writer Plugin
///
/// A two-pane workspace for crafting stories with AI assistance.
/// Registered as an ActivityBar view container.
@MainActor
public final class StoryWriterPlugin: LumiPlugin, SuperLog {
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.story-writer")
    nonisolated public static let emoji = "📖"
    nonisolated static let verbose = false

    public let id = "com.coffic.lumi.plugin.story-writer"

    /// 本插件 rail 面板的稳定标识（注册为 `PanelRailTabItem.id`）。
    public nonisolated static let railTabID = "com.coffic.lumi.plugin.story-writer.outline"

    public var name: String {
        LumiPluginLocalization.string("Story Writer")
    }
    public var pluginDescription: String {
        LumiPluginLocalization.string("A two-pane workspace for crafting stories with AI assistance.")
    }
    public let order = 90
    public let policy: LumiPluginPolicy = .optIn
    public let stage: LumiPluginStage = .beta
    public init() {}

    public func onBoot(kernel: KernelLumi) async throws {}

    public func onReady(kernel: KernelLumi) async throws {
        guard let storage = kernel.storage else {
            Self.logger.error("Storage service not available, skipping StoryWriterPlugin initialization")
            return
        }
        let storageDirectory = storage.pluginDataDirectory(for: "StoryWriter")
        let store = StoryStore(pluginDirectory: storageDirectory)
        let viewModel = StoryWriterViewModel(store: store)
        RuntimeBridge.viewModel = viewModel
        RuntimeBridge.kernel = kernel

        // Initial load
        await viewModel.loadStories()

        if Self.verbose {
            Self.logger.info("StoryWriterPlugin initialized with \(viewModel.stories.count) stories")
        }
    }

    public func viewContainers(kernel: KernelLumi) -> [ViewContainerItem] {
        [
            ViewContainerItem(
                id: id,
                title: name,
                systemImage: "book.closed.fill",
                railVisibility: .alwaysVisible,
                chatVisibility: .alwaysVisible,
                panelHeaderVisibility: .unsupported,
                panelBottomVisibility: .unsupported
            ) {
                StoryWriterRootView()
            },
        ]
    }

    public func panelRailTabItems(kernel: KernelLumi) -> [PanelRailTabItem] {
        [
            PanelRailTabItem(
                id: Self.railTabID,
                title: LumiPluginLocalization.string("Story Outline"),
                systemImage: "list.bullet.rectangle.portrait",
                visibility: .viewContainer(id: id)
            ) {
                StoryOutlineRootView()
            },
        ]
    }

    public func agentTools(kernel: KernelLumi) -> [any LumiAgentTool] {
        [
            // Stories
            ListStoriesTool(),
            GetStoryTool(),
            CreateStoryTool(),
            UpdateStoryTool(),
            DeleteStoryTool(),
            // Chapters
            ListChaptersTool(),
            GetChapterTool(),
            CreateChapterTool(),
            UpdateChapterTool(),
            DeleteChapterTool(),
            // Import / Export
            ImportMarkdownAsChapterTool(),
            ExportStoryAsMarkdownTool(),
        ]
    }

    // MARK: - LumiPlugin stubs

    public func llmProviders(kernel: KernelLumi) -> [any LumiLLMProvider] { [] }
    public func messageRenderers(kernel: KernelLumi) -> [LumiMessageRendererItem] { [] }
    public func menuBarContentItems(kernel: KernelLumi) -> [LumiMenuBarContentItem] { [] }
    public func menuBarPopupItems(kernel: KernelLumi) -> [LumiMenuBarPopupItem] { [] }
    public func titleToolbarItems(kernel: KernelLumi) -> [LumiTitleToolbarItem] { [] }
    public func panelHeaderItems(kernel: KernelLumi) -> [PanelHeaderItem] { [] }
    public func panelBottomTabItems(kernel: KernelLumi) -> [PanelBottomTabItem] { [] }
    public func statusBarItems(kernel: KernelLumi) -> [StatusBarItem] { [] }
    public func chatSectionItems(kernel: KernelLumi) -> [ChatSectionItem] { [] }
    public func chatSectionToolbarItems(kernel: KernelLumi) -> [ChatSectionToolbarItem] { [] }
    public func chatSectionToolbarBarItems(kernel: KernelLumi) -> [ChatSectionToolbarBarItem] { [] }
    public func chatSectionHeaderItems(kernel: KernelLumi) -> [ChatSectionHeaderItem] { [] }
    public func chatSectionActionBarItems(kernel: KernelLumi) -> [ChatSectionActionBarItem] { [] }
    public func chatSectionRootWrapper(kernel: KernelLumi, content: AnyView) -> AnyView { content }
    public func settingsTabItems(kernel: KernelLumi) -> [SettingsTabItem] { [] }
    public func addSettingsView(kernel: KernelLumi) -> [AnyView] { [] }
    public func pluginAboutView(kernel: KernelLumi) -> AnyView? {
        AnyView(StoryWriterAboutView())
    }
    public func pluginManualView(kernel: KernelLumi) -> AnyView? {
        AnyView(StoryWriterManualView())
    }
    public func llmProviderSettingsItems(kernel: KernelLumi) -> [LLMProviderSettingsItem] { [] }
    public func llmProviderSettingsViews(kernel: KernelLumi) -> [LumiLLMProviderSettingsViewItem] { [] }
    public func rootOverlays(kernel: KernelLumi) -> [LumiRootOverlayItem] { [] }
    public func onboardingPages(kernel: KernelLumi) -> [OnboardingPageItem] { [] }
    public func logoItems(kernel: KernelLumi) -> [LogoItem] { [] }
    public func onTurnFinished(kernel: KernelLumi, conversationID: UUID, reason: LumiTurnEndReason) async {}
    public func onContainerActivated(kernel: KernelLumi, containerID: String) {}
}
