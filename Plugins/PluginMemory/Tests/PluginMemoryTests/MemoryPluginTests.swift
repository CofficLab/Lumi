import AgentToolKit
import LumiCoreKit
import MemoryKit
import Testing
@testable import PluginMemory

@Suite("PluginMemory")
struct PluginMemoryTests {
    @Test("plugin metadata is stable")
    func pluginMetadata() {
        #expect(MemoryPlugin.id == "Memory")
        #expect(MemoryPlugin.displayName == "Memory")
        #expect(MemoryPlugin.iconName == "brain.head.profile")
        #expect(MemoryPlugin.category == .agent)
        #expect(MemoryPlugin.order == 15)
    }

    @MainActor
    @Test("plugin registers four memory tools")
    func pluginRegistersTools() {
        let tools = MemoryPlugin.shared.agentTools(context: ToolContext())

        #expect(tools.count == 4)
        let names = tools.map(\.name)
        #expect(names.contains("save_memory"))
        #expect(names.contains("recall_memory"))
        #expect(names.contains("list_memories"))
        #expect(names.contains("delete_memory"))
    }

    @Test("save memory tool schema has required fields")
    func saveMemoryToolSchema() throws {
        let tool = SaveMemoryTool()
        let schema = tool.inputSchema(for: .english)

        let required = try #require(schema["required"] as? [String])
        #expect(required.contains("id"))
        #expect(required.contains("type"))
        #expect(required.contains("name"))
        #expect(required.contains("description"))
        #expect(required.contains("content"))
    }

    @Test("recall memory tool schema requires query")
    func recallMemoryToolSchema() throws {
        let tool = RecallMemoryTool()
        let schema = tool.inputSchema(for: .english)

        let required = try #require(schema["required"] as? [String])
        #expect(required == ["query"])
    }

    @Test("all tools have low risk level")
    func allToolsLowRisk() {
        #expect(SaveMemoryTool().permissionRiskLevel(arguments: [:]) == .low)
        #expect(RecallMemoryTool().permissionRiskLevel(arguments: [:]) == .low)
        #expect(ListMemoriesTool().permissionRiskLevel(arguments: [:]) == .low)
        #expect(DeleteMemoryTool().permissionRiskLevel(arguments: [:]) == .low)
    }

    @Test("localization catalog is packaged")
    func localizationCatalogIsPackaged() {
        #expect(PluginMemoryLocalization.bundle.url(forResource: "Memory", withExtension: "xcstrings") != nil)
        #expect(PluginMemoryLocalization.string("Memory").isEmpty == false)
    }

    @Test("config has sensible defaults")
    func configDefaults() {
        let config = MemoryPluginConfig.default
        #expect(config.maxRelevantMemories == 3)
        #expect(config.staleThresholdDays == 7)
        #expect(config.halfLifeDays == 30)
        #expect(config.injectGlobalIndex == true)
        #expect(config.injectProjectIndex == true)
    }
}
