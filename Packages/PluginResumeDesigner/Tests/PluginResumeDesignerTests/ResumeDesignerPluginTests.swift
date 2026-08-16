import AgentToolKit
import Foundation
import KernelCore
import ProviderActivityBar
import ProviderContentView
import ProviderDocsView
import ProviderRailView
import ProviderStorage
import ProviderToolManager
import Testing
@testable import PluginResumeDesigner

/// 综合测试套件（串行执行）。
///
/// 插件装配测试与 Agent 工具测试都依赖全局单例 `WorkspaceStore.shared`
/// （插件 onShutdown 会经 `ResumeDesignerRuntime.reset()` 清空存储路径），
/// 因此必须归入同一个 `.serialized` suite，避免并行时互相干扰；
/// 存储层测试（不共享全局状态）见 `ResumeDocumentStoreTests`，可独立并行。
@Suite("PluginResumeDesigner 综合测试", .serialized)
@MainActor
struct ResumeDesignerSuite {
    private final class TestStorage: StorageProviding {
        let dataRootDirectory: URL

        init() {
            dataRootDirectory = FileManager.default.temporaryDirectory
                .appendingPathComponent("PluginResumeDesignerTests-\(UUID().uuidString)")
        }

        func pluginDataDirectory(for pluginID: String) -> URL {
            dataRootDirectory.appendingPathComponent(pluginID, isDirectory: true)
        }

        func coreDataDirectory() -> URL {
            dataRootDirectory.appendingPathComponent("Core", isDirectory: true)
        }
    }

    // MARK: - 工具测试辅助（跨文件 extension 共用）

    /// 创建独立临时存储目录，并让 WorkspaceStore 指向它。
    func makeTemporaryStorage() -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ResumeToolsTests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        WorkspaceStore.shared.setAppStorage(appStorageDirectory: url)
        return url
    }

    func cleanup(_ directory: URL) {
        ResumeDesignerRuntime.reset()
        try? FileManager.default.removeItem(at: directory)
    }

    func arguments(_ pairs: [String: Any]) -> [String: ToolArgument] {
        pairs.mapValues { ToolArgument($0) }
    }

    @Test("启动后注册 ActivityBar 入口、Rail 标签与 Docs 文档，停止后全部撤回")
    func registersAndActivatesContributions() throws {
        let kernel = KernelCoreContainer()
        let activity = DefaultActivityBarProviding()
        let rail = DefaultRailViewProviding()
        let docs = DefaultDocsViewProviding()
        let storage = TestStorage()

        try kernel.registerProvider((any ActivityBarProviding).self, activity)
        try kernel.registerProvider(
            (any ContentViewProviding).self,
            DefaultContentViewProviding()
        )
        try kernel.registerProvider((any RailViewProviding).self, rail)
        try kernel.registerProvider((any DocsViewProviding).self, docs)
        try kernel.registerProvider((any StorageProviding).self, storage)

        try kernel.start(plugins: [ResumeDesignerPlugin()])

        // ActivityBar 入口与 Rail 标签注册。
        #expect(activity.items.map(\.id) == ["com.coffic.lumi.plugin.resume-designer.entry"])
        #expect(rail.tabs.map(\.id) == [ResumeDesignerPlugin.railTabID])
        #expect(rail.tabs.first?.groupID == "com.coffic.lumi.plugin.resume-designer")
        // Docs 关于页与说明书注册。
        #expect(docs.aboutEntries.map(\.id) == ["com.coffic.lumi.plugin.resume-designer"])
        #expect(docs.manualEntries.map(\.id) == ["com.coffic.lumi.plugin.resume-designer"])

        try kernel.stop()

        #expect(activity.items.isEmpty)
        #expect(rail.tabs.isEmpty)
        #expect(docs.aboutEntries.isEmpty)
        #expect(docs.manualEntries.isEmpty)
        try? FileManager.default.removeItem(at: storage.dataRootDirectory)
    }

    @Test("启动后 10 个 Agent 工具注册到 ToolManagerProviding，停止后移除")
    func registersAndRemovesAgentTools() throws {
        let kernel = KernelCoreContainer()
        let toolManager = DefaultToolManagerProviding()
        let storage = TestStorage()

        try kernel.registerProvider((any ToolManagerProviding).self, toolManager)
        try kernel.registerProvider((any ActivityBarProviding).self, DefaultActivityBarProviding())
        try kernel.registerProvider(
            (any ContentViewProviding).self,
            DefaultContentViewProviding()
        )
        try kernel.registerProvider((any RailViewProviding).self, DefaultRailViewProviding())
        try kernel.registerProvider((any StorageProviding).self, storage)

        try kernel.start(plugins: [ResumeDesignerPlugin()])

        // 10 个工具全部注册，且归入本插件分组。
        #expect(toolManager.allTools().count == 10)
        let groups = toolManager.toolsGroupedByPlugin()
        #expect(groups.count == 1)
        #expect(groups.first?.pluginID == "com.coffic.lumi.plugin.resume-designer")
        #expect(groups.first?.tools.count == 10)

        let expectedNames: Set<String> = [
            "resume_list", "resume_create", "resume_read", "resume_read_html",
            "resume_replace_html", "resume_patch_html", "resume_import_asset",
            "resume_lint", "resume_preview_page", "resume_export",
        ]
        #expect(Set(toolManager.allTools().map(\.name)) == expectedNames)

        try kernel.stop()

        #expect(toolManager.allTools().isEmpty)
        #expect(toolManager.toolsGroupedByPlugin().isEmpty)
        try? FileManager.default.removeItem(at: storage.dataRootDirectory)
    }
}
