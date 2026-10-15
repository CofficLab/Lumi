import Foundation
import Testing
import KitAgentTool
import ProviderAgentLoop

@testable import PluginAskUser

/// 挂起 payload 的编解码契约，以及 `AskUserPendingInteraction` 的派生逻辑。
///
/// `AskUserPendingInteraction.from(suspension:)` 是 AgentLoop（生产方）与
/// 聊天区 UI（消费方）之间唯一的转换点：payload 由 JSON 字符串承载，
/// 因此字段缺失、kind 不符、toolCallID 为空这几类退化输入必须有明确行为，
/// 否则界面上会渲染出一张「无法回答」的问题卡片。
@Suite("AskUser 挂起 payload 与交互派生")
struct AskUserInteractionTests {

    private func makeResponse(
        question: String = "继续吗?",
        options: [AskUserOption] = [AskUserOption(label: "是"), AskUserOption(label: "否")],
        mode: String? = "yes_no",
        verbosity: String = "standard"
    ) throws -> String {
        let response = AskUserPendingResponse(
            toolCallId: "ask_user",
            question: question,
            options: options,
            mode: mode,
            conversationId: "",
            verbosity: verbosity
        )
        return String(data: try JSONEncoder().encode(response), encoding: .utf8)!
    }

    private func makeSuspension(
        kind: String = "userInput",
        toolCallID: String? = "call-1",
        payload: String
    ) -> AgentLoopSuspension {
        AgentLoopSuspension(
            suspensionID: "userInput:call-1",
            conversationID: UUID(),
            toolCallID: toolCallID,
            kind: kind,
            payload: payload
        )
    }

    // MARK: - from(suspension:)

    @Test("合法 userInput suspension 派生出交互，并保留真实 tool call ID")
    func decodesValidSuspension() throws {
        let payload = try makeResponse(question: "选哪个?")
        let interaction = try #require(
            AskUserPendingInteraction.from(suspension: makeSuspension(payload: payload))
        )

        #expect(interaction.toolCallID == "call-1")
        #expect(interaction.response.question == "选哪个?")
        #expect(interaction.response.options.map(\.label) == ["是", "否"])
        // 尚未回答，因此 initialAnswer 为空，卡片显示为「待回答」态。
        #expect(interaction.initialAnswer == nil)
    }

    @Test("非 userInput kind 不派生交互（授权类挂起由各自的 UI 负责）")
    func rejectsOtherKinds() throws {
        let payload = try makeResponse()
        #expect(
            AskUserPendingInteraction.from(
                suspension: makeSuspension(kind: "authorization", payload: payload)
            ) == nil
        )
    }

    @Test("toolCallID 缺失或为空时不派生交互")
    func rejectsMissingToolCallID() throws {
        let payload = try makeResponse()
        #expect(
            AskUserPendingInteraction.from(suspension: makeSuspension(toolCallID: nil, payload: payload)) == nil
        )
        #expect(
            AskUserPendingInteraction.from(suspension: makeSuspension(toolCallID: "", payload: payload)) == nil
        )
    }

    @Test("payload 非法 JSON 或字段缺失时不派生交互")
    func rejectsMalformedPayload() throws {
        #expect(
            AskUserPendingInteraction.from(suspension: makeSuspension(payload: "not json")) == nil
        )
        // 缺 question 字段，无法解码成 AskUserPendingResponse。
        #expect(
            AskUserPendingInteraction.from(suspension: makeSuspension(payload: #"{"toolCallId":"x"}"#)) == nil
        )
    }

    // MARK: - shouldShow

    @Test("仅在选中会话与挂起会话一致时显示")
    func showGating() throws {
        let conversationID = UUID()
        let payload = try makeResponse()
        var suspension = makeSuspension(payload: payload)
        suspension = AgentLoopSuspension(
            suspensionID: suspension.suspensionID,
            conversationID: conversationID,
            toolCallID: suspension.toolCallID,
            kind: suspension.kind,
            payload: suspension.payload
        )
        let interaction = try #require(AskUserPendingInteraction.from(suspension: suspension))

        #expect(AskUserPendingInteraction.shouldShow(selectedConversationID: conversationID, interaction: interaction))
        #expect(!AskUserPendingInteraction.shouldShow(selectedConversationID: UUID(), interaction: interaction))
        // 未选中任何会话时不显示：问题卡片固定在聊天区底部，
        // 没有会话上下文时展示一个无法回答的卡片只会误导用户。
        #expect(!AskUserPendingInteraction.shouldShow(selectedConversationID: nil, interaction: interaction))
        // 无挂起交互时不显示。
        #expect(!AskUserPendingInteraction.shouldShow(selectedConversationID: conversationID, interaction: nil))
    }

    @Test("不同会话的挂起点互不串台")
    func doesNotLeakAcrossConversations() throws {
        let payload = try makeResponse(question: "A 会话的问题")
        let a = UUID()
        let b = UUID()
        let interactionA = AskUserPendingInteraction(
            response: try JSONDecoder().decode(
                AskUserPendingResponse.self,
                from: Data(payload.utf8)
            ),
            toolCallID: "call-a",
            conversationID: a,
            initialAnswer: nil
        )

        #expect(AskUserPendingInteraction.shouldShow(selectedConversationID: a, interaction: interactionA))
        #expect(!AskUserPendingInteraction.shouldShow(selectedConversationID: b, interaction: interactionA))
    }

    // MARK: - payload 编解码

    @Test("带 description/badge 的选项完整往返")
    func optionCodingRoundTrip() throws {
        let option = AskUserOption(label: "Release", description: "正式发布", badge: "推荐")
        let decoded = try JSONDecoder().decode(
            AskUserOption.self,
            from: try JSONEncoder().encode(option)
        )
        #expect(decoded == option)
    }

    @Test("裸字符串选项编码为字符串而非对象（兼容旧格式）")
    func bareOptionEncodesAsString() throws {
        let encoded = try JSONEncoder().encode(AskUserOption(label: "Debug"))
        #expect(String(data: encoded, encoding: .utf8) == "\"Debug\"")
        // 反向解码同样接受裸字符串。
        #expect(
            try JSONDecoder().decode(AskUserOption.self, from: Data("\"Debug\"".utf8))
                == AskUserOption(label: "Debug")
        )
    }

    @Test("payload 往返保留 mode/question/options")
    func payloadRoundTrip() throws {
        let original = AskUserPendingResponse(
            toolCallId: "ask_user",
            question: "冲突如何处理?",
            options: [AskUserOption(label: "保留 A", badge: "推荐")],
            mode: "choice",
            conversationId: "",
            verbosity: "standard"
        )
        let decoded = try JSONDecoder().decode(
            AskUserPendingResponse.self,
            from: try JSONEncoder().encode(original)
        )
        #expect(decoded == original)
    }

    @Test("旧 payload 缺少 mode 时仍可解码（mode 保持 nil）")
    func decodesLegacyPayloadWithoutMode() throws {
        let legacy = #"{"toolCallId":"ask_user","question":"旧问题","options":["是","否"],"conversationId":"","verbosity":"standard"}"#
        let decoded = try JSONDecoder().decode(
            AskUserPendingResponse.self,
            from: Data(legacy.utf8)
        )
        #expect(decoded.mode == nil)
        #expect(decoded.question == "旧问题")
        #expect(decoded.options.map(\.label) == ["是", "否"])
    }

    @Test("选项 id 即 label，重复标签会让 ForEach 复用同一行")
    func optionIdentity() {
        #expect(AskUserOption(label: "是").id == "是")
        // 去重发生在模型侧；这里锁住「label 即 id」这一事实，
        // 让 UI 侧出现重复选项时能被定位为 payload 问题而非渲染 bug。
        let duplicate = AskUserOption(label: "是")
        #expect(duplicate == AskUserOption(label: "是"))
    }
}
