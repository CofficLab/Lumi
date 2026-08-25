import KitAgentTool
import Foundation
import Testing
@testable import ProviderToolManager

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

    @Test("execute 通过观察者发出 started 和 completed")
    func executeNotifiesObservers() async {
        let manager = DefaultToolManagerProviding()
        manager.add(MockTool(name: "read"), pluginID: "p")
        var events: [String] = []
        let handle = manager.addToolManagerObserver { event in
            switch event {
            case .started:
                events.append("started")
            case .completed:
                events.append("completed")
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
