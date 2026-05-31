import AgentToolKit
import Foundation
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

    @Test("tool input strings are trimmed and blank strings are rejected")
    func toolInputStringNormalization() {
        #expect(MemoryToolInput.string(" \n/Users/example/Project\t") == "/Users/example/Project")
        #expect(MemoryToolInput.string(" \n\t ") == nil)
    }

    @Test("tool input scopes are trimmed and validated")
    func toolInputScopeNormalization() throws {
        let projectScope = try MemoryToolInput.scope(" \nproject\t", default: "global", allowed: ["global", "project"])
        #expect(projectScope == "project")

        let defaultScope = try MemoryToolInput.scope(nil, default: "all", allowed: ["global", "project", "all"])
        #expect(defaultScope == "all")

        #expect(throws: MemoryToolError.self) {
            try MemoryToolInput.scope("workspace", default: "global", allowed: ["global", "project"])
        }
    }

    @Test("recall max results are clamped to a safe range")
    func recallMaxResultsAreClamped() {
        #expect(MemoryToolInput.maxResults(-3) == 0)
        #expect(MemoryToolInput.maxResults(8) == 8)
        #expect(MemoryToolInput.maxResults(99) == 20)
        #expect(MemoryToolInput.maxResults(nil) == 5)
    }

    @Test("local store reports save result and reloads values")
    func localStoreReportsSaveResultAndReloadsValues() {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "MemoryPluginLocalStore-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = MemoryPluginLocalStore(settingsDirectory: directory)

        #expect(store.set(8, forKey: .maxRelevantMemories) == true)
        #expect(store.set(true, forKey: .injectGlobalIndex) == true)

        let reloadedStore = MemoryPluginLocalStore(settingsDirectory: directory)
        #expect(reloadedStore.maxRelevantMemories == 8)
        #expect(reloadedStore.shouldInjectGlobalIndex == true)
    }

    @Test("local store quarantines invalid settings file and recovers")
    func localStoreQuarantinesInvalidSettingsFileAndRecovers() throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "MemoryPluginLocalStore-Invalid-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let settingsURL = directory.appending(path: "Memory.plist")
        let corruptURL = directory.appending(path: "Memory.corrupt.plist")
        let invalidData = Data("not a plist".utf8)
        try invalidData.write(to: settingsURL)

        let store = MemoryPluginLocalStore(settingsDirectory: directory)

        #expect(store.set(10, forKey: .maxRelevantMemories) == true)
        #expect((try? Data(contentsOf: corruptURL)) == invalidData)
        #expect(store.maxRelevantMemories == 10)

        let reloadedStore = MemoryPluginLocalStore(settingsDirectory: directory)
        #expect(reloadedStore.maxRelevantMemories == 10)
    }

    @Test("local store reports failure when settings directory is blocked")
    func localStoreReportsFailureWhenSettingsDirectoryIsBlocked() throws {
        let tempRoot = FileManager.default.temporaryDirectory
            .appending(path: "MemoryPluginLocalStore-Blocked-\(UUID().uuidString)", directoryHint: .isDirectory)
        let blockedDirectory = tempRoot.appending(path: "PluginSettings", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        try "not a directory".write(to: blockedDirectory, atomically: true, encoding: .utf8)

        let store = MemoryPluginLocalStore(settingsDirectory: blockedDirectory)

        #expect(store.set(10, forKey: .maxRelevantMemories) == false)
        #expect(store.maxRelevantMemories == 3)
    }
}
