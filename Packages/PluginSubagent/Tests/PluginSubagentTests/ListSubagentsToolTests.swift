import Foundation
import KitAgentTool
import ProviderToolManager
import Testing
@testable import PluginSubagent

/// #1328 Task 3：`list_subagents` 的输出契约。
///
/// 表里的名字就是后续 `send_subagent_message` 的寻址依据，因此测试既锁
/// 内容（名字/状态/时长/投递方式），也锁「谁是调用方」与不可寻址的旧条目。
@MainActor
@Suite(.serialized)
struct ListSubagentsToolTests {
    private let base = Date(timeIntervalSince1970: 10_000)

    private func makeTool(_ fixture: SubagentTestFixture, now: Date? = nil) -> ListSubagentsTool {
        let fixed = now ?? base
        return ListSubagentsTool(registry: fixture.registry, now: { fixed })
    }

    private func context(_ conversationID: UUID) -> ToolExecutionContext {
        ToolExecutionContext(jobID: "job-list", conversationID: conversationID)
    }

    @Test("列出 lead 与子代理的实时状态、时长和投递方式")
    func listsLeadAndMembers() async throws {
        let fixture = try SubagentTestFixture()
        defer { fixture.cleanup() }
        let rootID = try await fixture.makeRoot()
        let explorer = try await fixture.makeChild(
            of: rootID, label: "Research auth flow", name: "explorer", jobID: "job-explorer",
            createdAt: base, status: .running
        )
        fixture.agentLoop.runningConversationIDs.insert(explorer)
        fixture.toolManager.jobsByID["job-explorer"]?.startedAt = base

        let editor = try await fixture.makeChild(
            of: rootID, label: "Edit auth module", name: "editor", jobID: "job-editor",
            createdAt: base, status: .completed
        )
        fixture.toolManager.jobsByID["job-editor"]?.startedAt = base
        fixture.toolManager.jobsByID["job-editor"]?.completedAt = base.addingTimeInterval(184)

        let tool = makeTool(fixture, now: base.addingTimeInterval(120))
        let result = try await tool.executeResult(
            context: context(rootID),
            arguments: [:]
        )
        let output = result.content

        #expect(output.contains("NAME"))
        #expect(output.contains("DELIVERY"))
        #expect(output.contains("lead"))
        #expect(output.contains("explorer"))
        #expect(output.contains("running"))
        #expect(output.contains("2m 00s"))
        #expect(output.contains("Research auth flow"))
        #expect(output.contains("messageable"))
        #expect(output.contains("editor"))
        #expect(output.contains("completed"))
        #expect(output.contains("3m 04s"))
        #expect(output.contains("resumable"))
        #expect(output.contains("You are lead."))
        #expect(output.contains("send_subagent_message"))
        #expect(output.contains(editor.uuidString) == false)
    }

    @Test("没有名字的历史卡片保留展示但标记为不可寻址")
    func legacyCardIsNotAddressable() async throws {
        let fixture = try SubagentTestFixture()
        defer { fixture.cleanup() }
        let rootID = try await fixture.makeRoot()
        _ = try await fixture.makeChild(
            of: rootID, label: "Legacy task", name: nil, jobID: "job-legacy",
            createdAt: base, status: .completed
        )

        let output = try await makeTool(fixture)
            .executeResult(context: context(rootID), arguments: [:])
            .content
        #expect(output.contains("(unnamed)"))
        #expect(output.contains("not addressable"))
    }

    @Test("子代理视角知道自己是谁并能看到兄弟")
    func childCallerSeesItselfAndSiblings() async throws {
        let fixture = try SubagentTestFixture()
        defer { fixture.cleanup() }
        let rootID = try await fixture.makeRoot()
        let explorer = try await fixture.makeChild(
            of: rootID, label: "Explorer", name: "explorer", jobID: "job-explorer",
            createdAt: base, status: .running
        )
        _ = try await fixture.makeChild(
            of: rootID, label: "Editor", name: "editor", jobID: "job-editor",
            createdAt: base, status: .running
        )

        let output = try await makeTool(fixture)
            .executeResult(context: context(explorer), arguments: [:])
            .content
        #expect(output.contains("You are explorer."))
        #expect(output.contains("lead"))
        #expect(output.contains("editor"))
    }

    @Test("空树只显示 lead 与创建提示")
    func emptyTree() async throws {
        let fixture = try SubagentTestFixture()
        defer { fixture.cleanup() }
        let rootID = try await fixture.makeRoot()

        let output = try await makeTool(fixture)
            .executeResult(context: context(rootID), arguments: [:])
            .content
        #expect(output.contains("lead"))
        #expect(output.contains("No subagents yet"))
        #expect(output.contains("run_subagent"))
    }

    @Test("缺少会话上下文时抛错而不是返回空表")
    func missingContextThrows() async throws {
        let fixture = try SubagentTestFixture()
        defer { fixture.cleanup() }
        let tool = makeTool(fixture)

        await #expect(throws: ToolExecutionError.self) {
            _ = try await tool.execute(arguments: [:])
        }
    }

    @Test("调用方会话已不存在时抛错")
    func missingConversationThrows() async throws {
        let fixture = try SubagentTestFixture()
        defer { fixture.cleanup() }
        let tool = makeTool(fixture)

        await #expect(throws: ToolExecutionError.self) {
            _ = try await tool.executeResult(context: context(UUID()), arguments: [:])
        }
    }

    @Test("工具元数据：只读并发、低风险、提示先查名字")
    func toolMetadata() throws {
        let fixture = try SubagentTestFixture()
        defer { fixture.cleanup() }
        let tool = ListSubagentsTool(registry: fixture.registry)

        #expect(tool.name == "list_subagents")
        #expect(tool.executionCapability == .parallelReadOnly)
        #expect(tool.permissionRiskLevel(arguments: [:]) == .low)
        let schema = tool.inputSchema(for: .english)
        #expect(schema["type"] as? String == "object")
        #expect((schema["properties"] as? [String: Any])?.isEmpty == true)
        #expect(tool.description(for: .english).contains("send_subagent_message"))
    }
}
