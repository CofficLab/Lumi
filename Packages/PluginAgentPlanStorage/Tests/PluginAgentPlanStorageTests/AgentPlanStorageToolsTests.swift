import Foundation
import KitAgentTool
import KernelCore
import ProviderStorage
import ProviderToolManager
import Testing
@testable import PluginAgentPlanStorage

// MARK: - 测试替身

/// 指向临时目录的存储替身。
private final class StubStorageProvider: StorageProviding {
    let root: URL

    init(root: URL) {
        self.root = root
    }

    var dataRootDirectory: URL { root }

    func pluginDataDirectory(for pluginID: String) -> URL {
        root.appendingPathComponent(pluginID, isDirectory: true)
    }

    func coreDataDirectory() -> URL {
        root.appendingPathComponent("core", isDirectory: true)
    }
}

private func makeTemporaryDirectory(_ label: String) throws -> URL {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("PluginAgentPlanStorageTests-\(label)-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory
}

// MARK: - 计划工具

@Suite("计划工具")
struct AgentPlanToolsTests {

    @Test("write_plan 写入文件并返回路径")
    func writePlanStoresContent() async throws {
        let root = try makeTemporaryDirectory("write")
        defer { try? FileManager.default.removeItem(at: root) }
        let service = try PlanFileStorageService(directory: root, retentionDays: 30)
        let tool = WritePlanTool(storage: service)

        let output = try await tool.execute(arguments: [
            "filename": ToolArgument("plan.md"),
            "content": ToolArgument("# plan"),
        ])

        #expect(output.hasPrefix("Wrote plan to "))
        #expect(output.hasSuffix("/plan.md"))
        #expect(try await service.read(filename: "plan.md") == "# plan")
    }

    @Test("write_plan 缺少参数时抛错")
    func writePlanRequiresArguments() async throws {
        let root = try makeTemporaryDirectory("write-missing")
        defer { try? FileManager.default.removeItem(at: root) }
        let service = try PlanFileStorageService(directory: root, retentionDays: 30)
        let tool = WritePlanTool(storage: service)

        await #expect(throws: (any Error).self) {
            _ = try await tool.execute(arguments: ["filename": ToolArgument("plan.md")])
        }
        await #expect(throws: (any Error).self) {
            _ = try await tool.execute(arguments: ["content": ToolArgument("x")])
        }
    }

    @Test("read_plan 读取已写入内容")
    func readPlanReturnsContent() async throws {
        let root = try makeTemporaryDirectory("read")
        defer { try? FileManager.default.removeItem(at: root) }
        let service = try PlanFileStorageService(directory: root, retentionDays: 30)
        _ = try await service.write(filename: "plan.md", content: "body")
        let tool = ReadPlanTool(storage: service)

        let output = try await tool.execute(arguments: ["filename": ToolArgument("plan.md")])

        #expect(output == "body")
    }

    @Test("read_plan 缺少参数或文件不存在时抛错")
    func readPlanReportsMissingInput() async throws {
        let root = try makeTemporaryDirectory("read-missing")
        defer { try? FileManager.default.removeItem(at: root) }
        let service = try PlanFileStorageService(directory: root, retentionDays: 30)
        let tool = ReadPlanTool(storage: service)

        await #expect(throws: (any Error).self) {
            _ = try await tool.execute(arguments: [:])
        }
        await #expect(throws: PlanFileStorageError.fileNotFound("nope.md")) {
            _ = try await tool.execute(arguments: ["filename": ToolArgument("nope.md")])
        }
    }

    @Test("delete_plan 删除已存在文件")
    func deletePlanRemovesFile() async throws {
        let root = try makeTemporaryDirectory("delete")
        defer { try? FileManager.default.removeItem(at: root) }
        let service = try PlanFileStorageService(directory: root, retentionDays: 30)
        _ = try await service.write(filename: "plan.md", content: "body")
        let tool = DeletePlanTool(storage: service)

        let output = try await tool.execute(arguments: ["filename": ToolArgument("plan.md")])

        #expect(output == "Deleted plan plan.md")
        #expect(await service.listFiles().isEmpty)
    }

    @Test("delete_plan 缺少参数时抛错")
    func deletePlanRequiresFilename() async throws {
        let root = try makeTemporaryDirectory("delete-missing")
        defer { try? FileManager.default.removeItem(at: root) }
        let service = try PlanFileStorageService(directory: root, retentionDays: 30)
        let tool = DeletePlanTool(storage: service)

        await #expect(throws: (any Error).self) {
            _ = try await tool.execute(arguments: [:])
        }
    }

    @Test("list_plans 空目录时给出提示与存储信息")
    func listPlansDescribesEmptyStorage() async throws {
        let root = try makeTemporaryDirectory("list-empty")
        defer { try? FileManager.default.removeItem(at: root) }
        let service = try PlanFileStorageService(directory: root, retentionDays: 7)
        let tool = ListPlansTool(storage: service)

        let output = try await tool.execute(arguments: [:])

        #expect(output.contains("No plan files."))
        #expect(output.contains("Storage directory: "))
        #expect(output.contains("Retention: 7 days"))
    }

    @Test("list_plans 列出文件名、大小与修改时间")
    func listPlansDescribesFiles() async throws {
        let root = try makeTemporaryDirectory("list-files")
        defer { try? FileManager.default.removeItem(at: root) }
        let service = try PlanFileStorageService(directory: root, retentionDays: 30)
        _ = try await service.write(filename: "plan.md", content: "0123456789")
        let tool = ListPlansTool(storage: service)

        let output = try await tool.execute(arguments: [:])

        #expect(output.contains("1 plan file(s)."))
        #expect(output.contains("- plan.md (10 bytes, modified "))
    }

    @Test("四个工具的名称、风险等级与展示描述稳定")
    func toolsExposeStableMetadata() async throws {
        let root = try makeTemporaryDirectory("metadata")
        defer { try? FileManager.default.removeItem(at: root) }
        let service = try PlanFileStorageService(directory: root, retentionDays: 30)

        let write = WritePlanTool(storage: service)
        let read = ReadPlanTool(storage: service)
        let list = ListPlansTool(storage: service)
        let delete = DeletePlanTool(storage: service)

        #expect(write.name == "write_plan")
        #expect(read.name == "read_plan")
        #expect(list.name == "list_plans")
        #expect(delete.name == "delete_plan")

        for tool in [write, read, list, delete] as [any SuperAgentTool] {
            #expect(tool.permissionRiskLevel(arguments: [:]) == .low)
            #expect(tool.description(for: .english).isEmpty == false)
            #expect(tool.inputSchema(for: .english)["type"] as? String == "object")
        }

        #expect(write.displayDescription(for: ["filename": ToolArgument("a.md")]) == "写入计划 a.md")
        #expect(write.displayDescription(for: [:]) == "写入计划")
        #expect(read.displayDescription(for: ["filename": ToolArgument("a.md")]) == "读取计划 a.md")
        #expect(read.displayDescription(for: [:]) == "读取计划")
        #expect(delete.displayDescription(for: ["filename": ToolArgument("a.md")]) == "删除计划 a.md")
        #expect(delete.displayDescription(for: [:]) == "删除计划")
        #expect(list.displayDescription(for: [:]) == "列出计划文件")
    }

    @Test("写入工具的 schema 声明 filename 与 content 必填")
    func writeToolSchemaDeclaresRequiredFields() throws {
        let root = try makeTemporaryDirectory("schema")
        defer { try? FileManager.default.removeItem(at: root) }
        let service = try PlanFileStorageService(directory: root, retentionDays: 1)
        let schema = WritePlanTool(storage: service).inputSchema(for: .chinese)

        let properties = schema["properties"] as? [String: Any]
        #expect(properties?["filename"] != nil)
        #expect(properties?["content"] != nil)
        let required = schema["required"] as? [String]
        #expect(required == ["filename", "content"])
    }
}

// MARK: - 保留天数配置

@Suite("计划存储保留天数配置")
struct AgentPlanStorageLocalStoreTests {

    @Test("未配置时使用默认 30 天")
    func defaultsToThirtyDays() throws {
        let directory = try makeTemporaryDirectory("store-default")
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = AgentPlanStoragePluginLocalStore(settingsDirectory: directory)

        #expect(store.retentionDays == 30)
    }

    @Test("写入后读回保留天数")
    func roundTripsRetentionDays() throws {
        let directory = try makeTemporaryDirectory("store-roundtrip")
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = AgentPlanStoragePluginLocalStore(settingsDirectory: directory)

        store.retentionDays = 12

        #expect(store.retentionDays == 12)
    }

    @Test("保留天数被夹取到至少 1 天")
    func clampsRetentionDaysToAtLeastOne() throws {
        let directory = try makeTemporaryDirectory("store-clamp")
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = AgentPlanStoragePluginLocalStore(settingsDirectory: directory)

        store.retentionDays = 0
        #expect(store.retentionDays == 1)

        store.retentionDays = -5
        #expect(store.retentionDays == 1)
    }

    @Test("设置文件损坏时回退到默认值")
    func fallsBackToDefaultOnCorruptedFile() throws {
        let directory = try makeTemporaryDirectory("store-corrupt")
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("settings.plist")
        try Data("not a plist".utf8).write(to: file)
        let store = AgentPlanStoragePluginLocalStore(settingsDirectory: directory)

        #expect(store.retentionDays == 30)
    }
}

// MARK: - 运行时目录

@Suite("计划存储运行时目录")
@MainActor
struct AgentPlanStorageRuntimeTests {

    @Test("注入目录后 settingsDirectory 返回该目录")
    func usesInjectedDirectory() throws {
        let directory = try makeTemporaryDirectory("runtime-injected")
        AgentPlanStorageRuntime.configure(settingsDirectory: directory)
        defer { AgentPlanStorageRuntime.reset() }

        #expect(AgentPlanStorageRuntime.settingsDirectory() == directory)
    }

    @Test("重置后回到默认回退目录")
    func resetRestoresFallbackDirectory() throws {
        let directory = try makeTemporaryDirectory("runtime-reset")
        AgentPlanStorageRuntime.configure(settingsDirectory: directory)
        AgentPlanStorageRuntime.reset()

        #expect(AgentPlanStorageRuntime.settingsDirectory() != directory)
        #expect(
            AgentPlanStorageRuntime.settingsDirectory().lastPathComponent
                == "com.coffic.lumi.plugin.agent-plan-storage"
        )
    }
}

// MARK: - 插件生命周期

@Suite("计划存储插件生命周期")
@MainActor
struct AgentPlanStoragePluginLifecycleTests {

    @Test("启动后注册四个计划工具")
    func bootRegistersTools() throws {
        let root = try makeTemporaryDirectory("boot-tools")
        defer { try? FileManager.default.removeItem(at: root) }
        let kernel = KernelCoreContainer()
        try kernel.registerProvider(
            (any StorageProviding).self,
            StubStorageProvider(root: root)
        )
        let toolManager = DefaultToolManagerProviding()
        try kernel.registerProvider((any ToolManagerProviding).self, toolManager)

        let plugin = AgentPlanStoragePlugin()
        try plugin.onBoot(kernel: kernel)
        defer { try? plugin.onShutdown(kernel: kernel) }

        #expect(toolManager.allTools().map(\.name) == ["write_plan", "read_plan", "list_plans", "delete_plan"])
    }

    @Test("启动时把插件数据目录注入运行时配置")
    func bootInjectsStorageDirectory() throws {
        let root = try makeTemporaryDirectory("boot-directory")
        defer { try? FileManager.default.removeItem(at: root) }
        let kernel = KernelCoreContainer()
        try kernel.registerProvider(
            (any StorageProviding).self,
            StubStorageProvider(root: root)
        )

        let plugin = AgentPlanStoragePlugin()
        try plugin.onBoot(kernel: kernel)
        defer { try? plugin.onShutdown(kernel: kernel) }

        let expected = root.appendingPathComponent(AgentPlanStoragePlugin.pluginID, isDirectory: true)
        #expect(AgentPlanStorageRuntime.settingsDirectory() == expected)
    }

    @Test("缺少存储 Provider 时启动失败")
    func bootFailsWithoutStorageProvider() {
        let kernel = KernelCoreContainer()
        let plugin = AgentPlanStoragePlugin()

        #expect(throws: (any Error).self) {
            try plugin.onBoot(kernel: kernel)
        }
    }

    @Test("关闭时移除四个计划工具")
    func shutdownRemovesTools() throws {
        let root = try makeTemporaryDirectory("shutdown-tools")
        defer { try? FileManager.default.removeItem(at: root) }
        let kernel = KernelCoreContainer()
        try kernel.registerProvider(
            (any StorageProviding).self,
            StubStorageProvider(root: root)
        )
        let toolManager = DefaultToolManagerProviding()
        try kernel.registerProvider((any ToolManagerProviding).self, toolManager)

        let plugin = AgentPlanStoragePlugin()
        try plugin.onBoot(kernel: kernel)
        try plugin.onShutdown(kernel: kernel)

        #expect(toolManager.allTools().isEmpty)
    }

    @Test("没有工具管理器时启动仍然成功")
    func bootSucceedsWithoutToolManager() throws {
        let root = try makeTemporaryDirectory("boot-no-tools")
        defer { try? FileManager.default.removeItem(at: root) }
        let kernel = KernelCoreContainer()
        try kernel.registerProvider(
            (any StorageProviding).self,
            StubStorageProvider(root: root)
        )

        let plugin = AgentPlanStoragePlugin()
        try plugin.onBoot(kernel: kernel)
        defer { try? plugin.onShutdown(kernel: kernel) }

        #expect(AgentPlanStorageRuntime.settingsDirectory().lastPathComponent
            == AgentPlanStoragePlugin.pluginID)
    }
}
