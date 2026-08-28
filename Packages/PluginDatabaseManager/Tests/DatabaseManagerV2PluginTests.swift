import DatabaseManagerPlugin
import EditorService
import KernelCore
import ProviderContentView
import ProviderExternalFile
import ProviderToolbar
import ProviderToolManager
import Testing

@MainActor
struct DatabaseManagerV2PluginTests {
    @Test("V2 plugin restores workspace, SQL grammar, and SQLite external-file routing")
    func restoresDatabaseWorkspace() throws {
        let kernel = KernelCoreContainer()
        let content = DefaultContentViewProviding()
        let externalFiles = DefaultExternalFileOpening()
        let tools = DefaultToolManagerProviding()
        try kernel.registerProvider((any ContentViewProviding).self, content)
        try kernel.registerProvider((any ExternalFileOpening).self, externalFiles)
        try kernel.registerProvider((any ToolbarProviding).self, DefaultToolbarProviding())
        try kernel.registerProvider((any ToolManagerProviding).self, tools)
        try kernel.registerProvider(EditorService.self, EditorService(editorExtensionRegistry: EditorExtensionRegistry()))

        let plugin = DatabaseManagerSuperPlugin()
        try plugin.onBoot(kernel: kernel)

        #expect(externalFiles.open(URL(fileURLWithPath: "/tmp/lumi-v2.sqlite")))
        #expect(!externalFiles.open(URL(fileURLWithPath: "/tmp/lumi-v2.txt")))
        #expect(tools.tool(named: DatabaseListConnectionsV2Tool.toolName) != nil)
        #expect(tools.tool(named: DatabaseDescribeSchemaV2Tool.toolName) != nil)
        #expect(tools.tool(named: DatabaseReadonlyQueryV2Tool.toolName) != nil)
        #expect(tools.tool(named: DatabaseSampleTableV2Tool.toolName) != nil)
        try plugin.onShutdown(kernel: kernel)
        #expect(!externalFiles.open(URL(fileURLWithPath: "/tmp/lumi-v2.sqlite")))
        #expect(tools.tool(named: DatabaseListConnectionsV2Tool.toolName) == nil)
    }
}
