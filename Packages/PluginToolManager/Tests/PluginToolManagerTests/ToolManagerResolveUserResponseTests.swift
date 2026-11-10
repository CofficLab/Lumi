import Foundation
import KitAgentTool
import ProviderToolManager
import Testing
@testable import PluginToolManager

private actor ResumeExecutionCounter {
    private(set) var executions = 0

    func next() -> Int {
        executions += 1
        return executions
    }
}

/// 模拟 Computer Use：首次执行挂起等授权，授权后重新执行返回真实结果。
private struct SuspendingAuthorizationStubTool: SuperAgentTool, @unchecked Sendable {
    let name = "computer_observe_stub"
    let counter: ResumeExecutionCounter

    func description(for language: LanguagePreference) -> String { name }
    func inputSchema(for language: LanguagePreference) -> [String: Any] { [:] }
    func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel { .low }
    func displayDescription(for arguments: [String: ToolArgument]) -> String { name }
    func execute(arguments: [String: ToolArgument]) async throws -> String { "unused" }

    func executeResult(arguments: [String: ToolArgument]) async throws -> ToolCallResult {
        let execution = await counter.next()
        if execution == 1 {
            return ToolCallResult(
                content: "authorization_required",
                awaitingUserResponse: true,
                interactionState: .waiting
            )
        }
        return ToolCallResult(content: "observation-\(execution)")
    }

    func userResponseAction(
        for answer: String,
        arguments: [String: ToolArgument]
    ) -> ToolUserResponseAction {
        _ = arguments
        let token = answer
            .split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: false)
            .first.map(String.init)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? answer
        switch token {
        case "computer_use.allow_for_task": return .reexecute
        case "computer_use.deny": return .reject(reason: "denied")
        default: return .returnAnswer
        }
    }
}

/// 普通挂起工具（如 ask_user）：回答就是结果本身。
private struct AnswerOnlyStubTool: SuperAgentTool, @unchecked Sendable {
    let name = "answer_only_stub"
    let counter: ResumeExecutionCounter

    func description(for language: LanguagePreference) -> String { name }
    func inputSchema(for language: LanguagePreference) -> [String: Any] { [:] }
    func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel { .low }
    func displayDescription(for arguments: [String: ToolArgument]) -> String { name }
    func execute(arguments: [String: ToolArgument]) async throws -> String { "unused" }

    func executeResult(arguments: [String: ToolArgument]) async throws -> ToolCallResult {
        _ = await counter.next()
        return ToolCallResult(content: "waiting", awaitingUserResponse: true)
    }
}

@MainActor
@Test func resolveUserResponseReexecutesAfterAuthorization() async {
    let manager = ToolManager()
    let counter = ResumeExecutionCounter()
    manager.add(SuspendingAuthorizationStubTool(counter: counter), pluginID: "test")
    let conversationID = UUID()
    let turnID = UUID()
    let call = ToolCall(id: "observe-1", name: "computer_observe_stub", arguments: "{}")

    let suspended = await manager.execute(call, conversationID: conversationID, turnID: turnID)
    #expect(suspended.awaitingUserResponse)

    let resumed = await manager.resolveUserResponse(
        "computer_use.allow_for_task\nAccess granted for this task",
        for: call,
        conversationID: conversationID,
        turnID: turnID
    )

    // 挂起结果被缓存；必须失效后才能拿到真实观察结果。
    #expect(!resumed.awaitingUserResponse)
    #expect(!resumed.isError)
    #expect(resumed.content == "observation-2")
    let executions = await counter.executions
    #expect(executions == 2)
}

@MainActor
@Test func resolveUserResponseRejectionDoesNotReexecute() async {
    let manager = ToolManager()
    let counter = ResumeExecutionCounter()
    manager.add(SuspendingAuthorizationStubTool(counter: counter), pluginID: "test")
    let conversationID = UUID()
    let turnID = UUID()
    let call = ToolCall(id: "observe-2", name: "computer_observe_stub", arguments: "{}")

    _ = await manager.execute(call, conversationID: conversationID, turnID: turnID)

    let resumed = await manager.resolveUserResponse(
        "computer_use.deny\nThe user denied access",
        for: call,
        conversationID: conversationID,
        turnID: turnID
    )

    // 拒绝不能重执行：授权没有落地，重执行只会再次挂起等一个已回答的问题。
    #expect(resumed.isError)
    #expect(resumed.content == "denied")
    let executions = await counter.executions
    #expect(executions == 1)
}

@MainActor
@Test func resolveUserResponseKeepsAnswerOnlyBehaviourByDefault() async {
    let manager = ToolManager()
    let counter = ResumeExecutionCounter()
    manager.add(AnswerOnlyStubTool(counter: counter), pluginID: "test")
    let conversationID = UUID()
    let turnID = UUID()
    let call = ToolCall(id: "answer-1", name: "answer_only_stub", arguments: "{}")

    _ = await manager.execute(call, conversationID: conversationID, turnID: turnID)

    let resumed = await manager.resolveUserResponse(
        "my answer",
        for: call,
        conversationID: conversationID,
        turnID: turnID
    )

    #expect(resumed.content == "my answer")
    #expect(!resumed.isError)
    let executions = await counter.executions
    #expect(executions == 1)
}
