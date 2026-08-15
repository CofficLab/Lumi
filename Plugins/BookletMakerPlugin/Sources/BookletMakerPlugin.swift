import Foundation
import KernelLumi
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

    /// 本插件 rail 面板的稳定标识（注册为 `PanelRailTabItem.id`）。
    public nonisolated static let railTabID = "booklet-maker.sidebar"

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

    public func onBoot(kernel: KernelLumi) async throws {
        BookletMakerRuntimeBridge.directoryURL = kernel.storage?
            .pluginDataDirectory(for: "BookletMaker")
        if Self.verbose {
            Self.logger.info(
                "📖 BookletMakerPlugin booted, stagingDir = \(BookletMakerRuntimeBridge.directoryURL?.path ?? "<unavailable>")"
            )
        }
    }

    public func onReady(kernel: KernelLumi) async throws {}

    // MARK: - View Container

    /// Contribute one view container that fills the entire workspace.
    public func viewContainers(kernel: KernelLumi) -> [ViewContainerItem] {
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

    public func pluginAboutView(kernel: KernelLumi) -> AnyView? {
        AnyView(BookletMakerAboutView())
    }

    public func pluginManualView(kernel: KernelLumi) -> AnyView? {
        AnyView(BookletMakerManualView())
    }

    // MARK: - Save Panel

    private func presentSavePanel() {
        #if os(macOS)
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.nameFieldStringValue = suggestedFileName()
        panel.canCreateDirectories = true
        panel.title = BookletLocalization.string("Export Booklet PDF")
        if panel.runModal() == .OK, let url = panel.url {
            Task { await sharedViewModel.export(to: url) }
        }
        #else
        // iOS: 生成到临时文件后弹出系统分享面板（保存到「文件」/ 分享）。
        Task { @MainActor in
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent(suggestedFileName())
            try? FileManager.default.removeItem(at: url)
            await sharedViewModel.export(to: url)
            SharePresenter.share(fileURL: url)
        }
        #endif
    }

    private func suggestedFileName() -> String {
        let base = sharedViewModel.currentDocument.baseFileName
        return "\(base)-booklet.pdf"
    }

    private func presentSplitDirectoryPanel() {
        #if os(macOS)
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
        #else
        // iOS: 拆分到临时目录后用分享面板导出。
        Task { @MainActor in
            let dir = FileManager.default.temporaryDirectory
                .appendingPathComponent("booklet-split-\(UUID().uuidString)", isDirectory: true)
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            await sharedViewModel.exportSplit(to: dir)
            SharePresenter.share(fileURL: dir)
        }
        #endif
    }

    // MARK: - LumiPlugin Stubs

    public func llmProviders(kernel: KernelLumi) -> [any LumiLLMProvider] { [] }
    public func messageRenderers(kernel: KernelLumi) -> [LumiMessageRendererItem] { [] }
    public func menuBarContentItems(kernel: KernelLumi) -> [LumiMenuBarContentItem] { [] }
    public func menuBarPopupItems(kernel: KernelLumi) -> [LumiMenuBarPopupItem] { [] }
    public func titleToolbarItems(kernel: KernelLumi) -> [LumiTitleToolbarItem] {
        [
            LumiTitleToolbarItem(
                id: "\(id).title",
                title: BookletLocalization.string("Split PDF or Booklet Maker"),
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
    public func panelHeaderItems(kernel: KernelLumi) -> [PanelHeaderItem] { [] }
    public func panelBottomTabItems(kernel: KernelLumi) -> [PanelBottomTabItem] { [] }
    public func panelRailTabItems(kernel: KernelLumi) -> [PanelRailTabItem] {
        [
            PanelRailTabItem(
                id: Self.railTabID,
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
    public func statusBarItems(kernel: KernelLumi) -> [StatusBarItem] { [] }
    public func chatSectionItems(kernel: KernelLumi) -> [ChatSectionItem] { [] }
    public func chatSectionToolbarItems(kernel: KernelLumi) -> [ChatSectionToolbarItem] { [] }
    public func chatSectionToolbarBarItems(kernel: KernelLumi) -> [ChatSectionToolbarBarItem] { [] }
    public func chatSectionHeaderItems(kernel: KernelLumi) -> [ChatSectionHeaderItem] { [] }
    public func chatSectionActionBarItems(kernel: KernelLumi) -> [ChatSectionActionBarItem] { [] }
    public func chatSectionRootWrapper(kernel: KernelLumi, content: AnyView) -> AnyView { content }
    public func settingsTabItems(kernel: KernelLumi) -> [SettingsTabItem] { [] }
    public func addSettingsView(kernel: KernelLumi) -> [AnyView] { [] }
    public func llmProviderSettingsItems(kernel: KernelLumi) -> [LLMProviderSettingsItem] { [] }
    public func llmProviderSettingsViews(kernel: KernelLumi) -> [LumiLLMProviderSettingsViewItem] { [] }
    public func rootOverlays(kernel: KernelLumi) -> [LumiRootOverlayItem] { [] }
    public func onboardingPages(kernel: KernelLumi) -> [OnboardingPageItem] { [] }
    public func logoItems(kernel: KernelLumi) -> [LogoItem] { [] }
    public func onTurnFinished(kernel: KernelLumi, conversationID: UUID, reason: LumiTurnEndReason) async {}
    public func onContainerActivated(kernel: KernelLumi, containerID: String) {}
    public func registerEditorExtensions(into registry: AnyObject, kernel: KernelLumi) async {}
    public func configureEditorRuntime(kernel: KernelLumi) async {}
    public func agentTools(kernel: KernelLumi) -> [any LumiAgentTool] { [] }
}
