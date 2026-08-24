import PluginProjectRAG
import Testing

@Suite("ProjectRAGSuperPlugin")
@MainActor
struct ProjectRAGSuperPluginTests {
    @Test("keeps the legacy plugin and tool identifiers")
    func retainsStableIdentifiers() {
        #expect(ProjectRAGSuperPlugin().id == "com.coffic.lumi.plugin.project.rag")
        #expect(RAGCodeSearchTool.toolName == "search_code")
    }
}
