import EditorContracts
import EditorService
import KernelCore
import PluginCodeEditorHost
import Testing

@MainActor
struct CodeEditorHostSuperPluginTests {
    @Test("registers the shared editor service and every host capability")
    func registersEditorServices() throws {
        let kernel = KernelCoreContainer()
        try kernel.start(plugins: [CodeEditorHostSuperPlugin()])

        _ = try #require(kernel.resolveProvider(EditorService.self))
        let editor = try #require(kernel.resolveProvider(EditorProvidingV2.self))
        let surface = try #require(kernel.resolveProvider(EditorSurfaceProviding.self))

        #expect(editor.surface === surface)
        #expect(kernel.resolveProvider(EditorEmbeddedEditorProviding.self) != nil)
    }

    @Test("removes every editor capability during shutdown")
    func removesEditorServices() throws {
        let kernel = KernelCoreContainer()
        try kernel.start(plugins: [CodeEditorHostSuperPlugin()])

        try kernel.stop()

        #expect(kernel.resolveProvider(EditorService.self) == nil)
        #expect(kernel.resolveProvider(EditorProvidingV2.self) == nil)
        #expect(kernel.resolveProvider(EditorSurfaceProviding.self) == nil)
        #expect(kernel.resolveProvider(EditorEmbeddedEditorProviding.self) == nil)
    }
}
