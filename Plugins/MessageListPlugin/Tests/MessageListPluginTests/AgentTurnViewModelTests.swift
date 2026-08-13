import Foundation
import KernelLumi
import Testing
@testable import MessageListPlugin

struct AgentTurnViewModelTests {
    private let conversationID = UUID()

    @Test("最后一条回复直接展示,此前回复都归入过程")
    func lastResponseIsVisibleAndEarlierResponsesAreProcess() throws {
        let turnID = UUID()
        let base = Date(timeIntervalSinceReferenceDate: 5_000)
        let user = LumiChatMessage(
            conversationID: conversationID,
            role: .user,
            content: "用户问题",
            createdAt: base
        )
        let status = LumiChatMessage(
            conversationID: conversationID,
            role: .status,
            content: "正在思考…",
            createdAt: base.addingTimeInterval(1)
        )
        let toolCall = LumiChatMessage(
            conversationID: conversationID,
            role: .assistant,
            content: "搜索文件",
            turnID: turnID,
            createdAt: base.addingTimeInterval(2),
            toolCalls: [LumiToolCall(id: "search", name: "search", arguments: "{}")]
        )
        let final = LumiChatMessage(
            conversationID: conversationID,
            role: .assistant,
            content: "最终回答",
            turnID: turnID,
            createdAt: base.addingTimeInterval(3)
        )
        let record = AgentTurnRecord(
            id: turnID,
            conversationID: conversationID,
            state: .completed,
            startedAt: base.addingTimeInterval(0.5),
            endedAt: base.addingTimeInterval(4)
        )
        let summary = try #require(AgentTurnSummaryBuilder().build(
            records: [record],
            messages: [user, status, toolCall, final]
        ).first)
        let item = AgentTurnPresentationItem(recorded: summary, acceptsLiveActivity: false)

        let projection = AgentTurnViewModel.project(
            item: item,
            messages: [user, status, toolCall, final],
            streamingMessage: nil
        )

        #expect(projection.userMessages.map(\.id) == [user.id])
        #expect(projection.processMessages.map(\.id) == [toolCall.id])
        #expect(projection.lastMessage?.id == final.id)
    }

    @Test("流式消息成为最后一条,瞬时状态独立展示")
    func streamingMessageBecomesLastResponse() throws {
        let turnID = UUID()
        let base = Date(timeIntervalSinceReferenceDate: 6_000)
        let status = LumiChatMessage(
            conversationID: conversationID,
            role: .status,
            content: "正在思考…",
            createdAt: base
        )
        let streaming = LumiChatMessage(
            id: LumiStreamingRowID,
            conversationID: conversationID,
            role: .assistant,
            content: "正在生成",
            createdAt: base.addingTimeInterval(1)
        )
        let record = AgentTurnRecord(
            id: turnID,
            conversationID: conversationID,
            state: .running,
            startedAt: base
        )
        let summary = try #require(AgentTurnSummaryBuilder().build(
            records: [record],
            messages: [status]
        ).first)
        let item = AgentTurnPresentationItem(recorded: summary, acceptsLiveActivity: true)

        let projection = AgentTurnViewModel.project(
            item: item,
            messages: [status],
            streamingMessage: streaming,
            streamingStage: .generating
        )

        #expect(projection.processMessages.isEmpty)
        #expect(projection.lastMessage?.id == LumiStreamingRowID)
        #expect(projection.activityMessage?.content == "正在思考…")
        #expect(projection.activityMessage?.id != status.id)

        var updatedStatus = status
        updatedStatus.content = "正在读取文件…"
        let updatedProjection = AgentTurnViewModel.project(
            item: item,
            messages: [updatedStatus],
            streamingMessage: streaming,
            streamingStage: .generating
        )
        #expect(updatedProjection.activityMessage?.id == projection.activityMessage?.id)
        #expect(updatedProjection.activityMessage?.content == "正在读取文件…")
    }

    @Test("没有具体状态时使用流式阶段文案兜底")
    func streamingStageProvidesFallbackActivity() {
        let user = LumiChatMessage(
            conversationID: conversationID,
            role: .user,
            content: "你好"
        )
        let item = AgentTurnPresentationItem(
            pendingUserMessages: [user],
            statusMessage: nil
        )

        let projection = AgentTurnViewModel.project(
            item: item,
            messages: [user],
            streamingMessage: nil,
            streamingStage: .sending
        )

        #expect(projection.lastMessage == nil)
        #expect(projection.activityMessage?.role == .status)
        #expect(projection.activityMessage?.content == "正在发送消息…")
    }

    @Test("非活跃 Turn 不接收会话动态状态")
    func inactiveTurnDoesNotReceiveActivity() throws {
        let turnID = UUID()
        let base = Date(timeIntervalSinceReferenceDate: 7_000)
        let status = LumiChatMessage(
            conversationID: conversationID,
            role: .status,
            content: "正在读取文件…",
            createdAt: base
        )
        let record = AgentTurnRecord(
            id: turnID,
            conversationID: conversationID,
            state: .completed,
            startedAt: base,
            endedAt: base.addingTimeInterval(1)
        )
        let summary = try #require(AgentTurnSummaryBuilder().build(
            records: [record],
            messages: [status]
        ).first)
        let item = AgentTurnPresentationItem(recorded: summary, acceptsLiveActivity: false)

        let projection = AgentTurnViewModel.project(
            item: item,
            messages: [status],
            streamingMessage: nil,
            streamingStage: .thinking
        )

        #expect(projection.activityMessage == nil)
        #expect(projection.processMessages.isEmpty)
    }

    @Test("工具原始输出不会进入过程或最后一条")
    func toolResultsAreFiltered() throws {
        let user = LumiChatMessage(
            conversationID: conversationID,
            role: .user,
            content: "执行"
        )
        let toolResult = LumiChatMessage(
            conversationID: conversationID,
            role: .tool,
            content: "原始输出"
        )
        let item = AgentTurnPresentationItem(
            pendingUserMessages: [user],
            statusMessage: nil
        )

        let projection = AgentTurnViewModel.project(
            item: item,
            messages: [user, toolResult],
            streamingMessage: nil
        )

        #expect(projection.processMessages.isEmpty)
        #expect(projection.lastMessage == nil)
    }

    @Test("过程标题显示已完成 Turn 的固定耗时与条数")
    func completedTurnProcessTitleUsesRecordedDuration() {
        let startedAt = Date(timeIntervalSinceReferenceDate: 10_000)
        let record = AgentTurnRecord(
            id: UUID(),
            conversationID: conversationID,
            state: .completed,
            startedAt: startedAt,
            endedAt: startedAt.addingTimeInterval(125)
        )
        let item = AgentTurnPresentationItem(
            recorded: AgentTurnSummaryItem(
                record: record,
                userMessage: nil,
                processMessages: [],
                message: LumiChatMessage(
                    conversationID: conversationID,
                    role: .assistant,
                    content: "完成"
                )
            ),
            acceptsLiveActivity: false
        )

        let title = AgentTurnViewModel.processDisclosureTitle(
            item: item,
            userMessages: [],
            processCount: 2,
            now: startedAt.addingTimeInterval(999)
        )

        #expect(title == "耗时2分钟 2条")
    }

    @Test("运行中 Turn 的过程耗时使用当前时间")
    func runningTurnProcessTitleUsesCurrentTime() {
        let startedAt = Date(timeIntervalSinceReferenceDate: 20_000)
        let record = AgentTurnRecord(
            id: UUID(),
            conversationID: conversationID,
            state: .running,
            startedAt: startedAt
        )
        let item = AgentTurnPresentationItem(
            recorded: AgentTurnSummaryItem(
                record: record,
                userMessage: nil,
                processMessages: [],
                message: LumiChatMessage(
                    conversationID: conversationID,
                    role: .status,
                    content: "…"
                )
            ),
            acceptsLiveActivity: true
        )

        let title = AgentTurnViewModel.processDisclosureTitle(
            item: item,
            userMessages: [],
            processCount: 3,
            now: startedAt.addingTimeInterval(9)
        )

        #expect(title == "耗时9秒 3条")
    }
}
