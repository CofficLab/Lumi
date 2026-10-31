import Foundation
import Testing
import KernelCore
import KitAgentTool
import KitLLM
import ProviderAgentLoop
import ProviderChatSection
import ProviderConversation
import ProviderLLMManager
import ProviderMessage
import ProviderMessageStreaming
import ProviderToolManager

@testable import PluginAskUser

/// ask_user 的端到端生命周期：LLM 发问 → 回合挂起 → 用户回答 → 恢复 → 回合完成。
///
/// 单元测试回答不了「挂起后界面能不能被回答、答案会不会真的回到 LLM」。
/// 这里用脚本化 LLM 把整条链路跑通，断言三件事：
/// 1. 首轮挂起（outcome 为 `.suspended`，且挂起点 ID 与工具调用 ID 对应）；
/// 2. 恢复后答案以 `role=tool` 消息回传（这是「LLM 收到了答案」的证据）；
/// 3. 回合跑完并以最终文本收尾。
@Suite("ask_user 端到端挂起与恢复")
@MainActor
struct AskUserLifecycleTests {

    /// 按调用顺序返回预设响应的 LLM。
    ///
    /// 用「脚本化响应」而不是判断请求内容，是因为 AgentLoop 每轮的确切
    /// 请求数由实现细节决定；测试只关心「第二轮拿到工具结果后收尾」。
    private final class ScriptedLLM: SuperLLMProvider, @unchecked Sendable {
        let providerID = "scripted"
        let providerInfo = LLMProviderInfo(
            id: "scripted",
            displayName: "Scripted",
            defaultModel: "",
            models: [],
            isLocal: true
        )

        private var responses: [LLMResponse]
        private let lock = NSLock()
        private var _receivedBodies: [[LLMMessage]] = []

        /// 每轮 LLM 实际收到的消息，供断言「第二轮看到了工具结果」。
        var receivedBodies: [[LLMMessage]] {
            lock.lock(); defer { lock.unlock() }
            return _receivedBodies
        }

        init(responses: [LLMResponse]) {
            self.responses = responses
        }

        func complete(_ request: LLMRequest) async throws -> LLMResponse {
            // - Important: 必须用 `withLock` 作用域式加锁。`NSLock.lock()`
            //   在 async 上下文中被 Swift 6 明确禁用。
            lock.withLock {
                _receivedBodies.append(request.messages)
                return responses.isEmpty ? LLMResponse(content: "") : responses.removeFirst()
            }
        }
    }

    private final class StubLLMManager: LLMManaging {
        var provider: any SuperLLMProvider

        init(provider: any SuperLLMProvider) { self.provider = provider }

        var providerID: String { "scripted-manager" }
        var providerInfo: LLMProviderInfo {
            LLMProviderInfo(id: "scripted-manager", displayName: "Scripted Manager", defaultModel: "", models: [], isLocal: true)
        }
        func complete(_ request: LLMRequest) async throws -> LLMResponse {
            try await provider.complete(request)
        }
        func allProviders() -> [any SuperLLMProvider] { [provider] }
        func provider(id: String) -> (any SuperLLMProvider)? { provider }
        var providerCount: Int { 1 }
        func register(_ provider: any SuperLLMProvider) throws {}
        func unregister(id: String) {}
        var selectedProviderID: String? { "scripted-manager" }
        var selectedModel: String? { nil }
        func models(for providerID: String) -> [String] { [] }
        func select(providerID: String, model: String?, reason: ModelSelectionReason) {}
    }

    /// 构造一个装好 ask_user 工具的最小运行环境。
    private func makeEnvironment(
        tool: AskUserTool,
        llm: any SuperLLMProvider
    ) -> (DefaultAgentLoopProvider, DefaultToolManagerProviding, DefaultConversationManager, DefaultMessageManager) {
        let conversations = DefaultConversationManager()
        let toolManager = DefaultToolManagerProviding()
        let messages = DefaultMessageManager()
        toolManager.add(tool, pluginID: "test")
        let loop = DefaultAgentLoopProvider(
            messages: messages,
            llmManager: StubLLMManager(provider: llm),
            toolManager: toolManager,
            streaming: DefaultMessageStreamingProviding(),
            conversations: conversations
        )
        return (loop, toolManager, conversations, messages)
    }

    // MARK: - 端到端

    @Test("yes_no 提问挂起后，回答「是」可恢复并把答案回传给 LLM")
    func yesNoSuspendThenResume() async throws {
        let callID = "ask-1"
        let llm = ScriptedLLM(responses: [
            LLMResponse(content: "", toolCalls: [
                LLMToolCall(id: callID, name: "ask_user", arguments: #"{"question":"继续构建?","mode":"yes_no"}"#),
            ]),
            LLMResponse(content: "好的，继续"),
        ])
        let (loop, _, _, messages) = makeEnvironment(tool: AskUserTool(), llm: llm)

        let conversationID = UUID()
        messages.insertMessage(
            Message(conversationID: conversationID, role: .user, content: "帮我做决定"),
            to: conversationID
        )

        // 首轮：工具挂起，回合停在 userInput。
        let outcome = try await loop.runTurn(in: conversationID)
        #expect(outcome == .suspended("userInput:\(callID)"))

        let suspension = try #require(loop.suspension(for: conversationID))
        #expect(suspension.kind == "userInput")
        #expect(suspension.toolCallID == callID)
        #expect(loop.state(for: conversationID) == .suspended)

        // 挂起期间挂起点必须能被 UI 解析出问题卡片所需的数据。
        let interaction = try #require(AskUserPendingInteraction.from(suspension: suspension))
        #expect(interaction.response.question == "继续构建?")
        #expect(interaction.response.options.map(\.label) == ["是", "否"])

        // 恢复：答案是「是」。
        let resumed = try await loop.resumeTurn(
            in: conversationID,
            request: AgentTurnResumeRequest(suspensionID: suspension.suspensionID, answer: "是")
        )
        #expect(resumed == .completed)

        // 答案必须以 role=tool 消息回传，且内容等于用户选择。
        let snapshot = await messages.messagesSnapshot(in: conversationID)
        let toolMessages = snapshot.filter { $0.role == .tool && $0.toolCallID == callID }
        #expect(toolMessages.count == 1)
        #expect(toolMessages.first?.content == "是")
        #expect(toolMessages.first?.isError != true)

        // 挂起点在恢复后被清除，界面上的问题卡片应随之消失。
        #expect(loop.suspension(for: conversationID) == nil)
        #expect(loop.state(for: conversationID) == .completed)

        // 第二轮 LLM 确实看到了工具结果，并以此收尾。
        #expect(snapshot.last?.content == "好的，继续")
        let secondRequestBodies = await llm.receivedBodies
        #expect(secondRequestBodies.count == 2, "首轮发问 + 恢复后续跑，应恰好两次 LLM 调用")
        let resumedMessages = try #require(secondRequestBodies.last)
        #expect(resumedMessages.contains { $0.role == .tool && $0.content == "是" })
    }

    @Test("choice 提问：选项被点选后以选项 label 作为答案恢复")
    func choiceSuspendThenResume() async throws {
        let callID = "ask-choice"
        let llm = ScriptedLLM(responses: [
            LLMResponse(content: "", toolCalls: [
                LLMToolCall(
                    id: callID,
                    name: "ask_user",
                    arguments: #"{"question":"选哪个?","mode":"choice","options":["Debug",{"label":"Release","badge":"推荐"}]}"#
                ),
            ]),
            LLMResponse(content: "已切换到 Release"),
        ])
        let (loop, _, _, messages) = makeEnvironment(tool: AskUserTool(), llm: llm)

        let conversationID = UUID()
        messages.insertMessage(
            Message(conversationID: conversationID, role: .user, content: "帮我选"),
            to: conversationID
        )

        #expect(try await loop.runTurn(in: conversationID) == .suspended("userInput:\(callID)"))

        let suspension = try #require(loop.suspension(for: conversationID))
        let interaction = try #require(AskUserPendingInteraction.from(suspension: suspension))
        #expect(interaction.response.mode == "choice")
        #expect(interaction.response.options.map(\.label) == ["Debug", "Release"])
        #expect(interaction.response.options[1].badge == "推荐")

        // 用户点选「Release」。
        let resumed = try await loop.resumeTurn(
            in: conversationID,
            request: AgentTurnResumeRequest(suspensionID: suspension.suspensionID, answer: "Release")
        )
        #expect(resumed == .completed)

        let snapshot = await messages.messagesSnapshot(in: conversationID)
        #expect(snapshot.last?.content == "已切换到 Release")
        #expect(snapshot.contains { $0.role == .tool && $0.toolCallID == callID && $0.content == "Release" })
    }

    @Test("free_text 提问：自由文本答案原样回传")
    func freeTextSuspendThenResume() async throws {
        let callID = "ask-free"
        let llm = ScriptedLLM(responses: [
            LLMResponse(content: "", toolCalls: [
                LLMToolCall(id: callID, name: "ask_user", arguments: #"{"question":"冲突如何处理?","mode":"free_text"}"#),
            ]),
            LLMResponse(content: "收到，我按你的方案处理"),
        ])
        let (loop, _, _, messages) = makeEnvironment(tool: AskUserTool(), llm: llm)

        let conversationID = UUID()
        messages.insertMessage(
            Message(conversationID: conversationID, role: .user, content: "有冲突"),
            to: conversationID
        )

        #expect(try await loop.runTurn(in: conversationID) == .suspended("userInput:\(callID)"))

        let suspension = try #require(loop.suspension(for: conversationID))
        let interaction = try #require(AskUserPendingInteraction.from(suspension: suspension))
        // free_text 无选项，UI 走输入框分支。
        #expect(interaction.response.options.isEmpty)

        let answer = "保留 main 的版本，改用 rebase"
        let resumed = try await loop.resumeTurn(
            in: conversationID,
            request: AgentTurnResumeRequest(suspensionID: suspension.suspensionID, answer: answer)
        )
        #expect(resumed == .completed)

        let snapshot = await messages.messagesSnapshot(in: conversationID)
        #expect(snapshot.contains { $0.role == .tool && $0.toolCallID == callID && $0.content == answer })
    }

    @Test("参数非法时工具报错，回合不挂起而是正常结束")
    func invalidArgumentsDoNotSuspend() async throws {
        // 缺 mode：工具返回错误结果，AgentLoop 视为已执行完毕，继续下一轮。
        let llm = ScriptedLLM(responses: [
            LLMResponse(content: "", toolCalls: [
                LLMToolCall(id: "ask-bad", name: "ask_user", arguments: #"{"question":"继续吗?"}"#),
            ]),
            LLMResponse(content: "抱歉，我需要知道问题类型"),
        ])
        let (loop, _, _, messages) = makeEnvironment(tool: AskUserTool(), llm: llm)

        let conversationID = UUID()
        messages.insertMessage(
            Message(conversationID: conversationID, role: .user, content: "继续吗"),
            to: conversationID
        )

        let outcome = try await loop.runTurn(in: conversationID)
        #expect(outcome == .completed, "非法参数不应挂起回合")
        #expect(loop.suspension(for: conversationID) == nil, "非法参数不应产生挂起点")

        let snapshot = await messages.messagesSnapshot(in: conversationID)
        let errored = snapshot.contains { $0.role == .tool && $0.toolCallID == "ask-bad" && $0.isError == true }
        #expect(errored, "工具错误应作为带 isError 的 tool 结果回传，让模型自我纠正")
    }

    @Test("错误答案不影响恢复：resumeTurn 对任意 suspensionID 校验严格")
    func resumeRejectsMismatchedSuspension() async throws {
        let llm = ScriptedLLM(responses: [
            LLMResponse(content: "", toolCalls: [
                LLMToolCall(id: "ask-x", name: "ask_user", arguments: #"{"question":"继续?","mode":"yes_no"}"#),
            ]),
            LLMResponse(content: "done"),
        ])
        let (loop, _, _, messages) = makeEnvironment(tool: AskUserTool(), llm: llm)

        let conversationID = UUID()
        messages.insertMessage(
            Message(conversationID: conversationID, role: .user, content: "继续"),
            to: conversationID
        )
        #expect(try await loop.runTurn(in: conversationID) == .suspended("userInput:ask-x"))

        // 错误的挂起点 ID 必须被拒绝，避免误恢复其他交互。
        await #expect(throws: AgentLoopError.self) {
            try await loop.resumeTurn(
                in: conversationID,
                request: AgentTurnResumeRequest(suspensionID: "userInput:wrong", answer: "是")
            )
        }

        // 拒绝后原挂起点仍然有效，可正常恢复。
        let suspension = try #require(loop.suspension(for: conversationID))
        #expect(
            try await loop.resumeTurn(
                in: conversationID,
                request: AgentTurnResumeRequest(suspensionID: suspension.suspensionID, answer: "是")
            ) == .completed
        )
    }

    // MARK: - ToolManager 层

    @Test("ToolManager 透传 ask_user 的挂起语义")
    func toolManagerPropagatesSuspension() async throws {
        let (_, toolManager, _, _) = makeEnvironment(
            tool: AskUserTool(),
            llm: ScriptedLLM(responses: [])
        )

        let result = await toolManager.execute(
            ToolCall(
                id: "ask-direct",
                name: "ask_user",
                arguments: #"{"question":"继续吗?","mode":"yes_no"}"#
            ),
            conversationID: UUID(),
            turnID: nil
        )

        #expect(result.awaitingUserResponse)
        #expect(!result.isError)
        let payload = try #require(result.content.data(using: .utf8))
        let response = try JSONDecoder().decode(AskUserPendingResponse.self, from: payload)
        #expect(response.question == "继续吗?")
    }
}
