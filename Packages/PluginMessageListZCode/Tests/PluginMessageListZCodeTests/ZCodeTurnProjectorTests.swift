import Foundation
import ProviderMessage
import Testing
@testable import PluginMessageListZCode

/// V4（ZCode）轮次投影契约测试。
///
/// 投影的唯一输入是 `ListV4ViewModel.historyRows`（已含 `.tool` 过滤与
/// 连续 tool-only 合并），因此这里直接用构造好的 `Message` 数组作为输入。
///
/// 核心不变式：
/// - 身份稳定（不生成随机 UUID，重复投影结果完全一致）；
/// - 用户消息开启新轮次；
/// - 整轮复制只含助手正文；
/// - 操作栏只挂在轮尾正文。
@Suite("ZCode 轮次投影")
struct ZCodeTurnProjectorTests {

    // MARK: - 轮次边界

    @Test("nil turnID 的用户消息开启新轮次")
    func userMessageStartsNewTurn() {
        let user = makeMessage(role: .user, content: "问题一")
        let assistant = makeMessage(role: .assistant, content: "回答一")
        let user2 = makeMessage(role: .user, content: "问题二")
        let assistant2 = makeMessage(role: .assistant, content: "回答二")

        let turns = ZCodeTurnProjector.project([user, assistant, user2, assistant2])

        #expect(turns.count == 2)
        #expect(turns[0].rows.count == 2)
        #expect(turns[1].rows.count == 2)
        #expect(turns[0].rows[0].message.id == user.id)
        #expect(turns[1].rows[0].message.id == user2.id)
    }

    @Test("同 turnID 的多段内容不会被拆开")
    func sameTurnIDIsNotSplit() {
        let turnID = UUID()
        let rows = [
            makeMessage(role: .assistant, content: "第一段", turnID: turnID),
            makeMessage(role: .assistant, content: "第二段", turnID: turnID),
            makeMessage(role: .status, content: "状态", turnID: turnID),
        ]

        let turns = ZCodeTurnProjector.project(rows)

        #expect(turns.count == 1)
        #expect(turns[0].rows.count == 3)
        #expect(turns[0].agentTurnID == turnID)
    }

    @Test("不同的非 nil turnID 不混桶")
    func differentTurnIDsAreNotMixed() {
        let turnA = UUID()
        let turnB = UUID()
        let rows = [
            makeMessage(role: .assistant, content: "A", turnID: turnA),
            makeMessage(role: .assistant, content: "B", turnID: turnB),
        ]

        let turns = ZCodeTurnProjector.project(rows)

        #expect(turns.count == 2)
        #expect(turns[0].agentTurnID == turnA)
        #expect(turns[1].agentTurnID == turnB)
    }

    @Test("当前轮次尚无 agentTurnID 时可由后续消息补齐")
    func agentTurnIDCanBeBackfilled() {
        let turnID = UUID()
        let rows = [
            makeMessage(role: .user, content: "问题"),
            makeMessage(role: .assistant, content: "回答", turnID: turnID),
        ]

        let turns = ZCodeTurnProjector.project(rows)

        #expect(turns.count == 1)
        #expect(turns[0].agentTurnID == turnID)
    }

    @Test("全部 nil turnID 的旧数据按用户消息边界确定性分组")
    func legacyNilTurnIDsGroupDeterministically() {
        let rows = [
            makeMessage(role: .user, content: "问题一"),
            makeMessage(role: .assistant, content: "回答一"),
            makeMessage(role: .user, content: "问题二"),
            makeMessage(role: .assistant, content: "回答二"),
        ]

        let first = ZCodeTurnProjector.project(rows)
        let second = ZCodeTurnProjector.project(rows)

        #expect(first.count == 2)
        #expect(first.map(\.id) == second.map(\.id))
        #expect(first[0].id == "message:\(rows[0].id.uuidString)")
        #expect(first[1].id == "message:\(rows[2].id.uuidString)")
    }

    // MARK: - 身份稳定性

    @Test("同一输入重复投影得到完全相同的身份")
    func repeatedProjectionIsIdentical() {
        let turnID = UUID()
        let rows = [
            makeMessage(role: .user, content: "问题"),
            makeMessage(role: .assistant, content: "回答", turnID: turnID),
        ]

        let first = ZCodeTurnProjector.project(rows)
        let second = ZCodeTurnProjector.project(rows)

        #expect(first == second)
        #expect(first.map(\.id) == second.map(\.id))
        #expect(first[0].rows.map(\.id) == second[0].rows.map(\.id))
    }

    @Test("history 行 id 使用 history 前缀且不与流式/活动行冲突")
    func rowIDsUseStablePrefixes() {
        let user = makeMessage(role: .user, content: "问题")
        let rows = [user]

        let turns = ZCodeTurnProjector.project(rows)

        #expect(turns[0].rows[0].id == "history:\(user.id.uuidString)")
    }

    @Test("助手主导的轮次优先使用 turn 前缀")
    func assistantLedTurnPrefersTurnPrefix() {
        let turnID = UUID()
        let rows = [makeMessage(role: .assistant, content: "回答", turnID: turnID)]

        let turns = ZCodeTurnProjector.project(rows)

        #expect(turns[0].id == "turn:\(turnID.uuidString)")
    }

    @Test("助手主导且无 turnID 时回退到首条消息 id")
    func assistantLedTurnWithoutTurnIDFallsBackToMessage() {
        let assistant = makeMessage(role: .assistant, content: "回答")
        let rows = [assistant]

        let turns = ZCodeTurnProjector.project(rows)

        #expect(turns[0].id == "message:\(assistant.id.uuidString)")
    }

    @Test("prepend 后已有轮次与行身份保持不变")
    func prependKeepsExistingIdentities() {
        let user = makeMessage(role: .user, content: "问题")
        let assistant = makeMessage(role: .assistant, content: "回答")
        let before = ZCodeTurnProjector.project([user, assistant])

        let older = makeMessage(role: .user, content: "更早的问题")
        let after = ZCodeTurnProjector.project([older, user, assistant])

        #expect(after.count == 2)
        // 原有轮次身份不变（只是数组下标后移）。
        #expect(after[1].id == before[0].id)
        #expect(after[1].rows.map(\.id) == before[0].rows.map(\.id))
    }

    // MARK: - 整轮复制文本

    @Test("整轮复制只含助手正文并用空行连接")
    func copyTextContainsOnlyAssistantBody() {
        let rows = [
            makeMessage(role: .user, content: "用户问题"),
            makeMessage(role: .assistant, content: "第一段"),
            makeMessage(role: .assistant, content: "第二段"),
        ]

        let turns = ZCodeTurnProjector.project(rows)

        #expect(turns[0].assistantCopyText == "第一段\n\n第二段")
    }

    @Test("整轮复制排除工具输出与 tool-only 行")
    func copyTextExcludesToolOutput() {
        var toolOnly = makeMessage(role: .assistant, content: "")
        toolOnly.toolCalls = [.init(id: "call-1", name: "Read", arguments: "{}")]
        let rows = [
            makeMessage(role: .user, content: "用户问题"),
            toolOnly,
            makeMessage(role: .assistant, content: "结论"),
        ]

        let turns = ZCodeTurnProjector.project(rows)

        #expect(turns[0].assistantCopyText == "结论")
    }

    @Test("整轮复制忽略空白正文")
    func copyTextIgnoresBlankBodies() {
        let rows = [
            makeMessage(role: .assistant, content: "   "),
            makeMessage(role: .assistant, content: "有效"),
        ]

        let turns = ZCodeTurnProjector.project(rows)

        #expect(turns[0].assistantCopyText == "有效")
    }

    // MARK: - 轮尾正文

    @Test("只有最后一个助手正文是轮尾正文")
    func onlyLastAssistantBodyIsTail() {
        let rows = [
            makeMessage(role: .assistant, content: "第一段"),
            makeMessage(role: .assistant, content: "第二段"),
        ]

        let turns = ZCodeTurnProjector.project(rows)

        #expect(turns[0].tailAssistantRowID == turns[0].rows.last?.id)
        #expect(turns[0].rows[0].id != turns[0].tailAssistantRowID)
    }

    @Test("没有助手正文时没有轮尾正文")
    func noAssistantBodyMeansNoTail() {
        let rows = [makeMessage(role: .user, content: "问题")]

        let turns = ZCodeTurnProjector.project(rows)

        #expect(turns[0].tailAssistantRowID == nil)
        #expect(turns[0].assistantCopyText.isEmpty)
    }

    @Test("完成时间取轮尾正文的真实创建时间")
    func completedAtUsesTailBodyCreatedAt() {
        let createdAt = Date(timeIntervalSince1970: 1_700_000_000)
        let assistant = makeMessage(role: .assistant, content: "回答", createdAt: createdAt)
        let rows = [makeMessage(role: .user, content: "问题"), assistant]

        let turns = ZCodeTurnProjector.project(rows)

        #expect(turns[0].completedAt == createdAt)
    }

    // MARK: - 边界

    @Test("空数组投影得到空结果")
    func emptyInputProjectsEmpty() {
        #expect(ZCodeTurnProjector.project([]).isEmpty)
    }

    @Test("仅 status 行不崩溃")
    func statusOnlyDoesNotCrash() {
        let rows = [makeMessage(role: .status, content: "正在思考")]

        let turns = ZCodeTurnProjector.project(rows)

        #expect(turns.count == 1)
        #expect(turns[0].rows.count == 1)
        #expect(turns[0].tailAssistantRowID == nil)
    }

    @Test("仅 tool-only 助手行不崩溃")
    func toolOnlyDoesNotCrash() {
        var toolOnly = makeMessage(role: .assistant, content: "")
        toolOnly.toolCalls = [.init(id: "call-1", name: "Read", arguments: "{}")]
        let rows = [toolOnly]

        let turns = ZCodeTurnProjector.project(rows)

        #expect(turns.count == 1)
        #expect(turns[0].assistantCopyText.isEmpty)
        #expect(turns[0].tailAssistantRowID == nil)
    }

    @Test("仅助手正文不崩溃")
    func assistantOnlyDoesNotCrash() {
        let rows = [makeMessage(role: .assistant, content: "回答")]

        let turns = ZCodeTurnProjector.project(rows)

        #expect(turns.count == 1)
        #expect(turns[0].assistantCopyText == "回答")
    }

    @Test("流式行与活动行互斥，不会同时出现")
    func streamingAndActivityAreMutuallyExclusive() {
        let streaming = makeMessage(role: .assistant, content: "流式内容")
        let activity = makeMessage(role: .assistant, content: "活动内容")

        let withStreaming = ZCodeTurnProjector.project(history: [], streaming: streaming, activity: nil)
        let withActivity = ZCodeTurnProjector.project(history: [], streaming: nil, activity: activity)
        let withBoth = ZCodeTurnProjector.project(history: [], streaming: streaming, activity: activity)

        #expect(withStreaming.turns.count == 1)
        #expect(withStreaming.turns[0].rows.count == 1)
        #expect(withActivity.turns.count == 1)
        // 流式存在时不再插入活动行。
        #expect(withBoth.turns.count == 1)
        #expect(withBoth.turns[0].rows.count == 1)
        #expect(withBoth.turns[0].rows[0].origin == .streaming)
    }

    @Test("流式行的 id 使用固定语义且不与历史行冲突")
    func streamingRowIDIsDistinct() {
        let streaming = makeMessage(role: .assistant, content: "流式内容")

        let turns = ZCodeTurnProjector.project(history: [], streaming: streaming, activity: nil)

        #expect(turns.turns[0].rows[0].id == "streaming")
        #expect(turns.turns[0].rows[0].origin == .streaming)
    }

    @Test("活动行的 id 使用固定语义")
    func activityRowIDIsFixed() {
        let activity = makeMessage(role: .assistant, content: "活动内容")

        let turns = ZCodeTurnProjector.project(history: [], streaming: nil, activity: activity)

        #expect(turns.turns[0].rows[0].id == "conversation-activity")
        #expect(turns.turns[0].rows[0].origin == .activity)
    }

    @Test("流式更新不改变历史轮次的数量与身份")
    func streamingUpdateDoesNotChangeHistoryTurns() {
        let user = makeMessage(role: .user, content: "问题")
        let assistant = makeMessage(role: .assistant, content: "回答")
        let history = [user, assistant]

        let before = ZCodeTurnProjector.project(history)

        var streaming = makeMessage(role: .assistant, content: "流")
        let after1 = ZCodeTurnProjector.project(history: history, streaming: streaming, activity: nil)
        streaming = makeMessage(role: .assistant, content: "流式更长")
        let after2 = ZCodeTurnProjector.project(history: history, streaming: streaming, activity: nil)

        let beforeIDs: [String] = before.map(\.id)
        #expect(after1.historyTurnCount == before.count)
        #expect(after2.historyTurnCount == before.count)
        #expect(after1.historyTurnIDs == beforeIDs)
        #expect(after2.historyTurnIDs == beforeIDs)
    }

    // MARK: - 辅助

    private func makeMessage(
        role: MessageRole,
        content: String,
        turnID: UUID? = nil,
        createdAt: Date = Date(timeIntervalSince1970: 1_700_000_000)
    ) -> Message {
        Message(
            conversationID: UUID(),
            role: role,
            content: content,
            createdAt: createdAt,
            turnID: turnID
        )
    }
}
