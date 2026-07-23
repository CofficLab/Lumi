import Foundation
import LumiKernel
import Testing
@testable import MemoryPlugin

@Suite("PluginMemory")
struct PluginMemoryTests {
    @Test("plugin metadata is stable")
    func pluginMetadata() {
        #expect(MemoryPlugin.info.id == "com.coffic.lumi.plugin.memory")
        #expect(MemoryPlugin.info.displayName == PluginMemoryLocalization.string("Memory"))
        #expect(MemoryPlugin.iconName == "brain.head.profile")
        #expect(MemoryPlugin.category == .agent)
        #expect(MemoryPlugin.info.order == 15)
    }

    @MainActor
    @Test("plugin registers four memory tools")
    func pluginRegistersTools() {
        let tools = MemoryPlugin.agentTools(lumiCore: LumiPluginContext(activeSectionID: "chat", activeSectionTitle: "Chat"))

        #expect(tools.count == 4)
        let names = tools.map(\.name)
        #expect(names.contains("save_memory"))
        #expect(names.contains("recall_memory"))
        #expect(names.contains("list_memories"))
        #expect(names.contains("delete_memory"))
    }

    @MainActor
    @Test("save memory tool schema has required fields")
    func saveMemoryToolSchema() {
        let tool = SaveMemoryTool()
        let schema = tool.inputSchema

        let required = Self.extractStringArray(schema, "required")
        #expect(required?.contains("id") == true)
        #expect(required?.contains("type") == true)
        #expect(required?.contains("name") == true)
        #expect(required?.contains("description") == true)
        #expect(required?.contains("content") == true)
    }

    @Test("recall memory tool schema requires query")
    func recallMemoryToolSchema() {
        let tool = RecallMemoryTool()
        let schema = tool.inputSchema

        #expect(Self.extractStringArray(schema, "required") == ["query"])

        let properties = Self.extractObject(schema, "properties")
        if case .object(let maxResults) = properties?["max_results"] {
            if case .string(let type) = maxResults["type"] {
                #expect(type == "integer")
            }
            if case .int(let minimum) = maxResults["minimum"] {
                #expect(minimum == MemoryToolInput.minMaxResults)
            }
            if case .int(let maximum) = maxResults["maximum"] {
                #expect(maximum == MemoryToolInput.maxMaxResults)
            }
        }
    }

    @Test("all tools have low risk level")
    func allToolsLowRisk() {
        #expect(SaveMemoryTool().riskLevel(arguments: [:], context: nil) == .low)
        #expect(RecallMemoryTool().riskLevel(arguments: [:], context: nil) == .low)
        #expect(ListMemoriesTool().riskLevel(arguments: [:], context: nil) == .low)
        #expect(DeleteMemoryTool().riskLevel(arguments: [:], context: nil) == .low)
    }

    // MARK: - LumiJSONValue schema helpers

    private static func extractObject(_ schema: LumiJSONValue, _ key: String) -> [String: LumiJSONValue]? {
        guard case .object(let keys) = schema, case .object(let inner) = keys[key] else { return nil }
        return inner
    }

    private static func extractStringArray(_ schema: LumiJSONValue, _ key: String) -> [String]? {
        guard case .object(let keys) = schema, case .array(let arr) = keys[key] else { return nil }
        return arr.compactMap { if case .string(let s) = $0 { s } else { nil } }
    }

    @Test("localization catalog is packaged")
    func localizationCatalogIsPackaged() {
        #expect(PluginMemoryLocalization.bundle.url(forResource: "Localizable", withExtension: "xcstrings") != nil)
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
        #expect(MemoryToolInput.maxResults(-3) == MemoryToolInput.minMaxResults)
        #expect(MemoryToolInput.maxResults(8) == 8)
        #expect(MemoryToolInput.maxResults(8.0) == 8)
        #expect(MemoryToolInput.maxResults("9") == 9)
        #expect(MemoryToolInput.maxResults(99) == MemoryToolInput.maxMaxResults)
        #expect(MemoryToolInput.maxResults(nil) == MemoryToolInput.defaultMaxResults)
        #expect(MemoryToolInput.maxResults("not-a-number") == MemoryToolInput.defaultMaxResults)
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
