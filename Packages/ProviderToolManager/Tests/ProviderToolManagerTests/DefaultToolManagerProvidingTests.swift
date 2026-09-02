import KitAgentTool
import Foundation
import Testing
@testable import ProviderToolManager

private struct ContextConversationTool: SuperAgentTool {
    let name = "context_conversation"

    func description(for language: LanguagePreference) -> String { "Context conversation" }
    func inputSchema(for language: LanguagePreference) -> [String: Any] { [:] }
    func permissionRiskLevel(arguments: [String: ToolArgument]) -> CommandRiskLevel { .low }
    func displayDescription(for arguments: [String: ToolArgument]) -> String { name }

    func execute(arguments: [String: ToolArgument]) async throws -> String {
        "legacy path"
    }

    func executeResult(
        context: ToolExecutionContext,
        arguments: [String: ToolArgument]
    ) async throws -> ToolCallResult {
        ToolCallResult(content: context.conversationID.uuidString)
    }
}

@MainActor
struct DefaultToolManagerProvidingTests {

    @Test("execute 成功返回内容并缓存结果")
    func executeSuccess() async {
        let manager = DefaultToolManagerProviding()
        manager.add(MockTool(name: "read"), pluginID: "p")

        let call = makeToolCall(name: "read", arguments: ["path": "/tmp/a.txt"])
        let result = await manager.execute(call, conversationID: UUID(), turnID: nil)

        #expect(!result.isError)
        #expect(result.content == "read /tmp/a.txt")
        #expect(result.duration != nil)

        // 结果缓存立即可查
        let cached = await manager.toolCallResult(for: call.id)
        #expect(cached?.content == "read /tmp/a.txt")
    }

    @Test("execute 将回合会话 ID 传给 Context-aware 工具")
    func executePassesConversationContext() async {
        let manager = DefaultToolManagerProviding()
        manager.add(ContextConversationTool(), pluginID: "p")
        let conversationID = UUID()

        let result = await manager.execute(
            makeToolCall(name: "context_conversation"),
            conversationID: conversationID,
            turnID: UUID()
        )

        #expect(result.content == conversationID.uuidString)
    }

    @Test("execute 通过观察者发出 started 和 completed")
    func executeNotifiesObservers() async {
        let manager = DefaultToolManagerProviding()
        manager.add(MockTool(name: "read"), pluginID: "p")
        var events: [String] = []
        let handle = manager.addToolManagerObserver { event in
            switch event {
            case .started:
                events.append("started")
            case .authorizationRequired:
                events.append("authorizationRequired")
            case .completed:
                events.append("completed")
            case .authorizedCompleted:
                events.append("authorizedCompleted")
            case .batchCompleted:
                events.append("batchCompleted")
            }
        }

        _ = await manager.execute(
            makeToolCall(name: "read"),
            conversationID: UUID(),
            turnID: UUID()
        )

        #expect(events == ["started", "completed"])
        handle.cancel()
    }

    @Test("execute 工具不存在返回错误")
    func executeToolNotFound() async {
        let manager = DefaultToolManagerProviding()
        let result = await manager.execute(
            makeToolCall(name: "missing"),
            conversationID: UUID(),
            turnID: nil
        )
        #expect(result.isError)
        #expect(result.content.contains("Tool not found"))
    }

    @Test("execute 工具抛错返回错误结果")
    func executeToolThrows() async {
        let manager = DefaultToolManagerProviding()
        manager.add(MockTool(name: "boom", failWith: "disk full"), pluginID: "p")

        let result = await manager.execute(
            makeToolCall(name: "boom"),
            conversationID: UUID(),
            turnID: nil
        )
        #expect(result.isError)
        #expect(result.content.contains("disk full"))
    }

    @Test("授权执行事件携带最终授权状态")
    func authorizedCompletionCarriesDecision() async {
        let manager = DefaultToolManagerProviding()
        manager.add(MockTool(name: "read"), pluginID: "p")
        var approvedState: ToolCallAuthorizationState?
        let handle = manager.addToolManagerObserver { event in
            if case let .authorizedCompleted(_, _, toolCall, _) = event {
                approvedState = toolCall.authorizationState
            }
        }

        _ = await manager.executeAuthorized(
            makeToolCall(name: "read"),
            conversationID: UUID(),
            turnID: nil
        )

        #expect(approvedState == .userApproved)
        handle.cancel()
    }

    @Test("拒绝授权事件携带最终授权状态")
    func rejectedCompletionCarriesDecision() async {
        let manager = DefaultToolManagerProviding()
        var rejectedState: ToolCallAuthorizationState?
        let handle = manager.addToolManagerObserver { event in
            if case let .authorizedCompleted(_, _, toolCall, _) = event {
                rejectedState = toolCall.authorizationState
            }
        }

        _ = await manager.rejectAuthorized(
            makeToolCall(name: "read"),
            conversationID: UUID(),
            turnID: nil
        )

        #expect(rejectedState == .userRejected)
        handle.cancel()
    }

    @Test("批次遇到高风险工具后立即暂停，不执行后续调用")
    func executeBatchStopsAtApproval() async {
        let manager = DefaultToolManagerProviding()
        manager.add(MockTool(name: "risky", risk: .high), pluginID: "p")
        manager.add(MockTool(name: "safe", risk: .low), pluginID: "p")
        var authorizationEventReceived = false
        let observer = manager.addToolManagerObserver { event in
            if case .authorizationRequired = event {
                authorizationEventReceived = true
            }
        }

        let results = await manager.executeBatch(
            [
                makeToolCall(name: "risky", id: "risky-1"),
                makeToolCall(name: "safe", id: "safe-1")
            ],
            policy: .requireApprovalForHighRisk,
            conversationID: UUID(),
            turnID: UUID()
        )

        #expect(results.count == 1)
        guard case .needsUserResponse = results[0] else {
            Issue.record("expected the first tool call to require user response")
            observer.cancel()
            return
        }
        #expect(authorizationEventReceived)
        observer.cancel()
    }

    @Test("execute 参数非 JSON 对象返回错误")
    func executeBadArguments() async {
        let manager = DefaultToolManagerProviding()
        manager.add(MockTool(name: "read"), pluginID: "p")

        let call = ToolCall(id: "c1", name: "read", arguments: "not json{")
        let result = await manager.execute(call, conversationID: UUID(), turnID: nil)
        #expect(result.isError)
    }

    @Test("删除会话后执行被拒绝")
    func executeAfterConversationDeleted() async {
        let manager = DefaultToolManagerProviding()
        manager.add(MockTool(name: "read"), pluginID: "p")
        let conversationID = UUID()

        await manager.deleteToolCalls(for: conversationID)
        let result = await manager.execute(
            makeToolCall(name: "read"),
            conversationID: conversationID,
            turnID: nil
        )
        #expect(result.isError)
        #expect(result.content.contains("deleted"))
    }

    @Test("toolCalls(for:) 无存储时返回空")
    func toolCallsWithoutStore() async {
        let manager = DefaultToolManagerProviding()
        let records = await manager.toolCalls(for: UUID())
        #expect(records.isEmpty)
    }

    @Test("toolCallResult 无存储且无缓存时返回 nil")
    func toolCallResultNil() async {
        let manager = DefaultToolManagerProviding()
        #expect(await manager.toolCallResult(for: "nope") == nil)
    }
}
