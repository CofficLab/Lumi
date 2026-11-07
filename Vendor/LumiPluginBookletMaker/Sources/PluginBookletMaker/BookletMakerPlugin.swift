import Foundation
import KernelCore
import LumiUI
import LumiLoggingKit
import os
import ProviderActivityBar
import ProviderContentView
import ProviderDocsView
import ProviderRailView
import ProviderRootView
import ProviderStorage
import ProviderToolbar
import SwiftUI

// MARK: - Plugin Entry

/// Booklet Maker plugin.
///
/// Provides a view container that lets the user drop a PDF, configure
/// 2-up imposition settings, and export a new PDF that can be printed
/// on A4 paper, folded along the centre line, and stapled into a
/// correctly paginated A5 booklet.
///
/// 本包是 Lumi 与 GameFactory 共享的远程插件。宿主差异通过 init 参数注入：
/// 插件不硬编码 pluginID，也不依赖任何宿主专属 Provider
/// （聊天区显隐通过 `onWorkspaceActivate` / `onWorkspaceDeactivate` 闭包由宿主接管）。
@MainActor
public final class BookletMakerPlugin: SuperPlugin, PluginDataMigrating, SuperLog {
    public nonisolated static let emoji = "📖"
    public nonisolated static let verbose: Bool = false
    public nonisolated static let logger = Logger(
        subsystem: "com.coffic.bookletmaker",
        category: "plugin.booklet-maker"
    )

    // MARK: - Identity

    /// 默认插件标识。宿主应在装配时传入自己的 id。
    public nonisolated static let defaultPluginID = "com.coffic.lumi.plugin.booklet-maker"

    public let legacyDataDirectoryNames = ["BookletMaker"]

    public let id: String

    /// 本插件 rail 面板的稳定标识（注册为 `RailTabItem.id`）。
    public nonisolated static let railTabID = "booklet-maker.sidebar"

    public let order: Int
    public let metadata: PluginMetadata

    /// 宿主注入的聊天区显隐钩子。
    ///
    /// Lumi 把 Booklet Maker 作为工作台展示，激活时需要收起聊天区；
    /// GameFactory 的 Booklet Maker 是独立 App，没有聊天区概念。
    /// 宿主传入对应闭包即可，插件本身不感知聊天区实现。
    public typealias VisibilityHook = @MainActor () -> Void

    private let onWorkspaceActivate: VisibilityHook?
    private let onWorkspaceDeactivate: VisibilityHook?

    /// 插件级唯一的 BookletMakerViewModel 实例。
    /// 通过 rail 面板与内容区同时注入，让 BookletMakerRailView（侧边栏）与
    /// BookletMakerMainView（内容区）共享同一份配置状态，
    /// 避免"在侧边栏改了设置但内容区没同步"的问题。
    private let sharedViewModel = BookletMakerViewModel()

    public var name: String { BookletLocalization.string("Booklet Maker") }

    /// 创建议划书插件。
    ///
    /// - Parameters:
    ///   - id: 插件唯一标识，决定 `PluginMetadata.id` 与插件数据目录名。
    ///     两个宿主各用各的命名空间，互不干扰。
    ///   - order: 加载顺序（数值越小越先 `onBoot`）。
    ///   - policy: 启用策略由宿主决定。Lumi 默认将本插件作为可选功能，
    ///     BookletMaker 专用宿主则以 `.required` 装配它。
    ///   - onWorkspaceActivate: 工作台激活时的宿主钩子，Lumi 用于隐藏聊天区。
    ///   - onWorkspaceDeactivate: 工作台退出时的宿主钩子，Lumi 用于恢复聊天区。
    public init(
        id: String = BookletMakerPlugin.defaultPluginID,
        order: Int = 880,
        policy: PluginEnablePolicy = .disabledByDefault,
        onWorkspaceActivate: VisibilityHook? = nil,
        onWorkspaceDeactivate: VisibilityHook? = nil
    ) {
        self.id = id
        self.order = order
        self.onWorkspaceActivate = onWorkspaceActivate
        self.onWorkspaceDeactivate = onWorkspaceDeactivate
        self.metadata = PluginMetadata(
            id: id,
            name: BookletLocalization.string("Booklet Maker"),
            description: BookletLocalization.string("Create print-ready booklets from PDF documents."),
            category: .editor,
            stage: .preview,
            policy: policy
        )
    }

    // MARK: - Lifecycle

    public func onRegister(kernel: KernelCoreContainer) throws {
        if let docs = kernel.resolveProvider((any DocsViewProviding).self) {
            docs.addAbout(DocsEntry(id: id, name: name) { BookletMakerAboutView() })
            docs.addManual(DocsEntry(id: id, name: name) { BookletMakerManualView() })
        }
    }

    public func onBoot(kernel: KernelCoreContainer) throws {
        BookletMakerRuntimeBridge.directoryURL = kernel
            .resolveProvider((any StorageProviding).self)?
            .pluginDataDirectory(for: id)

        // 仅在宿主显式打开测试接缝时交出 ViewModel（默认关闭）。
        if BookletMakerTestHooks.isEnabled {
            BookletMakerTestHooks.viewModel = sharedViewModel
            BookletMakerTestHooks.exportDirectoryURL = makeTestExportDirectory()
        }

        if Self.verbose {
            Self.logger.info(
                "\(Self.t)Booted, stagingDir = \(BookletMakerRuntimeBridge.directoryURL?.path ?? "<unavailable>")"
            )
        }
        let contentView = kernel.resolveProvider((any ContentViewProviding).self)
        let railView = kernel.resolveProvider((any RailViewProviding).self)
        let rootView = kernel.resolveProvider((any RootViewProviding).self)
        let toolbar = kernel.resolveProvider((any ToolbarProviding).self)
        let railWidthStore = kernel
            .resolveProvider((any StorageProviding).self)
            .map { storage in
                FileRailViewWidthStore(
                    fileURL: storage
                        .pluginDataDirectory(for: id)
                        .appendingPathComponent("rail-view-width.plist", isDirectory: false)
                )
            }
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
                    onExportSplit: { self.presentSplitDirectoryPanel() },
                    onExportMerge: { self.presentMergeSavePanel() }
                )
            },
        ])

        contentView?.setContentView(AnyView(BookletMakerMainView(viewModel: sharedViewModel)))

        if let activityBar = kernel.resolveProvider((any ActivityBarProviding).self) {
            let entryID = "\(id).entry"
            let pluginID = id
            activityBar.addItems([
                ActivityBarItem(
                    id: entryID,
                    title: name,
                    systemImage: "doc.on.doc",
                    order: order,
                    ownerPluginID: id
                ) { state in
                    if state == .activated {
                        toolbar?.setVisibleCategories([.global, .design])
                        self.onWorkspaceActivate?()
                        railView?.setVisibleCategories([.design])
                        railView?.setVisibleTabID(Self.railTabID)
                        rootView?.setRailViewVisible(railView?.hasVisibleTabs ?? false)
                        railView?.activateWidthProfile(
                            ownerID: pluginID,
                            recommended: RailViewWidth(minWidth: 260, idealWidth: 300, maxWidth: 420),
                            store: railWidthStore
                        )
                        rootView?.setContentHeaderViewHidden(true)
                        contentView?.setContentView(AnyView(BookletMakerMainView(viewModel: self.sharedViewModel)))
                        toolbar?.addToolbarItems([
                            ToolbarItem(
                                id: "\(self.id).title",
                                title: BookletLocalization.string("Split PDF or Booklet Maker"),
                                placement: .center,
                                category: .design,
                                order: 200
                            ) {
                                BookletMakerToolbarTitleView(viewModel: self.sharedViewModel)
                            },
                        ])
                    } else {
                        toolbar?.setVisibleCategories(Set(ToolbarItemCategory.allCases))
                        self.onWorkspaceDeactivate?()
                        rootView?.setContentHeaderViewHidden(false)
                        railView?.setVisibleCategories(Set(RailViewCategory.allCases))
                        rootView?.setRailViewVisible(railView?.hasVisibleTabs ?? false)
                        railView?.deactivateWidthProfile(ownerID: pluginID)
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
            // 界面测试时把保存位置预选到宿主自己的临时目录：宿主未开沙盒，
            // 否则产物会直接落进用户的「文稿」目录，而 XCUITest runner 有
            // 沙盒、事后也清理不掉。
            if let testDirectory = BookletMakerTestHooks.exportDirectoryURL {
                panel.directoryURL = testDirectory
            }
            if panel.runModal() == .OK, let url = panel.url {
                Task { await sharedViewModel.export(to: url) }
            }
        #endif
    }

    /// 界面测试专用的导出目录。
    ///
    /// 放在插件数据目录之下，而非系统临时目录：宿主在测试模式下不开沙盒，
    /// 系统临时目录会解析到用户可见位置，导出产物会直接掉进用户文件夹，
    /// 而 XCUITest runner 有沙盒、事后也清理不掉。
    private func makeTestExportDirectory() -> URL? {
        let base = BookletMakerRuntimeBridge.directoryURL ?? FileManager.default.temporaryDirectory
        let directory = base.appendingPathComponent("ui-test-export", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
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
            // 与保存面板同理：界面测试时把输出目录预选到临时目录，
            // 避免往用户目录里写测试产物。
            if let testDirectory = BookletMakerTestHooks.exportDirectoryURL {
                panel.directoryURL = testDirectory
            }

            if panel.runModal() == .OK, let directoryURL = panel.url {
                let didStartSecurityScope = directoryURL.startAccessingSecurityScopedResource()
                Task {
                    await sharedViewModel.exportSplit(to: directoryURL)
                    if didStartSecurityScope {
                        directoryURL.stopAccessingSecurityScopedResource()
                    }
                }
            }
        #endif
    }

    private func presentMergeSavePanel() {
        #if os(macOS)
            let panel = NSSavePanel()
            panel.allowedContentTypes = [.pdf]
            panel.nameFieldStringValue = suggestedMergeFileName()
            panel.canCreateDirectories = true
            panel.title = BookletLocalization.string("Export Merged PDF")
            if panel.runModal() == .OK, let url = panel.url {
                Task { await sharedViewModel.exportMerge(to: url) }
            }
        #endif
    }

    private func suggestedMergeFileName() -> String {
        let first = sharedViewModel.mergeDocuments.first?.url.deletingPathExtension().lastPathComponent
        return "\(first ?? "merged")-merged.pdf"
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        let activityBar = kernel.resolveProvider((any ActivityBarProviding).self)
        let wasActive = activityBar?.activeItemID == "\(id).entry"
        kernel.resolveProvider((any ContentViewProviding).self)?.setContentView(nil)
        kernel.resolveProvider((any RailViewProviding).self)?.removeTabs(ids: [Self.railTabID])
        activityBar?.removeItems(ids: ["\(id).entry"])
        if wasActive {
            kernel.resolveProvider((any RailViewProviding).self)?.deactivateWidthProfile(ownerID: id)
            onWorkspaceDeactivate?()
            kernel.resolveProvider((any RootViewProviding).self)?.setContentHeaderViewHidden(false)
            let railView = kernel.resolveProvider((any RailViewProviding).self)
            railView?.setVisibleCategories(Set(RailViewCategory.allCases))
            kernel.resolveProvider((any RootViewProviding).self)?.setRailViewVisible(railView?.hasVisibleTabs ?? false)
        }
        kernel.resolveProvider((any ToolbarProviding).self)?.removeToolbarItems(ids: ["\(id).title"])
        BookletMakerRuntimeBridge.directoryURL = nil
    }

    public func onUnregister(kernel: KernelCoreContainer) throws {
        kernel.resolveProvider((any DocsViewProviding).self)?.removeEntries(id: id)
    }
}
