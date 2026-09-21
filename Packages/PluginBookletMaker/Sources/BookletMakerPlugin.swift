import Foundation
import KernelCore
import KitAgentTool
import LumiUI
import os
import ProviderActivityBar
import ProviderChatSection
import ProviderContentView
import ProviderDocsView
import ProviderRailView
import ProviderRootView
import ProviderSkill
import ProviderStorage
import ProviderToolbar
import ProviderToolManager
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
public final class BookletMakerPlugin: SuperPlugin, PluginDataMigrating, SuperLog {
    public nonisolated static let emoji = "📖"
    public nonisolated static let verbose: Bool = false
    public nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi",
        category: "plugin.booklet-maker"
    )

    // MARK: - Identity

    public nonisolated static let pluginID = "com.coffic.lumi.plugin.booklet-maker"
    public let legacyDataDirectoryNames = ["BookletMaker"]

    public let id: String

    /// 本插件 rail 面板的稳定标识（注册为 `PanelRailTabItem.id`）。
    public nonisolated static let railTabID = "booklet-maker.sidebar"

    public let order = 880
    public let metadata: PluginMetadata

    /// 插件级唯一的 BookletMakerViewModel 实例。
    /// 通过 `viewContainers` 和 `panelRailTabItems` 同时注入，
    /// 让 BookletMakerRailView（侧边栏）与 BookletMakerMainView（内容区）共享同一份
    /// 配置状态，避免"在侧边栏改了设置但内容区没同步"的问题。
    private let sharedViewModel = BookletMakerViewModel()

    public var name: String { BookletLocalization.string("Booklet Maker") }

    /// - Parameter policy: 启用策略由宿主决定。Lumi 默认将本插件作为可选功能，
    ///   BookletMaker 专用宿主则以 `.required` 装配它。
    public init(policy: PluginEnablePolicy = .disabledByDefault) {
        id = Self.pluginID
        metadata = PluginMetadata(
            id: Self.pluginID,
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
            .resolveProvider((any ProviderStorage.StorageProviding).self)?
            .pluginDataDirectory(for: id)

        // 向 Agent 贡献 PDF 工具与技能。宿主未装配对应 Provider 时（如
        // iOS 专用宿主、独立测试）降级为仅启动 UI，不阻塞插件生效。
        registerAgentTools(kernel: kernel)
        registerSkill(kernel: kernel)

        if Self.verbose {
            Self.logger.info(
                "📖 BookletMakerPlugin booted, stagingDir = \(BookletMakerRuntimeBridge.directoryURL?.path ?? "<unavailable>")"
            )
        }
        let contentView = kernel.resolveProvider((any ContentViewProviding).self)
        let chat = kernel.resolveProvider((any ChatSectionProviding).self)
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
                    onExportSplit: { self.presentSplitDirectoryPanel() }
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
                        chat?.setVisible(false)
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
                        chat?.setVisible(true)
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
            if panel.runModal() == .OK, let url = panel.url {
                Task { await sharedViewModel.export(to: url) }
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
        #endif
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        unregisterAgentTools(kernel: kernel)
        unregisterSkill(kernel: kernel)

        let activityBar = kernel.resolveProvider((any ActivityBarProviding).self)
        let wasActive = activityBar?.activeItemID == "\(id).entry"
        kernel.resolveProvider((any ContentViewProviding).self)?.setContentView(nil)
        kernel.resolveProvider((any RailViewProviding).self)?.removeTabs(ids: [Self.railTabID])
        activityBar?.removeItems(ids: ["\(id).entry"])
        if wasActive {
            kernel.resolveProvider((any RailViewProviding).self)?.deactivateWidthProfile(ownerID: id)
            kernel.resolveProvider((any ChatSectionProviding).self)?.setVisible(true)
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

    // MARK: - Agent Contribution

    /// 本插件贡献的 Agent 工具。
    ///
    /// 与 App Store Promo Designer 的同名属性对应，供宿主与测试枚举。
    /// `nonisolated`：工具本身是 `Sendable` 值类型，无需主线程隔离。
    public nonisolated static let agentTools: [any SuperAgentTool] = [
        PDFInspectTool(),
        BookletMakeTool(),
        PDFSplitTool(),
        BookletPreviewTool(),
    ]

    /// 注册工具到 `ToolManagerProviding`。未装配该 Provider 时静默跳过：
    /// 工具能力属于增强项，不应让插件在精简宿主中启动失败。
    private func registerAgentTools(kernel: KernelCoreContainer) {
        guard let toolManager = kernel.resolveProvider((any ToolManagerProviding).self) else {
            Self.logger.warning("\(Self.t)ToolManagerProviding not registered; skip agent tools")
            return
        }
        for tool in Self.agentTools {
            toolManager.add(tool, pluginID: id)
        }
        if Self.verbose {
            Self.logger.info("\(Self.t)Contributed \(Self.agentTools.count) agent tool(s)")
        }
    }

    /// 从 `ToolManagerProviding` 撤回本插件的工具。
    private func unregisterAgentTools(kernel: KernelCoreContainer) {
        guard let toolManager = kernel.resolveProvider((any ToolManagerProviding).self) else { return }
        for tool in Self.agentTools {
            toolManager.remove(id: tool.name)
        }
    }

    /// 注册 Skill 贡献者。幂等：同一 providerID 不会重复注册。
    private func registerSkill(kernel: KernelCoreContainer) {
        guard let skillProvider = kernel.resolveProvider((any SkillProviding).self) else {
            Self.logger.warning("\(Self.t)SkillProviding not registered; skip skill contribution")
            return
        }
        guard !skillProvider.isProviderRegistered(providerID: id) else { return }
        let contributor = BookletMakerSkillContributor(providerID: id)
        skillProvider.addProvider(contributor)
        if Self.verbose {
            Self.logger.info("\(Self.t)Contributed \(contributor.allSkills.count) skill(s) via SkillProviding")
        }
    }

    /// 撤回 Skill 贡献，避免插件卸载后残留技能。重复撤销无副作用。
    private func unregisterSkill(kernel: KernelCoreContainer) {
        kernel.resolveProvider((any SkillProviding).self)?.removeProvider(providerID: id)
    }
}
