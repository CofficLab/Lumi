import Foundation
import LumiKernel
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

    public func onBoot(kernel: LumiKernel) async throws {}

    public func onReady(kernel: LumiKernel) async throws {
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

    public func viewContainers(kernel: LumiKernel) -> [ViewContainerItem] {
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

    public func panelRailTabItems(kernel: LumiKernel) -> [PanelRailTabItem] {
        [
            PanelRailTabItem(
                id: "\(id).outline",
                title: LumiPluginLocalization.string("Story Outline"),
                systemImage: "list.bullet.rectangle.portrait",
                visibility: .viewContainer(id: id)
            ) {
                StoryOutlineRootView()
            },
        ]
    }

    public func agentTools(kernel: LumiKernel) -> [any LumiAgentTool] {
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

    public func llmProviders(kernel: LumiKernel) -> [any LumiLLMProvider] { [] }
    public func messageRenderers(kernel: LumiKernel) -> [LumiMessageRendererItem] { [] }
    public func menuBarContentItems(kernel: LumiKernel) -> [LumiMenuBarContentItem] { [] }
    public func menuBarPopupItems(kernel: LumiKernel) -> [LumiMenuBarPopupItem] { [] }
    public func titleToolbarItems(kernel: LumiKernel) -> [LumiTitleToolbarItem] { [] }
    public func panelHeaderItems(kernel: LumiKernel) -> [PanelHeaderItem] { [] }
    public func panelBottomTabItems(kernel: LumiKernel) -> [PanelBottomTabItem] { [] }
    public func statusBarItems(kernel: LumiKernel) -> [StatusBarItem] { [] }
    public func chatSectionItems(kernel: LumiKernel) -> [ChatSectionItem] { [] }
    public func chatSectionToolbarItems(kernel: LumiKernel) -> [ChatSectionToolbarItem] { [] }
    public func chatSectionToolbarBarItems(kernel: LumiKernel) -> [ChatSectionToolbarBarItem] { [] }
    public func chatSectionHeaderItems(kernel: LumiKernel) -> [ChatSectionHeaderItem] { [] }
    public func chatSectionActionBarItems(kernel: LumiKernel) -> [ChatSectionActionBarItem] { [] }
    public func chatSectionRootWrapper(kernel: LumiKernel, content: AnyView) -> AnyView { content }
    public func settingsTabItems(kernel: LumiKernel) -> [SettingsTabItem] { [] }
    public func addSettingsView(kernel: LumiKernel) -> [AnyView] { [] }
    public func pluginAboutView(kernel: LumiKernel) -> AnyView? { nil }
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
