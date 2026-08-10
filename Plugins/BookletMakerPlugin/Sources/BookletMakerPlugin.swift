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
    public var name: String { BookletLocalization.string("PDF Tools") }
    public let order = 880
    public let policy: LumiPluginPolicy = .optIn
    public let stage: LumiPluginStage = .beta

    /// 插件级唯一的 BookletMakerViewModel 实例。
    /// 通过 `viewContainers` 和 `panelRailTabItems` 同时注入，
    /// 让 BookletMakerRailView（侧边栏）与 BookletMakerMainView（内容区）共享同一份
    /// 配置状态，避免"在侧边栏改了设置但内容区没同步"的问题。
    private let sharedViewModel = BookletMakerViewModel()

    public var pluginDescription: String {
        BookletLocalization.string("Create booklets and split PDF documents by page range.")
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
                title: BookletLocalization.string("PDF Tools"),
                systemImage: "doc.on.doc",
                railVisibility: .alwaysVisible,
                chatVisibility: .unsupported,
                panelHeaderVisibility: .unsupported,
                panelBottomVisibility: .unsupported
            ) {
                BookletMakerMainView(viewModel: self.sharedViewModel)
            },
        ]
    }

    // MARK: - About

    public func pluginAboutView(kernel: LumiKernel) -> AnyView? {
        AnyView(BookletMakerAboutView())
    }

    // MARK: - Save Panel

    private func presentSavePanel() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.nameFieldStringValue = suggestedFileName()
        panel.canCreateDirectories = true
        panel.title = BookletLocalization.string("Export Booklet PDF")
        if panel.runModal() == .OK, let url = panel.url {
            Task { await sharedViewModel.export(to: url) }
        }
    }

    private func suggestedFileName() -> String {
        let base = sharedViewModel.currentDocument.baseFileName
        return "\(base)-booklet.pdf"
    }

    private func presentSplitDirectoryPanel() {
        let panel = NSOpenPanel()
        panel.title = BookletLocalization.string("Choose Split PDF Output Folder")
        panel.message = BookletLocalization.string(
            "Each page range will be saved as a separate PDF file."
        )
        panel.prompt = BookletLocalization.string("Choose Folder")
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false

        if panel.runModal() == .OK, let directoryURL = panel.url {
            let didStartSecurityScope = directoryURL.startAccessingSecurityScopedResource()
            Task {
                await sharedViewModel.exportSplit(to: directoryURL)
                if didStartSecurityScope {
                    directoryURL.stopAccessingSecurityScopedResource()
                }
            }
        }
    }

    // MARK: - LumiPlugin Stubs

    public func llmProviders(kernel: LumiKernel) -> [any LumiLLMProvider] { [] }
    public func messageRenderers(kernel: LumiKernel) -> [LumiMessageRendererItem] { [] }
    public func menuBarContentItems(kernel: LumiKernel) -> [LumiMenuBarContentItem] { [] }
    public func menuBarPopupItems(kernel: LumiKernel) -> [LumiMenuBarPopupItem] { [] }
    public func titleToolbarItems(kernel: LumiKernel) -> [LumiTitleToolbarItem] {
        [
            LumiTitleToolbarItem(
                id: "\(id).title",
                title: BookletLocalization.string("拆分PDF或者小册子生成"),
                placement: .center,
                order: 200
            ) {
                BookletMakerToolbarTitleView(
                    containerID: self.id,
                    kernel: kernel,
                    viewModel: self.sharedViewModel
                )
            },
        ]
    }
    public func panelHeaderItems(kernel: LumiKernel) -> [PanelHeaderItem] { [] }
    public func panelBottomTabItems(kernel: LumiKernel) -> [PanelBottomTabItem] { [] }
    public func panelRailTabItems(kernel: LumiKernel) -> [PanelRailTabItem] {
        [
            PanelRailTabItem(
                id: "booklet-maker.sidebar",
                title: BookletLocalization.string("PDF Tools"),
                systemImage: "square.grid.2x2",
                visibility: .viewContainer(id: id)
            ) {
                BookletMakerRailView(
                    viewModel: self.sharedViewModel,
                    onExportBooklet: { self.presentSavePanel() },
                    onExportSplit: { self.presentSplitDirectoryPanel() }
                )
            },
        ]
    }
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
