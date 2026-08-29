import Foundation
import KernelCore
import LumiUI
import os
import ProviderActivityBar
import ProviderChatSection
import ProviderContentView
import ProviderDocsView
import ProviderRailView
import ProviderStorage
import ProviderToolbar
import KitSuperLog
import SwiftUI

// MARK: - Plugin Entry

/// Booklet Maker plugin.
///
/// Provides a view container that lets the user drop a PDF, configure
/// 2-up imposition settings, and export a new PDF that can be printed
/// on A4 paper, folded along the centre line, and stapled into a
/// correctly paginated A5 booklet.
@MainActor
public final class BookletMakerPlugin: SuperPlugin, SuperLog {
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

    public let order = 880
    public let metadata = PluginMetadata(
        id: "com.coffic.lumi.plugin.booklet-maker",
        name: "Booklet Maker",
        description: "Create print-ready booklets from PDF documents.",
        category: .editor,
        stage: .preview,
        // BookletMaker 专用宿主只有这一项业务插件，启动时必须可用。
        policy: .alwaysOn
    )

    /// 插件级唯一的 BookletMakerViewModel 实例。
    /// 通过 `viewContainers` 和 `panelRailTabItems` 同时注入，
    /// 让 BookletMakerRailView（侧边栏）与 BookletMakerMainView（内容区）共享同一份
    /// 配置状态，避免"在侧边栏改了设置但内容区没同步"的问题。
    private let sharedViewModel = BookletMakerViewModel()

    public var name: String { BookletLocalization.string("Booklet Maker") }

    public init() {}

    // MARK: - Lifecycle

    public func onRegister(kernel: KernelCoreContainer) throws {
        if let docs = kernel.resolveProvider((any DocsViewProviding).self) {
            docs.addAbout(DocsEntry(id: id, name: name) { BookletMakerAboutView() })
            docs.addManual(DocsEntry(id: id, name: name) { BookletMakerManualView() })
        }
    }

    public func onBoot(kernel: KernelCoreContainer) throws {
        BookletMakerRuntimeBridge.directoryURL = kernel
            .resolveProvider((any ProviderStorage.StorageProviding).self)?
            .pluginDataDirectory(for: "BookletMaker")
        if Self.verbose {
            Self.logger.info(
                "📖 BookletMakerPlugin booted, stagingDir = \(BookletMakerRuntimeBridge.directoryURL?.path ?? "<unavailable>")"
            )
        }
        let contentView = kernel.resolveProvider((any ContentViewProviding).self)
        let chat = kernel.resolveProvider((any ChatSectionProviding).self)
        let railView = kernel.resolveProvider((any RailViewProviding).self)
        let toolbar = kernel.resolveProvider((any ToolbarProviding).self)
        railView?.addTabs([
            RailTabItem(
                id: Self.railTabID,
                category: .design,
                title: name,
                systemImage: "square.grid.2x2",
                order: order
            ) {
                BookletMakerRailView(
                    viewModel: self.sharedViewModel,
                    onExportBooklet: { self.presentSavePanel() },
                    onExportSplit: { self.presentSplitDirectoryPanel() }
                )
            },
        ])

        contentView?.setContentView(AnyView(BookletMakerMainView(viewModel: sharedViewModel)))

        if let activityBar = kernel.resolveProvider((any ActivityBarProviding).self) {
            let entryID = "\(id).entry"
            activityBar.addItems([
                ActivityBarItem(
                    id: entryID,
                    title: name,
                    systemImage: "doc.on.doc",
                    order: order,
                    ownerPluginID: id
                ) { state in
                    if state == .activated {
                        chat?.setVisible(false)
                        railView?.setVisibleTabID(Self.railTabID)
                        contentView?.setContentView(AnyView(BookletMakerMainView(viewModel: self.sharedViewModel)))
                        toolbar?.addToolbarItems([
                            ToolbarItem(
                                id: "\(self.id).title",
                                title: BookletLocalization.string("Split PDF or Booklet Maker"),
                                placement: .center,
                                order: 200
                            ) {
                                BookletMakerToolbarTitleView(viewModel: self.sharedViewModel)
                            },
                        ])
                    } else {
                        chat?.setVisible(true)
                        toolbar?.removeToolbarItems(ids: ["\(self.id).title"])
                    }
                },
            ])
        }
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

    public func onShutdown(kernel: KernelCoreContainer) throws {
        let activityBar = kernel.resolveProvider((any ActivityBarProviding).self)
        let wasActive = activityBar?.activeItemID == "\(id).entry"
        kernel.resolveProvider((any ContentViewProviding).self)?.setContentView(nil)
        kernel.resolveProvider((any RailViewProviding).self)?.removeTabs(ids: [Self.railTabID])
        activityBar?.removeItems(ids: ["\(id).entry"])
        if wasActive {
            kernel.resolveProvider((any ChatSectionProviding).self)?.setVisible(true)
            kernel.resolveProvider((any RailViewProviding).self)?.setVisibleCategories(Set(RailViewCategory.allCases))
        }
        kernel.resolveProvider((any ToolbarProviding).self)?.removeToolbarItems(ids: ["\(id).title"])
        BookletMakerRuntimeBridge.directoryURL = nil
    }

    public func onUnregister(kernel: KernelCoreContainer) throws {
        kernel.resolveProvider((any DocsViewProviding).self)?.removeEntries(id: id)
    }
}
