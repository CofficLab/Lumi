import EditorContracts
import EditorService
import KernelCore
import ProviderActivityBar
import ProviderChatSection
import ProviderDocsView
import ProviderContentView
import ProviderExternalFile
import ProviderRailView
import ProviderRootView
import ProviderToolbar
import ProviderToolManager
import SwiftUI
import os
import KitSuperLog

struct DatabaseManagerPlugin {
    nonisolated static let verbose = false
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi", category: "DatabaseManagerPlugin")
}

/// DatabaseManager 的 KernelCore 入口，复用既有数据库连接、查询与 SQL 编辑体验。
@MainActor
public final class DatabaseManagerSuperPlugin: SuperPlugin, SuperLog {
    public let id = "com.coffic.lumi.plugin.database-manager"
    public let order = 750
    public let metadata = PluginMetadata(
        id: "com.coffic.lumi.plugin.database-manager",
        name: "Database",
        description: "Database connections, SQL queries, schema inspection, and data editing.",
        category: .project,
        stage: .preview,
        policy: .disabledByDefault
    )

    public static let railTabID = "com.coffic.lumi.plugin.database-manager.sidebar"

    private let viewModel = DatabaseViewModel()

    public init() {}

    public func onRegister(kernel: KernelCoreContainer) throws {
        if let docs = kernel.resolveProvider((any DocsViewProviding).self) {
            docs.addAbout(DocsEntry(id: id, name: metadata.name) { AboutView() })
            docs.addManual(DocsEntry(id: id, name: metadata.name) { DatabaseManagerManualView() })
        }
    }

    public func onBoot(kernel: KernelCoreContainer) throws {
        EmbeddedEditorServiceLocator.provider = kernel.resolveProvider(EditorEmbeddedEditorProviding.self)
        if let editor = kernel.resolveProvider(EditorService.self) {
            editor.editorExtensions.registerLanguage(DatabaseSQLLanguageSupport.descriptor)
            editor.editorExtensions.registerGrammarProvider(DatabaseSQLGrammarProvider())
        }
        let contentView = kernel.resolveProvider((any ContentViewProviding).self)
        let chat = kernel.resolveProvider((any ChatSectionProviding).self)
        let railView = kernel.resolveProvider((any RailViewProviding).self)
        let rootView = kernel.resolveProvider((any RootViewProviding).self)
        let toolbar = kernel.resolveProvider((any ToolbarProviding).self)
        railView?.addTabs([
            RailTabItem(
                id: Self.railTabID,
                category: .project,
                title: metadata.name,
                systemImage: "cylinder.split.1x2",
                order: order
            ) {
                SidebarView(viewModel: self.viewModel)
            },
        ])
        kernel.resolveProvider((any ActivityBarProviding).self)?.addItems([
            ActivityBarItem(
                id: "\(id).entry",
                title: metadata.name,
                systemImage: "cylinder.split.1x2",
                order: order,
                ownerPluginID: id
            ) { state in
                if state == .activated {
                    railView?.setVisibleTabID(Self.railTabID)
                    chat?.setVisible(false)
                    rootView?.setContentHeaderViewHidden(true)
                    contentView?.setContentView(
                        AnyView(DatabaseManagerV2Workspace(viewModel: self.viewModel))
                    )
                    toolbar?.addToolbarItems([
                        ToolbarItem(id: "\(self.id).title", title: self.metadata.name, placement: .center, order: 0) {
                            Text(self.metadata.name).font(.headline)
                        },
                    ])
                } else {
                    railView?.setVisibleCategories(Set(RailViewCategory.allCases))
                    chat?.setVisible(true)
                    rootView?.setContentHeaderViewHidden(false)
                    toolbar?.removeToolbarItems(ids: ["\(self.id).title"])
                }
            },
        ])
        kernel.resolveProvider((any ExternalFileOpening).self)?.registerHandler(pluginID: id) { url in
            self.openSQLiteDatabase(url)
        }
        let tools = kernel.resolveProvider((any ToolManagerProviding).self)
        tools?.add(DatabaseListConnectionsV2Tool(), pluginID: id)
        tools?.add(DatabaseDescribeSchemaV2Tool(), pluginID: id)
        tools?.add(DatabaseReadonlyQueryV2Tool(), pluginID: id)
        tools?.add(DatabaseSampleTableV2Tool(), pluginID: id)
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        let activityBar = kernel.resolveProvider((any ActivityBarProviding).self)
        let wasActive = activityBar?.activeItemID == "\(id).entry"
        activityBar?.removeItems(ids: ["\(id).entry"])
        if wasActive {
            kernel.resolveProvider((any RailViewProviding).self)?.setVisibleCategories(Set(RailViewCategory.allCases))
            kernel.resolveProvider((any ChatSectionProviding).self)?.setVisible(true)
            kernel.resolveProvider((any RootViewProviding).self)?.setContentHeaderViewHidden(false)
        }
        kernel.resolveProvider((any RailViewProviding).self)?.removeTabs(ids: [Self.railTabID])
        kernel.resolveProvider((any ContentViewProviding).self)?.setContentView(nil)
        kernel.resolveProvider((any ToolbarProviding).self)?.removeToolbarItems(ids: ["\(id).title"])
        kernel.resolveProvider((any ExternalFileOpening).self)?.unregisterHandlers(pluginID: id)
        let tools = kernel.resolveProvider((any ToolManagerProviding).self)
        tools?.remove(id: DatabaseListConnectionsV2Tool.toolName)
        tools?.remove(id: DatabaseDescribeSchemaV2Tool.toolName)
        tools?.remove(id: DatabaseReadonlyQueryV2Tool.toolName)
        tools?.remove(id: DatabaseSampleTableV2Tool.toolName)
        EmbeddedEditorServiceLocator.provider = nil
    }

    public func onUnregister(kernel: KernelCoreContainer) throws {
        kernel.resolveProvider((any DocsViewProviding).self)?.removeEntries(id: id)
    }

    private func openSQLiteDatabase(_ url: URL) -> Bool {
        guard ["sqlite", "sqlite3", "db"].contains(url.pathExtension.lowercased()) else { return false }
        let path = url.path
        let config = viewModel.configs.first(where: { $0.type == .sqlite && $0.database == path })
            ?? DatabaseConfig(name: url.deletingPathExtension().lastPathComponent, type: .sqlite, database: path)
        if !viewModel.configs.contains(where: { $0.id == config.id }) {
            viewModel.addConfig(config)
        }
        Task { await viewModel.connect(config: config) }
        return true
    }
}

@MainActor
private struct DatabaseManagerV2Workspace: View {
    @ObservedObject var viewModel: DatabaseViewModel

    var body: some View {
        DatabaseWorkspaceView(viewModel: viewModel)
            .frame(minWidth: 640)
    }
}
