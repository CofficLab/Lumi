import Foundation
import Testing
import KitAgentTool

@testable import PluginMemory

/// 锁定 #607：save / recall / list / delete_memory 的项目域必须作用于工具调用
/// 所属会话绑定的项目（`context.conversationProjectPath()`），而不是 UI 当前
/// 打开的项目。
///
/// 复现场景：会话绑定项目 A 的后台回合执行期间，用户把 UI 当前项目切到 B。
/// 这里用一个当前项目固定为 B 的能力适配器模拟 UI，再用绑定 A 的 Context 调用
/// 工具，断言记忆始终读写删 A 域。
///
/// 存储与能力都是每用例独立实例，不触碰任何进程级单例，可并行执行。
@Suite("Memory Tools Conversation Scope")
@MainActor
struct MemoryToolsConversationScopeTests {

    /// 当前项目固定为指定路径的能力适配器（模拟 UI 已切到 B）。
    @MainActor
    private final class FixedProjectCapability: MemoryProjectCapability {
        var currentProjectPath: String?
        init(_ path: String?) { currentProjectPath = path }
    }

    private let projectA = "/tmp/memory-scope-A"
    private let projectB = "/tmp/memory-scope-B"

    private func makeStorage() -> (MemoryFileStorage, URL) {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("memory-scope-\(UUID().uuidString)")
        return (MemoryFileStorage(rootURL: url), url)
    }

    private func makeContext(projectPath: String?) -> ToolExecutionContext {
        ToolExecutionContext(
            jobID: UUID().uuidString,
            conversationID: UUID(),
            conversationProjectPathProvider: { projectPath }
        )
    }

    private func arguments(_ pairs: [String: Any]) -> [String: ToolArgument] {
        pairs.mapValues { ToolArgument($0) }
    }

    @Test("save_memory 项目域写入会话项目 A，而非 UI 当前项目 B")
    func saveUsesConversationProject() async throws {
        let (storage, root) = makeStorage()
        defer { try? FileManager.default.removeItem(at: root) }
        let tool = SaveMemoryTool(storage: storage, projectCapability: FixedProjectCapability(projectB))

        _ = try await tool.executeResult(
            context: makeContext(projectPath: projectA),
            arguments: arguments([
                "id": "scoped", "name": "Scoped", "content": "A 的记忆",
                "type": "project", "scope": "project",
            ])
        )

        #expect(try await storage.load(id: "scoped", type: .project, scope: .project, projectPath: projectA) != nil)
        #expect(try await storage.load(id: "scoped", type: .project, scope: .project, projectPath: projectB) == nil)
    }

    @Test("recall_memory 项目域读会话项目 A，而非 UI 当前项目 B")
    func recallUsesConversationProject() async throws {
        let (storage, root) = makeStorage()
        defer { try? FileManager.default.removeItem(at: root) }
        _ = try await storage.save(
            id: "scoped", type: .project, name: "Scoped", description: "d",
            content: "A 的记忆", scope: .project, projectPath: projectA
        )
        let tool = RecallMemoryTool(storage: storage, projectCapability: FixedProjectCapability(projectB))

        let output = try await tool.executeResult(
            context: makeContext(projectPath: projectA),
            arguments: arguments(["id": "scoped", "scope": "project"])
        )
        #expect(output.content.contains("A 的记忆"))

        // 绑定 B 的会话读不到 A 的记忆（域隔离）。
        await #expect(throws: ToolExecutionError.self) {
            _ = try await tool.executeResult(
                context: self.makeContext(projectPath: self.projectB),
                arguments: self.arguments(["id": "scoped", "scope": "project"])
            )
        }
    }

    @Test("list_memories 项目域只列会话项目 A，不含 UI 当前项目 B")
    func listUsesConversationProject() async throws {
        let (storage, root) = makeStorage()
        defer { try? FileManager.default.removeItem(at: root) }
        _ = try await storage.save(
            id: "m-a", type: .project, name: "A", description: "d",
            content: "a", scope: .project, projectPath: projectA
        )
        _ = try await storage.save(
            id: "m-b", type: .project, name: "B", description: "d",
            content: "b", scope: .project, projectPath: projectB
        )
        let tool = ListMemoriesTool(storage: storage, projectCapability: FixedProjectCapability(projectB))

        let output = try await tool.executeResult(
            context: makeContext(projectPath: projectA),
            arguments: arguments(["scope": "project"])
        )
        #expect(output.content.contains("m-a"))
        #expect(!output.content.contains("m-b"))
    }

    @Test("delete_memory 项目域删会话项目 A，UI 当前项目 B 不受影响")
    func deleteUsesConversationProject() async throws {
        let (storage, root) = makeStorage()
        defer { try? FileManager.default.removeItem(at: root) }
        _ = try await storage.save(
            id: "scoped", type: .project, name: "A", description: "d",
            content: "a", scope: .project, projectPath: projectA
        )
        _ = try await storage.save(
            id: "scoped", type: .project, name: "B", description: "d",
            content: "b", scope: .project, projectPath: projectB
        )
        let tool = DeleteMemoryTool(storage: storage, projectCapability: FixedProjectCapability(projectB))

        _ = try await tool.executeResult(
            context: makeContext(projectPath: projectA),
            arguments: arguments(["id": "scoped", "scope": "project"])
        )

        #expect(try await storage.load(id: "scoped", type: .project, scope: .project, projectPath: projectA) == nil)
        #expect(try await storage.load(id: "scoped", type: .project, scope: .project, projectPath: projectB) != nil)
    }

    @Test("缺少会话上下文时回退到 UI 当前项目")
    func fallsBackToCurrentProjectWithoutContext() async throws {
        let (storage, root) = makeStorage()
        defer { try? FileManager.default.removeItem(at: root) }
        let tool = SaveMemoryTool(storage: storage, projectCapability: FixedProjectCapability(projectB))

        // 旧入口（无 Context）：项目域回退到当前项目 B。
        _ = try await tool.execute(arguments: arguments([
            "id": "legacy", "name": "Legacy", "content": "B 的记忆",
            "type": "project", "scope": "project",
        ]))
        #expect(try await storage.load(id: "legacy", type: .project, scope: .project, projectPath: projectB) != nil)
    }
}