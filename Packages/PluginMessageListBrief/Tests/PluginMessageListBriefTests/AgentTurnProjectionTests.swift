import Foundation
import ProviderAgentLoop
import ProviderMessage
import Testing
@testable import PluginMessageListBrief

/// README §2 Turn layout / §3 Process disclosure / §7 Message content
/// / §8.4 message cap 的纯函数投影测试。
///
/// 这些 case 全部基于 `AgentTurnVM.project(...)` 静态方法与
/// `AgentTurnSummaryBuilder`，不需要任何 Provider；只要构造出真实的
/// `Message` / `AgentTurnRecord` 即可稳定地验证 V1 的展示契约。
@MainActor
struct AgentTurnProjectionTests {
    private let conversationID = UUID()

    // MARK: - §2.1 / §2.2 Turn layout — user 消息恰好一条

    @Test("finished turn 包含 user、process、last 三段且 user 恰好一条")
    func finishedTurnLayout() {
        let started = Date()
        let turnID = UUID()
        let user = Message(
            conversationID: conversationID,
            role: .user,
            content: "请总结一下",
            createdAt: started
        )
        let intermediate = Message(
            conversationID: conversationID,
            role: .assistant,
            content: "正在思考",
            createdAt: started.addingTimeInterval(1),
            turnID: turnID
        )
        let final = Message(
            conversationID: conversationID,
            role: .assistant,
            content: "已总结",
            createdAt: started.addingTimeInterval(2),
            turnID: turnID
        )
        let record = AgentTurnRecord(
            id: turnID,
            conversationID: conversationID,
            startedAt: started,
            endedAt: final.createdAt,
            state: .completed
        )
        let summary = AgentTurnSummaryBuilder()
            .build(records: [record], messages: [user, intermediate, final])
            .first!
        let item = AgentTurnPresentationItem(recorded: summary, acceptsLiveActivity: false)

        let projection = AgentTurnVM.project(item: item, messages: [user, intermediate, final])

        #expect(projection.userMessages.map(\.id) == [user.id])
        #expect(projection.processMessages.map(\.id) == [intermediate.id])
        #expect(projection.lastMessage?.id == final.id)
    }

    // MARK: - §2.3 第二条用户消息形成独立 turn

    @Test("同一时间线里两条 user 消息各属于一个 turn 不会合并")
    func twoUserMessagesRemainSeparateTurns() {
        let first = Date()
        let second = first.addingTimeInterval(60)
        let firstUser = Message(
            conversationID: conversationID,
            role: .user,
            content: "先做 A",
            createdAt: first
        )
        let firstReply = Message(
            conversationID: conversationID,
            role: .assistant,
            content: "A 完成",
            createdAt: first.addingTimeInterval(1),
            turnID: UUID()
        )
        let secondUser = Message(
            conversationID: conversationID,
            role: .user,
            content: "再做 B",
            createdAt: second
        )
        let secondReply = Message(
            conversationID: conversationID,
            role: .assistant,
            content: "B 完成",
            createdAt: second.addingTimeInterval(1),
            turnID: UUID()
        )
        let records = [
            AgentTurnRecord(
                id: firstReply.turnID!,
                conversationID: conversationID,
                startedAt: first,
                endedAt: firstReply.createdAt,
                state: .completed
            ),
            AgentTurnRecord(
                id: secondReply.turnID!,
                conversationID: conversationID,
                startedAt: second,
                endedAt: secondReply.createdAt,
                state: .completed
            ),
        ]
        let summaries = AgentTurnSummaryBuilder()
            .build(records: records, messages: [firstUser, firstReply, secondUser, secondReply])

        #expect(summaries.count == 2)
        #expect(summaries[0].userMessage?.id == firstUser.id)
        #expect(summaries[1].userMessage?.id == secondUser.id)
    }

    // MARK: - §2.4 / §2.5 tool / system 不在投影里，error 仍是最后回复

    @Test("tool 与 system 不会进入 process / last 投影")
    func toolAndSystemRowsAreHidden() {
        let started = Date()
        let turnID = UUID()
        let user = Message(
            conversationID: conversationID,
            role: .user,
            content: "执行命令",
            createdAt: started
        )
        let assistant = Message(
            conversationID: conversationID,
            role: .assistant,
            content: "好的",
            createdAt: started.addingTimeInterval(1),
            turnID: turnID,
            toolCalls: [
                MessageToolCall(id: "c1", name: "run", arguments: "{}", displayDescription: "执行")
            ]
        )
        let toolResult = Message(
            conversationID: conversationID,
            role: .tool,
            content: "raw output",
            createdAt: started.addingTimeInterval(2),
            turnID: turnID
        )
        let systemRow = Message(
            conversationID: conversationID,
            role: .system,
            content: "should be hidden",
            createdAt: started.addingTimeInterval(3),
            turnID: turnID
        )
        let final = Message(
            conversationID: conversationID,
            role: .assistant,
            content: "完成",
            createdAt: started.addingTimeInterval(4),
            turnID: turnID
        )
        let record = AgentTurnRecord(
            id: turnID,
            conversationID: conversationID,
            startedAt: started,
            endedAt: final.createdAt,
            state: .completed
        )
        let summary = AgentTurnSummaryBuilder()
            .build(
                records: [record],
                messages: [user, assistant, toolResult, systemRow, final]
            )
            .first!
        let item = AgentTurnPresentationItem(recorded: summary, acceptsLiveActivity: false)

        let projection = AgentTurnVM.project(
            item: item,
            messages: [user, assistant, toolResult, systemRow, final]
        )

        #expect(projection.processMessages.contains { $0.id == toolResult.id } == false)
        #expect(projection.processMessages.contains { $0.id == systemRow.id } == false)
        #expect(projection.processMessages.contains { $0.id == assistant.id })
        #expect(projection.lastMessage?.id == final.id)
    }

    @Test("failed turn 仍然把 error 消息作为 last 渲染")
    func failedTurnSurfacesErrorAsLastMessage() {
        let started = Date()
        let turnID = UUID()
        let user = Message(
            conversationID: conversationID,
            role: .user,
            content: "做点事",
            createdAt: started
        )
        let error = Message(
            conversationID: conversationID,
            role: .error,
            content: "运行失败",
            createdAt: started.addingTimeInterval(1),
            turnID: turnID,
            isError: true
        )
        let record = AgentTurnRecord(
            id: turnID,
            conversationID: conversationID,
            startedAt: started,
            endedAt: error.createdAt,
            state: .failed
        )
        let summary = AgentTurnSummaryBuilder()
            .build(records: [record], messages: [user, error])
            .first!
        let item = AgentTurnPresentationItem(recorded: summary, acceptsLiveActivity: false)

        let projection = AgentTurnVM.project(item: item, messages: [user, error])

        #expect(projection.lastMessage?.id == error.id)
        #expect(projection.lastMessage?.role == .error)
    }

    // MARK: - §2.7 streaming turn 不增加 lastMessage

    @Test("流式回合进行中 lastMessage 为 nil，不出现 streaming reply block")
    func streamingTurnHasNoLastMessage() {
        let started = Date()
        let turnID = UUID()
        let user = Message(
            conversationID: conversationID,
            role: .user,
            content: "继续",
            createdAt: started
        )
        let interim = Message(
            conversationID: conversationID,
            role: .assistant,
            content: "",
            createdAt: started.addingTimeInterval(1),
            turnID: turnID,
            toolCalls: [
                MessageToolCall(id: "c1", name: "search", arguments: "{}", displayDescription: "搜索")
            ]
        )
        let record = AgentTurnRecord(
            id: turnID,
            conversationID: conversationID,
            startedAt: started,
            endedAt: nil,
            state: .running
        )
        let summary = AgentTurnSummaryBuilder()
            .build(records: [record], messages: [user, interim])
            .first!
        let item = AgentTurnPresentationItem(recorded: summary, acceptsLiveActivity: true)

        let projection = AgentTurnVM.project(item: item, messages: [user, interim])

        #expect(projection.lastMessage == nil)
        #expect(projection.processMessages.map(\.id) == [interim.id])
    }

    // MARK: - §2.8 无回复 turn 不显示空 reply block

    @Test("空回复（仅有占位符）回合不暴露 lastMessage")
    func emptyReplyTurnHidesLastMessage() {
        let started = Date()
        let turnID = UUID()
        let user = Message(
            conversationID: conversationID,
            role: .user,
            content: "分析一下",
            createdAt: started
        )
        // 仅一条纯工具调用、没有任何可见 assistant 正文 —— summaryMessage
        // 会落回合成的 "…" 占位，但 isEmptyResponse 把它再视作空，最终
        // 走到 placeholderMessage → 角色 .status(content == "…")。
        let interim = Message(
            conversationID: conversationID,
            role: .assistant,
            content: "",
            createdAt: started.addingTimeInterval(1),
            turnID: turnID,
            toolCalls: [
                MessageToolCall(id: "c1", name: "scan", arguments: "{}", displayDescription: "扫描")
            ]
        )
        let record = AgentTurnRecord(
            id: turnID,
            conversationID: conversationID,
            startedAt: started,
            endedAt: nil,
            state: .running
        )
        let summary = AgentTurnSummaryBuilder()
            .build(records: [record], messages: [user, interim])
            .first!
        let item = AgentTurnPresentationItem(recorded: summary, acceptsLiveActivity: true)

        let projection = AgentTurnVM.project(item: item, messages: [user, interim])

        // 没有「最后回复」独立行：要么是 nil，要么其 role == .status 占位符。
        if let last = projection.lastMessage {
            #expect(last.role == .status)
            #expect(last.content == "…")
        }
    }

    // MARK: - §3 Process disclosure 文本

    @Test("§3.2 完成回合的 disclosure 标题显示步骤数与耗时")
    func finishedDisclosureTitleShowsStepsAndDuration() {
        let started = Date()
        let turnID = UUID()
        let user = Message(
            conversationID: conversationID,
            role: .user,
            content: "查询",
            createdAt: started
        )
        let call = Message(
            conversationID: conversationID,
            role: .assistant,
            content: "",
            createdAt: started.addingTimeInterval(1),
            turnID: turnID,
            toolCalls: (0..<3).map { idx in
                MessageToolCall(
                    id: "c\(idx)",
                    name: "search",
                    arguments: "{}",
                    displayDescription: "步骤 \(idx + 1)"
                )
            }
        )
        let record = AgentTurnRecord(
            id: turnID,
            conversationID: conversationID,
            startedAt: started,
            endedAt: started.addingTimeInterval(12),
            state: .completed
        )
        let final = Message(
            conversationID: conversationID,
            role: .assistant,
            content: "完成",
            createdAt: started.addingTimeInterval(12),
            turnID: turnID
        )
        let summary = AgentTurnSummaryBuilder()
            .build(records: [record], messages: [user, call, final])
            .first!
        let item = AgentTurnPresentationItem(recorded: summary, acceptsLiveActivity: false)

        // 走真实链路：视图把 projection.processMessages 传给 disclosure。
        let projection = AgentTurnVM.project(item: item, messages: [user, call, final])
        let title = AgentTurnVM.processDisclosureTitle(
            item: item,
            userMessages: projection.userMessages,
            processMessages: projection.processMessages,
            now: started.addingTimeInterval(12)
        )

        #expect(title.contains("执行了3个步骤"))
        #expect(title.contains("12秒"))
    }

    @Test("§3.3 没有工具调用时步骤数回退到 process 消息数")
    func disclosureFallsBackToProcessCount() {
        let started = Date()
        let turnID = UUID()
        let user = Message(
            conversationID: conversationID,
            role: .user,
            content: "继续",
            createdAt: started
        )
        let thinking1 = Message(
            conversationID: conversationID,
            role: .status,
            content: "思考中",
            createdAt: started.addingTimeInterval(1),
            turnID: turnID
        )
        let thinking2 = Message(
            conversationID: conversationID,
            role: .status,
            content: "分析中",
            createdAt: started.addingTimeInterval(2),
            turnID: turnID
        )
        let record = AgentTurnRecord(
            id: turnID,
            conversationID: conversationID,
            startedAt: started,
            endedAt: started.addingTimeInterval(5),
            state: .completed
        )
        let summary = AgentTurnSummaryBuilder()
            .build(records: [record], messages: [user, thinking1, thinking2])
            .first!
        let item = AgentTurnPresentationItem(recorded: summary, acceptsLiveActivity: false)

        let title = AgentTurnVM.processDisclosureTitle(
            item: item,
            userMessages: [user],
            processMessages: summary.processMessages,
            now: started.addingTimeInterval(5)
        )

        // 2 条 process 消息，步骤数 = 2。
        #expect(title.contains("执行了2个步骤"))
    }

    @Test("§3.6 运行中回合的 disclosure 标题使用运行标签")
    func runningDisclosureTitleUsesRunningLabel() {
        let started = Date()
        let turnID = UUID()
        let user = Message(
            conversationID: conversationID,
            role: .user,
            content: "做",
            createdAt: started
        )
        let call = Message(
            conversationID: conversationID,
            role: .assistant,
            content: "",
            createdAt: started.addingTimeInterval(1),
            turnID: turnID,
            toolCalls: [
                MessageToolCall(id: "c1", name: "fetch", arguments: "{}", displayDescription: "拉取")
            ]
        )
        let record = AgentTurnRecord(
            id: turnID,
            conversationID: conversationID,
            startedAt: started,
            endedAt: nil,
            state: .running
        )
        let summary = AgentTurnSummaryBuilder()
            .build(records: [record], messages: [user, call])
            .first!
        let item = AgentTurnPresentationItem(recorded: summary, acceptsLiveActivity: true)

        let early = AgentTurnVM.processDisclosureTitle(
            item: item,
            userMessages: [user],
            processMessages: summary.processMessages,
            now: started.addingTimeInterval(2)
        )
        let later = AgentTurnVM.processDisclosureTitle(
            item: item,
            userMessages: [user],
            processMessages: summary.processMessages,
            now: started.addingTimeInterval(15)
        )

        #expect(early.contains("执行中"))
        // 持续时间随 `now` 推进，必须单调不减（实现保证的「每秒钟 tick」）。
        #expect(later != early)
    }

    // MARK: - §7.3 No renderer placeholder
    //
    // 「无 renderer」的可观察行为（橙色占位 + 「No renderer for message: <id>」）
    // 只能在真机/UI 测试里驱动 `MessageRowView` 渲染来断言；单元层仅做
    // 文档约定。详细验证见 `LumiMessageListBriefUITests`。
}
