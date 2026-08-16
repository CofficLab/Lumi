import Foundation
import KernelCore
import ProviderActivityBar
import ProviderContentView
import ProviderRailView
import ProviderStorage
import Testing
@testable import PluginAppIconDesigner

@Suite("PluginAppIconDesigner")
@MainActor
struct AppIconDesignerPluginTests {
    private final class TestStorage: StorageProviding {
        let dataRootDirectory: URL

        init() {
            dataRootDirectory = FileManager.default.temporaryDirectory
                .appendingPathComponent("PluginAppIconDesignerTests-\(UUID().uuidString)")
        }

        func pluginDataDirectory(for pluginID: String) -> URL {
            dataRootDirectory.appendingPathComponent(pluginID, isDirectory: true)
        }

        func coreDataDirectory() -> URL {
            dataRootDirectory.appendingPathComponent("Core", isDirectory: true)
        }
    }

    @Test("启动后注册 ActivityBar 与分组 Rail，并在激活时联动")
    func registersAndActivatesContributions() throws {
        let kernel = KernelCoreContainer()
        let activity = DefaultActivityBarProviding()
        let rail = DefaultRailViewProviding()
        let storage = TestStorage()

        try kernel.registerProvider((any ActivityBarProviding).self, activity)
        try kernel.registerProvider(
            (any ContentViewProviding).self,
            DefaultContentViewProviding()
        )
        try kernel.registerProvider((any RailViewProviding).self, rail)
        try kernel.registerProvider((any StorageProviding).self, storage)

        try kernel.start(plugins: [AppIconDesignerPlugin()])

        #expect(activity.items.map(\.id) == ["com.coffic.lumi.plugin.app-icon-designer.entry"])
        #expect(rail.tabs.map(\.id) == [AppIconDesignerPlugin.railTabID])
        #expect(rail.tabs.first?.groupID == "com.coffic.lumi.plugin.app-icon-designer")
        #expect(rail.activeGroupID == "com.coffic.lumi.plugin.app-icon-designer")
        #expect(rail.activeTabID == AppIconDesignerPlugin.railTabID)

        try kernel.stop()

        #expect(activity.items.isEmpty)
        #expect(rail.tabs.isEmpty)
        try? FileManager.default.removeItem(at: storage.dataRootDirectory)
    }

    @Test("图标文档在 APP 作用域创建并落盘")
    func createsAndPersistsAppDocument() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("IconDocumentStoreTests-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }

        IconDocumentStore.shared.setAppStorage(appStorageDirectory: directory)
        let document = IconDocumentStore.shared.createDocument(
            title: "Kernel Icon",
            width: 1024,
            height: 1024,
            background: .color("#00000000"),
            scope: .app
        )

        #expect(IconDocumentStore.shared.selectedDocumentId == document.id)
        #expect(FileManager.default.fileExists(
            atPath: directory
                .appendingPathComponent("\(document.fileSafeName)-\(document.id.prefix(8)).json")
                .path
        ))

        IconDesignerRuntime.reset()
    }
}
