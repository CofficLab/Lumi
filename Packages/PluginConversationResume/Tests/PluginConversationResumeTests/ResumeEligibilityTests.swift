import Foundation
import Testing
@testable import PluginConversationResume
import ProviderAgentLoop
import ProviderMessage

@MainActor
struct ResumeEligibilityTests {
    // MARK: - 辅助

    private func userMessage(_ content: String = "帮我改一下代码") -> Message {
        Message(conversationID: UUID(), role: .user, content: content)
    }

    private func assistantMessage(
        content: String = "",
        toolCalls: [MessageToolCall]? = nil
    ) -> Message {
        Message(
            conversationID: UUID(),
            role: .assistant,
            content: content,
            toolCalls: toolCalls
        )
    }

    private func toolCall(id: String = "call_1", name: String = "read_file") -> MessageToolCall {
        MessageToolCall(id: id, name: name, arguments: "{}")
    }

    private func interruptedRecord(
        conversationID: UUID = UUID(),
        turnID: UUID = UUID()
    ) -> ResumableTurnRecord {
        ResumableTurnRecord(
            conversationID: conversationID,
            turnID: turnID,
            outcome: .interrupted,
            startedAt: Date(timeIntervalSince1970: 1_000),
            recordedAt: Date(timeIntervalSince1970: 1_100),
            lastToolCallID: nil
        )
    }

    private func input(
        record: ResumableTurnRecord?,
        state: ResumeEligibility.AgentLoopStateSnapshot = .idle,
        messages: [Message] = []
    ) -> ResumeEligibility.Input {
        ResumeEligibility.Input(
            turnRecord: record,
            agentLoopState: state,
            messages: messages
        )
    }

    // MARK: - 判定

    @Test("中断的回合可以继续")
    func interruptedTurnIsResumable() {
        let conversationID = UUID()
        let turnID = UUID()
        let record = interruptedRecord(conversationID: conversationID, turnID: turnID)
        let user = Message(conversationID: conversationID, role: .user, content: "读一下文件")
        let assistant = Message(
            conversationID: conversationID,
            role: .assistant,
            content: "",
            turnID: turnID,
            toolCalls: [toolCall()]
        )

        let verdict = ResumeEligibility.evaluate(
            input(record: record, messages: [user, assistant])
        )

        #expect(verdict == .resumable(reason: "上一轮在执行中被中断"))
    }

    @Test("没有回合记录时不可继续")
    func missingRecordIsNotResumable() {
        let verdict = ResumeEligibility.evaluate(
            input(record: nil, messages: [userMessage()])
        )

        #expect(verdict == .notResumable(reason: "没有未收尾的回合记录"))
    }

    @Test("用户主动停止的回合不可继续")
    func cancelledTurnIsNotResumable() {
        var record = interruptedRecord()
        record = ResumableTurnRecord(
            conversationID: record.conversationID,
            turnID: record.turnID,
            outcome: .cancelled,
            startedAt: record.startedAt,
            recordedAt: record.recordedAt,
            lastToolCallID: nil
        )

        let verdict = ResumeEligibility.evaluate(
            input(record: record, messages: [userMessage()])
        )

        #expect(verdict == .notResumable(reason: "回合已正常收尾（cancelled）"))
    }

    @Test("正常完成的回合不可继续")
    func completedTurnIsNotResumable() {
        var record = interruptedRecord()
        record = ResumableTurnRecord(
            conversationID: record.conversationID,
            turnID: record.turnID,
            outcome: .completed,
            startedAt: record.startedAt,
            recordedAt: record.recordedAt,
            lastToolCallID: nil
        )

        let verdict = ResumeEligibility.evaluate(
            input(record: record, messages: [userMessage()])
        )

        #expect(verdict == .notResumable(reason: "回合已正常收尾（completed）"))
    }

    @Test("回合仍在运行时不可继续")
    func runningTurnIsNotResumable() {
        let verdict = ResumeEligibility.evaluate(
            input(
                record: interruptedRecord(),
                state: .running,
                messages: [userMessage()]
            )
        )

        #expect(verdict == .notResumable(reason: "回合仍在运行"))
    }

    @Test("回合挂起时不可继续")
    func suspendedTurnIsNotResumable() {
        let verdict = ResumeEligibility.evaluate(
            input(
                record: interruptedRecord(),
                state: .suspended,
                messages: [userMessage()]
            )
        )

        #expect(verdict == .notResumable(reason: "回合处于挂起状态，仍可继续交互"))
    }

    @Test("已产出最终回复的回合不可继续")
    func finishedReplyIsNotResumable() {
        let record = interruptedRecord()
        let user = userMessage()
        let assistant = assistantMessage(content: "已经改完了。")

        let verdict = ResumeEligibility.evaluate(
            input(record: record, messages: [user, assistant])
        )

        #expect(verdict == .notResumable(reason: "回合已产出最终回复"))
    }

    @Test("没有用户消息的会话不可继续")
    func noUserMessageIsNotResumable() {
        let verdict = ResumeEligibility.evaluate(
            input(record: interruptedRecord(), messages: [])
        )

        #expect(verdict == .notResumable(reason: "会话中没有用户消息"))
    }

    @Test("只有工具调用、没有最终回复的助手消息不算最终回复")
    func assistantWithToolCallsIsNotFinalReply() {
        #expect(!ResumeEligibility.hasFinalAssistantReply([
            assistantMessage(content: "", toolCalls: [toolCall()])
        ]))
    }

    @Test("带工具调用的助手消息即使有正文也不算最终回复")
    func assistantWithToolCallsAndTextIsNotFinalReply() {
        #expect(!ResumeEligibility.hasFinalAssistantReply([
            assistantMessage(content: "我先看看文件", toolCalls: [toolCall()])
        ]))
    }

    @Test("空正文的助手消息不算最终回复")
    func emptyAssistantIsNotFinalReply() {
        #expect(!ResumeEligibility.hasFinalAssistantReply([
            assistantMessage(content: "   ")
        ]))
    }

    @Test("错误消息不算最终回复")
    func errorAssistantIsNotFinalReply() {
        let message = Message(
            conversationID: UUID(),
            role: .assistant,
            content: "出错了",
            isError: true
        )
        #expect(!ResumeEligibility.hasFinalAssistantReply([message]))
    }
}
