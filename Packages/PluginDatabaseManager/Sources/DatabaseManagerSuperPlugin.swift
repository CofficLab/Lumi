import EditorContracts
import EditorService
import KernelCore
import ProviderDocsView
import ProviderContentView
import ProviderExternalFile
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
    nonisolated static let logger = Logger(subsystem: "com.coffic.lumi.plugin.database-manager", category: "DatabaseManager")
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

    private let viewModel = DatabaseViewModel()

    public init() {}

    public func onBoot(kernel: KernelCoreContainer) throws {
        EmbeddedEditorServiceLocator.provider = kernel.resolveProvider(EditorEmbeddedEditorProviding.self)
        if let editor = kernel.resolveProvider(EditorService.self) {
            editor.editorExtensions.registerLanguage(DatabaseSQLLanguageSupport.descriptor)
            editor.editorExtensions.registerGrammarProvider(DatabaseSQLGrammarProvider())
        }
        kernel.resolveProvider((any ContentViewProviding).self)?.setContentView(
            AnyView(DatabaseManagerV2Workspace(viewModel: viewModel))
        )
        kernel.resolveProvider((any ToolbarProviding).self)?.addToolbarItems([
            ToolbarItem(id: "\(id).title", title: metadata.name, placement: .center, order: 0) {
                Text(self.metadata.name).font(.headline)
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
        if let docs = kernel.resolveProvider((any DocsViewProviding).self) {
            docs.addAbout(DocsEntry(id: id, name: metadata.name) { AboutView() })
            docs.addManual(DocsEntry(id: id, name: metadata.name) { DatabaseManagerManualView() })
        }
    }

    public func onShutdown(kernel: KernelCoreContainer) throws {
        kernel.resolveProvider((any ContentViewProviding).self)?.setContentView(nil)
        kernel.resolveProvider((any ToolbarProviding).self)?.removeToolbarItems(ids: ["\(id).title"])
        kernel.resolveProvider((any ExternalFileOpening).self)?.unregisterHandlers(pluginID: id)
        let tools = kernel.resolveProvider((any ToolManagerProviding).self)
        tools?.remove(id: DatabaseListConnectionsV2Tool.toolName)
        tools?.remove(id: DatabaseDescribeSchemaV2Tool.toolName)
        tools?.remove(id: DatabaseReadonlyQueryV2Tool.toolName)
        tools?.remove(id: DatabaseSampleTableV2Tool.toolName)
        kernel.resolveProvider((any DocsViewProviding).self)?.removeEntries(id: id)
        EmbeddedEditorServiceLocator.provider = nil
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
        HSplitView {
            SidebarView(viewModel: viewModel)
                .frame(minWidth: 230, idealWidth: 280, maxWidth: 380)
            DatabaseWorkspaceView(viewModel: viewModel)
                .frame(minWidth: 640)
        }
    }
}
