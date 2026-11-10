import Foundation
import KitAgentTool
import ProviderProject
import Testing

@testable import PluginAgentRules

/// 跨会话隔离测试：Agent 规则工具必须按「工具调用所属会话」绑定项目读写，
/// 而不是 UI 当前打开的项目。
///
/// 场景：会话 A 绑定项目 A，回合仍在执行；用户切到项目 B 后，
/// 旧实现从 `AgentRulesRuntime.currentProjectPath` 取到 B，
/// 于是读取和写入都落到 B（见 #619）。
@Suite("AgentRulesConversationScope")
@MainActor
struct AgentRulesConversationScopeTests {

    private func makeProject(_ name: String) throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("agent-rules-scope-\(name)-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(
            at: root.appendingPathComponent(".lumi/rules", isDirectory: true),
            withIntermediateDirectories: true
        )
        return root
    }

    private func writeRule(filename: String, title: String, in project: URL) throws {
        try "# \(title)\n\nBody.".write(
            to: project.appendingPathComponent(".lumi/rules/\(filename)"),
            atomically: true,
            encoding: .utf8
        )
    }

    private func ruleURL(_ filename: String, in project: URL) -> URL {
        project.appendingPathComponent(".lumi/rules/\(filename)")
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

    /// 把 UI 当前打开的项目设为 B，模拟用户已切换到另一个项目。
    private func selectCurrentProject(_ project: URL) async throws {
        let provider = DefaultProjectProvider()
        try await provider.openProject(at: project.path)
        AgentRulesRuntime.configure(project: provider)
    }

    /// 只清空当前项目，保留 `settingsDirectory` 注入，避免干扰其它测试。
    private func clearCurrentProject() {
        AgentRulesRuntime.configure(project: nil)
    }

    @Test("list_agent_rules 读取会话绑定的项目，而不是 UI 当前项目")
    func listToolUsesConversationProject() async throws {
        let projectA = try makeProject("a")
        let projectB = try makeProject("b")
        defer {
            clearCurrentProject()
            try? FileManager.default.removeItem(at: projectA)
            try? FileManager.default.removeItem(at: projectB)
        }
        try writeRule(filename: "from-a.md", title: "From A", in: projectA)
        try writeRule(filename: "from-b.md", title: "From B", in: projectB)

        try await selectCurrentProject(projectB)

        let result = try await ListAgentRulesTool().executeResult(
            context: makeContext(projectPath: projectA.path),
            arguments: [:]
        )

        #expect(result.content.contains("from-a.md"))
        #expect(!result.content.contains("from-b.md"))
    }

    @Test("create_agent_rule 写入会话绑定的项目，而不是 UI 当前项目")
    func createToolWritesIntoConversationProject() async throws {
        let projectA = try makeProject("a")
        let projectB = try makeProject("b")
        defer {
            clearCurrentProject()
            try? FileManager.default.removeItem(at: projectA)
            try? FileManager.default.removeItem(at: projectB)
        }

        try await selectCurrentProject(projectB)

        _ = try await CreateAgentRuleTool().executeResult(
            context: makeContext(projectPath: projectA.path),
            arguments: arguments([
                "filename": "scoped",
                "title": "Scoped",
                "content": "Body.",
            ])
        )

        #expect(FileManager.default.fileExists(atPath: ruleURL("scoped.md", in: projectA).path))
        #expect(!FileManager.default.fileExists(atPath: ruleURL("scoped.md", in: projectB).path))
    }

    @Test("显式 project_path 优先于会话绑定项目")
    func explicitProjectPathBeatsConversationProject() async throws {
        let projectA = try makeProject("a")
        let projectB = try makeProject("b")
        defer {
            clearCurrentProject()
            try? FileManager.default.removeItem(at: projectA)
            try? FileManager.default.removeItem(at: projectB)
        }

        try await selectCurrentProject(projectB)

        _ = try await CreateAgentRuleTool().executeResult(
            context: makeContext(projectPath: projectA.path),
            arguments: arguments([
                "project_path": projectB.path,
                "filename": "explicit",
                "title": "Explicit",
                "content": "Body.",
            ])
        )

        #expect(FileManager.default.fileExists(atPath: ruleURL("explicit.md", in: projectB).path))
        #expect(!FileManager.default.fileExists(atPath: ruleURL("explicit.md", in: projectA).path))
    }
}
