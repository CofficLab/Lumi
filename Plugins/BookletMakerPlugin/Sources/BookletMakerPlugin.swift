import Foundation
import LumiKernel
import LumiUI
import os
import SuperLogKit
import SwiftUI

// MARK: - Plugin Entry

/// Booklet Maker plugin.
///
/// Provides a view container that lets the user drop a PDF, configure
/// 2-up imposition settings, and export a new PDF that can be printed
/// on A4 paper, folded along the centre line, and stapled into a
/// correctly paginated A5 booklet.
@MainActor
public final class BookletMakerPlugin: LumiPlugin, SuperLog {

    public nonisolated static let emoji = "📖"
    public nonisolated static let verbose: Bool = false
    public nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi",
        category: "plugin.booklet-maker"
    )

    // MARK: - Identity

    public let id = "com.coffic.lumi.plugin.booklet-maker"
    public var name: String { BookletLocalization.string("Booklet Maker") }
    public let order = 880
    public let policy: LumiPluginPolicy = .optIn

    public var pluginDescription: String {
        BookletLocalization.string(
            "Convert a PDF into a 2-up imposition ready for A4 duplex printing, folding and stapling."
        )
    }

    public init() {}

    // MARK: - Lifecycle

    public func onBoot(kernel: LumiKernel) async throws {
        BookletMakerRuntimeBridge.directoryURL = kernel.storage?
            .pluginDataDirectory(for: "BookletMaker")
        if Self.verbose {
            Self.logger.info(
                "📖 BookletMakerPlugin booted, stagingDir = \(BookletMakerRuntimeBridge.directoryURL?.path ?? "<unavailable>")"
            )
        }
    }

    public func onReady(kernel: LumiKernel) async throws {}

    // MARK: - View Container

    /// Contribute one view container that fills the entire workspace.
    public func viewContainers(kernel: LumiKernel) -> [ViewContainerItem] {
        [
            ViewContainerItem(
                id: id,
                title: BookletLocalization.string("Booklet Maker"),
                systemImage: "book.closed",
                railVisibility: .unsupported,
                chatVisibility: .unsupported,
                panelHeaderVisibility: .unsupported,
                panelBottomVisibility: .unsupported
            ) {
                BookletMakerMainView()
            },
        ]
    }

    // MARK: - About

    public func pluginAboutView(kernel: LumiKernel) -> AnyView? {
        AnyView(BookletMakerAboutView())
    }

    // MARK: - LumiPlugin Stubs

    public func llmProviders(kernel: LumiKernel) -> [any LumiLLMProvider] { [] }
    public func messageRenderers(kernel: LumiKernel) -> [LumiMessageRendererItem] { [] }
    public func menuBarContentItems(kernel: LumiKernel) -> [LumiMenuBarContentItem] { [] }
    public func menuBarPopupItems(kernel: LumiKernel) -> [LumiMenuBarPopupItem] { [] }
    public func titleToolbarItems(kernel: LumiKernel) -> [LumiTitleToolbarItem] { [] }
    public func panelHeaderItems(kernel: LumiKernel) -> [PanelHeaderItem] { [] }
    public func panelBottomTabItems(kernel: LumiKernel) -> [PanelBottomTabItem] { [] }
    public func panelRailTabItems(kernel: LumiKernel) -> [PanelRailTabItem] { [] }
    public func statusBarItems(kernel: LumiKernel) -> [StatusBarItem] { [] }
    public func chatSectionItems(kernel: LumiKernel) -> [ChatSectionItem] { [] }
    public func chatSectionToolbarItems(kernel: LumiKernel) -> [ChatSectionToolbarItem] { [] }
    public func chatSectionToolbarBarItems(kernel: LumiKernel) -> [ChatSectionToolbarBarItem] { [] }
    public func chatSectionHeaderItems(kernel: LumiKernel) -> [ChatSectionHeaderItem] { [] }
    public func chatSectionActionBarItems(kernel: LumiKernel) -> [ChatSectionActionBarItem] { [] }
    public func chatSectionRootWrapper(kernel: LumiKernel, content: AnyView) -> AnyView { content }
    public func settingsTabItems(kernel: LumiKernel) -> [SettingsTabItem] { [] }
    public func addSettingsView(kernel: LumiKernel) -> [AnyView] { [] }
    public func llmProviderSettingsItems(kernel: LumiKernel) -> [LLMProviderSettingsItem] { [] }
    public func llmProviderSettingsViews(kernel: LumiKernel) -> [LumiLLMProviderSettingsViewItem] { [] }
    public func rootOverlays(kernel: LumiKernel) -> [LumiRootOverlayItem] { [] }
    public func onboardingPages(kernel: LumiKernel) -> [OnboardingPageItem] { [] }
    public func logoItems(kernel: LumiKernel) -> [LogoItem] { [] }
    public func onTurnFinished(kernel: LumiKernel, conversationID: UUID, reason: LumiTurnEndReason) async {}
    public func onContainerActivated(kernel: LumiKernel, containerID: String) {}
    public func registerEditorExtensions(into registry: AnyObject, kernel: LumiKernel) async {}
    public func configureEditorRuntime(kernel: LumiKernel) async {}
    public func agentTools(kernel: LumiKernel) -> [any LumiAgentTool] { [] }
}
