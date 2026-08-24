import Foundation
import Testing
import KernelLumi
@testable import MessageListAppKitPlugin

struct TimelineProjectorTests {
    private func fixture() throws -> FixtureLoader.MixedMessagesFixture {
        try FixtureLoader.mixedMessages()
    }

    private func streamingMessage(conversationID: UUID) -> LumiChatMessage {
        LumiChatMessage(
            conversationID: conversationID,
            role: .assistant,
            content: "正在生成回复…",
            providerID: "zhipu",
            modelName: "glm-4-plus"
        )
    }

    // MARK: - Standard / idle

    @Test("standard+idle：保留全部历史，工具执行助手消息合并为步骤组")
    func standardIdleKeepsAllAndMergesToolExecution() throws {
        let f = try fixture()
        let rows = TimelineProjector().projectHistory(.init(
            persisted: f.messages,
            verbosity: .standard
        ))

        #expect(rows.count == 11)

        // B004（content "..." + toolCalls）合并为 toolStepGroup 行。
        let merged = rows[3]
        #expect(merged.kind == .toolStepGroup)
        #expect(merged.message.id == UUID(uuidString: "B0000000-0000-0000-0000-000000000004"))
        #expect(merged.message.renderKind == "turn-activity")
        #expect(merged.message.toolCalls?.count == 1)

        // 其余行按原顺序保留。
        #expect(rows[0].message.role == .system)
        #expect(rows[4].message.role == .tool)
        #expect(rows[7].kind == .status)
        #expect(rows[8].message.role == .error)
    }

    @Test("standard+idle：无流式行")
    func noStreamingWhenIdle() throws {
        let f = try fixture()
        let input = TimelineProjector.Input(
            persisted: f.messages,
            verbosity: .standard
        )
        #expect(TimelineProjector().projectStreamingRow(input) == nil)
    }

    // MARK: - Verbosity: brief drops tool rows

    @Test("brief+idle：剔除独立 tool 行，保留 status")
    func briefDropsToolRows() throws {
        let f = try fixture()
        let rows = TimelineProjector().projectHistory(.init(
            persisted: f.messages,
            verbosity: .brief
        ))

        #expect(rows.count == 10)
        #expect(rows.contains { $0.message.role == .tool } == false)
        #expect(rows.contains { $0.kind == .status } == true)
    }

    // MARK: - Streaming stages

    @Test("thinking 阶段：剔除 status，尾部附加流式行")
    func thinkingDropsStatusAndAppendsStreaming() throws {
        let f = try fixture()
        let streaming = streamingMessage(conversationID: f.conversationID)
        let input = TimelineProjector.Input(
            persisted: f.messages,
            verbosity: .standard,
            streamingStage: .thinking,
            streamingRow: streaming
        )
        let rows = TimelineProjector().project(input)

        #expect(rows.count == 11) // 10 history + 1 streaming
        #expect(rows.contains { $0.kind == .status } == false)

        let tail = rows.last
        #expect(tail?.kind == .streaming)
        #expect(tail?.id == LumiStreamingRowID.uuidString)
        #expect(tail?.content == "正在生成回复…")
    }

    @Test("sending 阶段：保留 status，不显示流式行")
    func sendingKeepsStatusWithoutStreaming() throws {
        let f = try fixture()
        let streaming = streamingMessage(conversationID: f.conversationID)
        let input = TimelineProjector.Input(
            persisted: f.messages,
            verbosity: .standard,
            streamingStage: .sending,
            streamingRow: streaming
        )
        let rows = TimelineProjector().project(input)

        #expect(rows.count == 11)
        #expect(rows.contains { $0.kind == .status } == true)
        #expect(rows.contains { $0.kind == .streaming } == false)
    }

    @Test("thinking 但 streamingRow 为空：不显示流式行、不剔 status")
    func thinkingWithoutStreamingRowShowsStatus() throws {
        let f = try fixture()
        let input = TimelineProjector.Input(
            persisted: f.messages,
            verbosity: .standard,
            streamingStage: .thinking,
            streamingRow: nil
        )
        let rows = TimelineProjector().project(input)

        #expect(rows.count == 11)
        #expect(rows.contains { $0.kind == .status } == true)
    }

    // MARK: - Tool execution merging

    @Test("同 turn 连续 tool-execution-only 消息合并为单行，id 取组首")
    func consecutiveToolExecutionMerged() {
        let conversation = UUID()
        let turn = UUID()
        let first = LumiChatMessage(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            conversationID: conversation,
            role: .assistant,
            content: "...",
            turnID: turn,
            createdAt: Date(timeIntervalSince1970: 100),
            toolCalls: [LumiToolCall(id: "a", name: "tool_a", arguments: "{}")]
        )
        let second = LumiChatMessage(
            id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
            conversationID: conversation,
            role: .assistant,
            content: "...",
            turnID: turn,
            createdAt: Date(timeIntervalSince1970: 101),
            toolCalls: [LumiToolCall(id: "b", name: "tool_b", arguments: "{}")]
        )
        let closing = LumiChatMessage(
            conversationID: conversation,
            role: .assistant,
            content: "完成",
            turnID: turn,
            createdAt: Date(timeIntervalSince1970: 102)
        )

        let merged = TimelineProjector.mergeConsecutiveToolExecutionMessages(
            [first, second, closing]
        )
        #expect(merged.count == 2)
        let group = merged[0]
        #expect(group.id == first.id)
        #expect(group.renderKind == "turn-activity")
        #expect(group.toolCalls?.map(\.id) == ["a", "b"])
        #expect(merged[1].content == "完成")
    }

    @Test("无 turnID 的历史 tool-execution 消息使用 tool-step-group 标记")
    func legacyToolExecutionUsesToolStepGroupKind() {
        let conversation = UUID()
        let legacy = LumiChatMessage(
            conversationID: conversation,
            role: .assistant,
            content: "...",
            turnID: nil,
            createdAt: Date(timeIntervalSince1970: 100),
            toolCalls: [LumiToolCall(id: "a", name: "tool_a", arguments: "{}")]
        )
        let merged = TimelineProjector.mergeConsecutiveToolExecutionMessages([legacy])
        #expect(merged.count == 1)
        #expect(merged[0].renderKind == "tool-step-group")
    }

    // MARK: - Row conversion

    @Test("普通消息转行为对应角色 kind")
    func rowKindConversion() throws {
        let f = try fixture()
        let rows = TimelineProjector().projectHistory(.init(
            persisted: f.messages,
            verbosity: .standard
        ))
        #expect(rows[0].kind == .system)
        #expect(rows[1].kind == .user)
        #expect(rows[2].kind == .assistant)
        #expect(rows[4].kind == .tool)
        #expect(rows[7].kind == .status)
        #expect(rows[8].kind == .error)
    }
}
