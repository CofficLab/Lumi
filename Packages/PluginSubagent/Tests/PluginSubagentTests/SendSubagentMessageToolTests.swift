import Foundation
import KitAgentTool
import ProviderAgentLoop
import ProviderMessage
import ProviderToolManager
import Testing
@testable import PluginSubagent

/// #1328 Task 4/5：代理间消息的投递语义。
///
/// 关键不变量：`queue` 绝不启动回合；`followup` 在空闲/终态时唤醒、运行中
/// 等回合结束再唤醒；重复终态事件只唤醒一次；消息带来源标记并可持久化。
@MainActor
@Suite(.serialized)
struct SendSubagentMessageToolTests {

    private func makeTool(
        _ fixture: SubagentTestFixture
    ) -> (tool: SendSubagentMessageTool, inbox: SubagentInboxCoordinator) {
        let inbox = SubagentInboxCoordinator(messages: fixture.messages, agentLoop: fixture.agentLoop)
        return (SendSubagentMessageTool(registry: fixture.registry, inbox: inbox), inbox)
    }

    private func context(_ conversationID: UUID) -> ToolExecutionContext {
        ToolExecutionContext(jobID: "job-send", conversationID: conversationID)
    }

    private func arguments(to: String, message: String = "Please check auth.swift", mode: String? = nil) -> [String: ToolArgument] {
        var args: [String: ToolArgument] = [
            "to": ToolArgument(to),
            "message": ToolArgument(message),
        ]
        if let mode {
            args["mode"] = ToolArgument(mode)
        }
        return args
    }

    @Test("queue 只写入消息，不启动回合，并恢复自动回复状态")
    func queueDeliversWithoutStartingTurn() async throws {
        let fixture = try SubagentTestFixture()
        defer { fixture.cleanup() }
        let rootID = try await fixture.makeRoot()
        let editor = try await fixture.makeChild(of: rootID, label: "Editor", name: "editor", jobID: "job-editor")
        let (tool, inbox) = makeTool(fixture)

        let result = try await tool.executeResult(
            context: context(rootID),
            arguments: arguments(to: "editor", mode: "queue")
        )

        #expect(result.content.contains("Queued"))
        #expect(result.content.contains("Message ID:"))
        #expect(result.content.contains("not a reply"))
        #expect(fixture.agentLoop.runTurnCalls.isEmpty)
        #expect(fixture.agentLoop.autoReplySuppressed.isEmpty)
        #expect(inbox.pendingMessageCount(for: editor) == 1)

        let message = try #require(fixture.messages.messages(for: editor).last)
        #expect(message.role == .user)
        #expect(message.content.contains("another agent, not from your user"))
        #expect(message.content.contains("Please check auth.swift"))
        #expect(message.metadata[SubagentMessageProvenance.senderNameKey] == "lead")
        #expect(message.metadata[SubagentMessageProvenance.senderConversationIDKey] == rootID.uuidString)
    }

    @Test("followup 到空闲目标会立即启动回合")
    func followupWakesIdleTarget() async throws {
        let fixture = try SubagentTestFixture()
        defer { fixture.cleanup() }
        let rootID = try await fixture.makeRoot()
        let editor = try await fixture.makeChild(of: rootID, label: "Editor", name: "editor", jobID: "job-editor")
        let (tool, inbox) = makeTool(fixture)

        let result = try await tool.executeResult(
            context: context(rootID),
            arguments: arguments(to: "editor", mode: "followup")
        )
        #expect(result.content.contains("a turn has been started"))

        try await subagentWaitUntil { fixture.agentLoop.runTurnCalls == [editor] }
        #expect(inbox.pendingMessageCount(for: editor) == 0)
    }

    @Test("followup 到运行中目标要等终态事件，重复终态只唤醒一次")
    func followupWaitsForRunningTurnExactlyOnce() async throws {
        let fixture = try SubagentTestFixture()
        defer { fixture.cleanup() }
        let rootID = try await fixture.makeRoot()
        let editor = try await fixture.makeChild(of: rootID, label: "Editor", name: "editor", jobID: "job-editor")
        fixture.agentLoop.runningConversationIDs.insert(editor)
        let (tool, _) = makeTool(fixture)

        let result = try await tool.executeResult(
            context: context(rootID),
            arguments: arguments(to: "editor", mode: "followup")
        )
        #expect(result.content.contains("was running"))
        #expect(fixture.agentLoop.runTurnCalls.isEmpty)

        fixture.agentLoop.runningConversationIDs.remove(editor)
        fixture.agentLoop.emit(.completed(conversationID: editor, turnID: UUID()))
        fixture.agentLoop.emit(.completed(conversationID: editor, turnID: UUID()))

        try await subagentWaitUntil { !fixture.agentLoop.runTurnCalls.isEmpty }
        try await Task.sleep(nanoseconds: 60_000_000)
        #expect(fixture.agentLoop.runTurnCalls == [editor])
    }

    @Test("queue 到运行中目标在回合结束后也不会被唤醒")
    func queueDoesNotWakeOnTurnEnd() async throws {
        let fixture = try SubagentTestFixture()
        defer { fixture.cleanup() }
        let rootID = try await fixture.makeRoot()
        let editor = try await fixture.makeChild(of: rootID, label: "Editor", name: "editor", jobID: "job-editor")
        fixture.agentLoop.runningConversationIDs.insert(editor)
        let (tool, _) = makeTool(fixture)

        _ = try await tool.executeResult(
            context: context(rootID),
            arguments: arguments(to: "editor", mode: "queue")
        )
        fixture.agentLoop.runningConversationIDs.remove(editor)
        fixture.agentLoop.emit(.completed(conversationID: editor, turnID: UUID()))
        try await Task.sleep(nanoseconds: 60_000_000)

        #expect(fixture.agentLoop.runTurnCalls.isEmpty)
    }

    @Test("子代理可以联系 lead 与兄弟，来源名是它自己")
    func childCanMessageLeadAndSibling() async throws {
        let fixture = try SubagentTestFixture()
        defer { fixture.cleanup() }
        let rootID = try await fixture.makeRoot()
        let explorer = try await fixture.makeChild(of: rootID, label: "Explorer", name: "explorer", jobID: "job-explorer")
        let editor = try await fixture.makeChild(of: rootID, label: "Editor", name: "editor", jobID: "job-editor")
        let (tool, _) = makeTool(fixture)

        _ = try await tool.executeResult(
            context: context(explorer),
            arguments: arguments(to: "lead", message: "I found the caller.", mode: "queue")
        )
        let toLead = try #require(fixture.messages.messages(for: rootID).last)
        #expect(toLead.metadata[SubagentMessageProvenance.senderNameKey] == "explorer")
        #expect(toLead.content.contains("I found the caller."))
        #expect(fixture.agentLoop.runTurnCalls.isEmpty)

        _ = try await tool.executeResult(
            context: context(explorer),
            arguments: arguments(to: "editor", message: "Don't delete it yet.", mode: "queue")
        )
        let toSibling = try #require(fixture.messages.messages(for: editor).last)
        #expect(toSibling.metadata[SubagentMessageProvenance.senderNameKey] == "explorer")
    }

    @Test("不能给自己、未知名字、跨树成员或重名目标发消息")
    func rejectsInvalidTargets() async throws {
        let fixture = try SubagentTestFixture()
        defer { fixture.cleanup() }
        let rootID = try await fixture.makeRoot()
        let explorer = try await fixture.makeChild(of: rootID, label: "Explorer", name: "explorer", jobID: "job-explorer")
        _ = try await fixture.makeChild(of: rootID, label: "Twin A", name: "twin", jobID: "job-twin-a")
        _ = try await fixture.makeChild(of: rootID, label: "Twin B", name: "twin", jobID: "job-twin-b")
        let otherRoot = try await fixture.makeRoot()
        _ = try await fixture.makeChild(of: otherRoot, label: "Outsider", name: "outsider", jobID: "job-outsider")
        let (tool, _) = makeTool(fixture)

        await #expect(throws: ToolExecutionError.self) {
            _ = try await tool.executeResult(context: context(rootID), arguments: arguments(to: "lead"))
        }
        await #expect(throws: ToolExecutionError.self) {
            _ = try await tool.executeResult(context: context(explorer), arguments: arguments(to: "explorer"))
        }
        await #expect(throws: ToolExecutionError.self) {
            _ = try await tool.executeResult(context: context(rootID), arguments: arguments(to: "missing"))
        }
        await #expect(throws: ToolExecutionError.self) {
            _ = try await tool.executeResult(context: context(rootID), arguments: arguments(to: "outsider"))
        }
        await #expect(throws: ToolExecutionError.self) {
            _ = try await tool.executeResult(context: context(rootID), arguments: arguments(to: "twin"))
        }
        #expect(fixture.messages.messages(for: rootID).count == 3)
    }

    @Test("缺少参数、非法模式或会话不存在时抛错")
    func rejectsInvalidArguments() async throws {
        let fixture = try SubagentTestFixture()
        defer { fixture.cleanup() }
        let rootID = try await fixture.makeRoot()
        _ = try await fixture.makeChild(of: rootID, label: "Editor", name: "editor", jobID: "job-editor")
        let (tool, _) = makeTool(fixture)

        await #expect(throws: ToolExecutionError.self) {
            _ = try await tool.executeResult(context: context(rootID), arguments: ["message": ToolArgument("hi")])
        }
        await #expect(throws: ToolExecutionError.self) {
            _ = try await tool.executeResult(context: context(rootID), arguments: ["to": ToolArgument("editor")])
        }
        await #expect(throws: ToolExecutionError.self) {
            _ = try await tool.executeResult(
                context: context(rootID),
                arguments: arguments(to: "editor", mode: "shout")
            )
        }
        await #expect(throws: ToolExecutionError.self) {
            _ = try await tool.execute(arguments: arguments(to: "editor"))
        }
        await #expect(throws: ToolExecutionError.self) {
            _ = try await tool.executeResult(context: context(UUID()), arguments: arguments(to: "editor"))
        }
    }

    @Test("子会话工具表显式放行通信工具，但仍排除委托工具")
    func childToolAllowlist() {
        let tools: [any SuperAgentTool] = [
            StubTool(name: "read_file", capability: .parallelReadOnly),
            StubTool(name: SubagentToolPolicy.messagingToolName, capability: .serialSideEffect),
            StubTool(name: SubagentToolPolicy.delegationToolName, capability: .parallelReadOnly),
            StubTool(name: "edit_file", capability: .serialSideEffect),
        ]
        let names = SubagentToolPolicy.childTools(from: tools).map(\.name)

        #expect(names.contains("read_file"))
        #expect(names.contains(SubagentToolPolicy.messagingToolName))
        #expect(names.contains(SubagentToolPolicy.delegationToolName) == false)
        #expect(names.contains("edit_file") == false)
    }
}

private struct StubTool: SuperAgentTool {
    let name: String
    let capability: ToolExecutionCapability

    var executionCapability: ToolExecutionCapability { capability }

    func description(for language: LanguagePreference) -> String { "" }
    func inputSchema(for language: LanguagePreference) -> [String: Any] { [:] }
    func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel { .low }
    func displayDescription(for arguments: [String: ToolArgument]) -> String { name }
    func execute(arguments: [String: ToolArgument]) async throws -> String { "" }
    func executeResult(arguments: [String: ToolArgument]) async throws -> ToolCallResult {
        ToolCallResult(content: "")
    }
}
