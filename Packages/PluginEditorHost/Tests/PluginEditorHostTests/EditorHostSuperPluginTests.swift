import EditorService
import KernelCore
import PluginEditorHost
import Testing

@MainActor
struct EditorHostSuperPluginTests {
    @Test("registers the shared editor service and embedded editor capability")
    func registersEditorServices() throws {
        let kernel = KernelCoreContainer()
        try kernel.start(plugins: [EditorHostSuperPlugin()])

        #expect(kernel.resolveProvider(EditorService.self) != nil)
        #expect(kernel.resolveProvider(EditorEmbeddedEditorProviding.self) != nil)
    }
}
