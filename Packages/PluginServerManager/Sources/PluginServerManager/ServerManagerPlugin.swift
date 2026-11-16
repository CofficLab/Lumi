import KernelCore
import KitAgentTool
import LumiLoggingKit
import os
import ProviderActivityBar
import ProviderChatSection
import ProviderContentView
import ProviderDocsView
import ProviderRailView
import ProviderRootView
import ProviderStorage
import ProviderToolbar
import ProviderToolManager
import SwiftUI

/// 服务器管理插件：通过 SSH 管理远程服务器。
///
/// 贡献：
/// - ActivityBar 入口 + Rail 服务器列表 + 主内容（概览 / 进程 / 容器 / 控制台）；
/// - Docs 关于 / 说明书；
/// - Agent 工具 `server_list` / `server_status` / `server_processes`（只读），
///   `server_container` / `server_exec`（写操作高风险且需显式批准）。
///
/// 生命周期对照 `DiskManagerPlugin`：onBoot 注册、onDisable/onShutdown
/// 对称撤回（含 Agent 工具，避免禁用后仍可被 LLM 调用）。
@MainActor
public final class ServerManagerPlugin: SuperPlugin, SuperLog {
    public let id = "com.coffic.lumi.plugin.server-manager"
    public let order = 260
    public let metadata = PluginMetadata(
        id: "com.coffic.lumi.plugin.server-manager",
        name: ServerManagerLocalization.string("Server Manager"),
        description: ServerManagerLocalization.string("Manage remote servers over SSH."),
        version: "0.1.0",
        category: .integration,
        stage: .preview,
        policy: .disabledByDefault,
        permissions: [
            PluginPermission(
                id: "network.ssh",
                reason: "Connect to configured servers over SSH to read status and run commands."
            ),
        ]
    )

    public static let railTabID = "com.coffic.lumi.plugin.server-manager.servers"

    public nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "plugin.server-manager")
    public nonisolated static var verbose: Bool { false }

    private var backend: ServerBackend?
    private var viewModel: ServerManagerViewModel?
    private var agentTools: [any SuperAgentTool] = []
    private var areAgentToolsRegistered = false

    public init() {}

    // MARK: - SuperPlugin

    public func onRegister(kernel: KernelCoreContainer) throws {
        if let docs = kernel.resolveProvider((any DocsViewProviding).self) {
            docs.addAbout(DocsEntry(id: id, name: metadata.name) { ServerAboutView() })
            docs.addManual(DocsEntry(id: id, name: metadata.name) { ServerManualView() })
        }
    }

    public func onBoot(kernel: KernelCoreContainer) throws {
        guard let storage = kernel.resolveProvider((any StorageProviding).self) else {
            Self.logger.error("Failed to resolve StorageProviding; server list will not persist")
            return
        }
        let backend = ServerBackend(directory: storage.pluginDataDirectory(for: id))
        let viewModel = ServerManagerViewModel(backend: backend)
        self.backend = backend
        self.viewModel = viewModel
        self.agentTools = [
            ServerListTool(backend: backend),
            ServerStatusTool(backend: backend),
            ServerProcessesTool(backend: backend),
            ServerContainerTool(backend: backend),
            ServerExecTool(backend: backend),
        ]

        registerAgentTools(kernel: kernel)

        let contentView = kernel.resolveProvider((any ContentViewProviding).self)
        let chat = kernel.resolveProvider((any ChatSectionProviding).self)
        let railView = kernel.resolveProvider((any RailViewProviding).self)
        let rootView = kernel.resolveProvider((any RootViewProviding).self)
        let toolbar = kernel.resolveProvider((any ToolbarProviding).self)
        let pluginID = id
        let railWidthStore = FileRailViewWidthStore(
            fileURL: storage
                .pluginDataDirectory(for: pluginID)
                .appendingPathComponent("rail-view-width.plist", isDirectory: false)
        )

        // 先注册 Rail，再注册 ActivityBar，确保首次激活回调能找到贡献。
        railView?.addTabs([
            RailTabItem(
                id: Self.railTabID,
                category: .system,
                title: ServerManagerLocalization.string("Servers"),
                systemImage: "server.rack",
                order: order
            ) {
                ServerSidebarView(viewModel: viewModel)
            },
        ])

        if let activityBar = kernel.resolveProvider((any ActivityBarProviding).self) {
            let entryID = "\(id).entry"
            activityBar.addItems([
                ActivityBarItem(
                    id: entryID,
                    title: metadata.name,
                    systemImage: "server.rack",
                    order: order,
                    ownerPluginID: id
                ) { state in
                    if state == .activated {
                        toolbar?.setVisibleCategories([.global, .system])
                        railView?.setVisibleCategories([.system])
                        railView?.setVisibleTabID(Self.railTabID)
                        rootView?.setRailViewVisible(railView?.hasVisibleTabs ?? false)
                        railView?.activateWidthProfile(
                            ownerID: pluginID,
                            recommended: RailViewWidth(minWidth: 220, idealWidth: 280, maxWidth: 420),
                            store: railWidthStore
                        )
                        chat?.setVisible(false)
                        rootView?.setContentHeaderViewHidden(true)
                        contentView?.setContentView(AnyView(
                            ServerManagerView(viewModel: viewModel)
                        ))
                    } else {
                        toolbar?.setVisibleCategories(Set(ToolbarItemCategory.allCases))
                        chat?.setVisible(true)
                        rootView?.setContentHeaderViewHidden(false)
                        railView?.setVisibleCategories(Set(RailViewCategory.allCases))
                        rootView?.setRailViewVisible(railView?.hasVisibleTabs ?? false)
                        railView?.deactivateWidthProfile(ownerID: pluginID)
                    }
                },
            ])
        } else {
            // 无 ActivityBar 的精简宿主直接展示主内容。
            contentView?.setContentView(AnyView(
                ServerManagerView(viewModel: viewModel)
            ))
        }
    }

    public func onEnable(kernel: KernelCoreContainer) async throws {
        registerAgentTools(kernel: kernel)
    }

    public func onDisable(kernel: KernelCoreContainer) async throws {
        unregisterAgentTools(kernel: kernel)
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        unregisterAgentTools(kernel: kernel)

        kernel.resolveProvider((any RailViewProviding).self)?
            .removeTabs(ids: [Self.railTabID])

        let activityBar = kernel.resolveProvider((any ActivityBarProviding).self)
        let wasActive = activityBar?.activeItemID == "\(id).entry"
        activityBar?.removeItems(ids: ["\(id).entry"])
        if wasActive {
            kernel.resolveProvider((any RailViewProviding).self)?.deactivateWidthProfile(ownerID: id)
            kernel.resolveProvider((any ChatSectionProviding).self)?.setVisible(true)
            kernel.resolveProvider((any RootViewProviding).self)?.setContentHeaderViewHidden(false)
            kernel.resolveProvider((any RailViewProviding).self)?.setVisibleCategories(Set(RailViewCategory.allCases))
            let railView = kernel.resolveProvider((any RailViewProviding).self)
            kernel.resolveProvider((any RootViewProviding).self)?.setRailViewVisible(railView?.hasVisibleTabs ?? false)
        }
        if activityBar == nil || activityBar?.activeItemID == nil {
            kernel.resolveProvider((any ContentViewProviding).self)?.setContentView(nil)
        }

        backend = nil
        viewModel = nil
        agentTools = []
    }

    public func onUnregister(kernel: KernelCoreContainer) throws {
        kernel.resolveProvider((any DocsViewProviding).self)?.removeEntries(id: id)
    }

    // MARK: - Agent Tools

    private func registerAgentTools(kernel: KernelCoreContainer) {
        guard !areAgentToolsRegistered else { return }
        guard let toolManager = kernel.resolveProvider((any ToolManagerProviding).self) else { return }
        areAgentToolsRegistered = true
        for tool in agentTools {
            toolManager.add(tool, pluginID: id)
        }
    }

    private func unregisterAgentTools(kernel: KernelCoreContainer) {
        guard areAgentToolsRegistered else { return }
        areAgentToolsRegistered = false
        guard let toolManager = kernel.resolveProvider((any ToolManagerProviding).self) else { return }
        for tool in agentTools {
            toolManager.remove(id: tool.name)
        }
    }
}