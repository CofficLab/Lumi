import PluginProjectRAG
import KernelCore
import ProviderProjectRAG
import Testing

@Suite("ProjectRAGSuperPlugin")
@MainActor
struct ProjectRAGSuperPluginTests {
    @Test("keeps the legacy plugin and tool identifiers")
    func retainsStableIdentifiers() {
        #expect(ProjectRAGSuperPlugin().id == "com.coffic.lumi.plugin.project.rag")
        #expect(RAGCodeSearchTool.toolName == "search_code")
    }

    @Test("registers the RAG capability in KernelCore")
    func registersProvider() throws {
        let kernel = KernelCoreContainer()
        let plugin = ProjectRAGSuperPlugin()

        try plugin.onBoot(kernel: kernel)
        #expect(kernel.resolveProvider((any ProjectRAGProviding).self) != nil)

        try plugin.onShutdown(kernel: kernel)
        #expect(kernel.resolveProvider((any ProjectRAGProviding).self) == nil)
    }
}
