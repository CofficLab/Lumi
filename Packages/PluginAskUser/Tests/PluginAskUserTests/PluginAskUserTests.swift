import Foundation
import Testing
import KernelCore
import KitAgentTool
import ProviderConversation
import ProviderMessage
import KitLLM
import ProviderAgentLoop
import ProviderToolManager
import ProviderLLMManager
import ProviderMessageStreaming

@testable import PluginAskUser

/// 测试用 LLMManaging：转发到脚本化 provider。
@MainActor
private final class ScriptedLLMManager: LLMManaging {
    var provider: any SuperLLMProvider

    init(provider: any SuperLLMProvider) {
        self.provider = provider
    }

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
    func select(providerID: String, model: String?) {}
}

@Suite("AskUserPlugin")
@MainActor
struct AskUserPluginTests {
    @Test("yes_no 模式：返回是/否选项且挂起等待回答")
    func yesNoMode() async throws {
        let tool = AskUserTool()
        let result = try await tool.executeResult(arguments: [
            "question": ToolArgument("继续构建?"),
            "mode": ToolArgument("yes_no"),
        ])
        #expect(result.awaitingUserResponse)
        #expect(!result.isError)

        let response = try #require(try? JSONDecoder().decode(
            AskUserPendingResponse.self,
            from: Data(result.content.utf8)
        ))
        #expect(response.mode == "yes_no")
        #expect(response.question == "继续构建?")
        #expect(response.options.map(\.label) == ["是", "否"])
    }

    @Test("choice 模式：返回传入的选项")
    func choiceMode() async throws {
        let tool = AskUserTool()
        let result = try await tool.executeResult(arguments: [
            "question": ToolArgument("选哪个?"),
            "mode": ToolArgument("choice"),
            "options": ToolArgument(["Debug", "Release", "Profile"]),
        ])
        let response = try #require(try? JSONDecoder().decode(
            AskUserPendingResponse.self,
            from: Data(result.content.utf8)
        ))
        #expect(response.mode == "choice")
        #expect(response.options.map(\.label) == ["Debug", "Release", "Profile"])
        #expect(result.awaitingUserResponse)
    }

    @Test("free_text 模式：无选项，挂起等待回答")
    func freeTextMode() async throws {
        let tool = AskUserTool()
        let result = try await tool.executeResult(arguments: [
            "question": ToolArgument("接下来怎么做?"),
            "mode": ToolArgument("free_text"),
        ])
        let response = try #require(try? JSONDecoder().decode(
            AskUserPendingResponse.self,
            from: Data(result.content.utf8)
        ))
        #expect(response.mode == "free_text")
        #expect(response.options.isEmpty)
        #expect(result.awaitingUserResponse)
    }

    @Test("缺 mode 返回错误且不挂起")
    func missingMode() async throws {
        let tool = AskUserTool()
        let result = try await tool.executeResult(arguments: [
            "question": ToolArgument("你好?"),
        ])
        #expect(result.isError)
        #expect(!result.awaitingUserResponse)
    }

    @Test("choice 模式缺 options 返回错误")
    func choiceMissingOptions() async throws {
        let tool = AskUserTool()
        let result = try await tool.executeResult(arguments: [
            "question": ToolArgument("选哪个?"),
            "mode": ToolArgument("choice"),
        ])
        #expect(result.isError)
    }

    @Test("插件注册 ask_user 工具")
    func pluginRegistersTool() throws {
        let kernel = KernelCoreContainer()
        let conversations = DefaultConversationManager()
        let toolManager = DefaultToolManagerProviding()
        try kernel.registerProvider((any ConversationManaging).self, conversations)
        try kernel.registerProvider((any ToolManagerProviding).self, toolManager)

        let plugin = AskUserPlugin()
        try plugin.onBoot(kernel: kernel)
        #expect(toolManager.tool(named: "ask_user") != nil)

        try plugin.onShutdown(kernel: kernel)
        #expect(toolManager.tool(named: "ask_user") == nil)
    }

    @Test("ask_user 工具经 AgentLoop 挂起后可恢复（端到端）")
    func endToEndSuspension() async throws {
        // 用脚本化 LLM：第一轮要求执行 ask_user，第二轮（恢复后）给出最终答复。
        final class ScriptedLLM: SuperLLMProvider, @unchecked Sendable {
            let providerID = "scripted"
            let providerInfo = LLMProviderInfo(id: "scripted", displayName: "Scripted", defaultModel: "", models: [], isLocal: true)
            var responses: [LLMResponse]
            init(responses: [LLMResponse]) { self.responses = responses }
            func complete(_ request: LLMRequest) async throws -> LLMResponse {
                guard !responses.isEmpty else { return LLMResponse(content: "") }
                return responses.removeFirst()
            }
        }

        let conversations = DefaultConversationManager()
        let toolManager = DefaultToolManagerProviding()
        toolManager.add(AskUserTool(conversations: conversations), pluginID: "test")

        // 直接验证 ToolManager 透传挂起语义（隔离 AgentLoop 层）。
        let direct = await toolManager.execute(
            ToolCall(id: "ask-0", name: "ask_user", arguments: #"{"question":"继续吗?","mode":"yes_no"}"#),
            conversationID: UUID(),
            turnID: nil
        )
        print(">>> direct awaitingUserResponse=\(direct.awaitingUserResponse) content=\(direct.content.prefix(60))")

        let provider = ScriptedLLM(responses: [
            LLMResponse(content: "", toolCalls: [
                LLMToolCall(id: "ask-1", name: "ask_user", arguments: #"{"question":"继续吗?","mode":"yes_no"}"#),
            ]),
            LLMResponse(content: "好的，继续"),
        ])

        let messages = DefaultMessageManager()
        let conversationID = UUID()
        messages.insertMessage(Message(conversationID: conversationID, role: .user, content: "帮我做决定"), to: conversationID)

        let loop = DefaultAgentLoopProvider(
            messages: messages,
            llmManager: ScriptedLLMManager(provider: provider),
            toolManager: toolManager,
            streaming: DefaultMessageStreamingProviding(),
            conversations: conversations
        )

        // 第一轮：ask_user → 挂起等待用户回答
        let outcome = try await loop.runTurn(in: conversationID)
        #expect(outcome == .suspended("userInput:ask-1"))
        let suspension = try #require(loop.suspension(for: conversationID))
        #expect(suspension.kind == "userInput")

        // 用户回答 → 恢复 → 工具结果回传 → 最终答复
        let resumed = try await loop.resumeTurn(
            in: conversationID,
            request: AgentTurnResumeRequest(suspensionID: suspension.suspensionID, answer: "是")
        )
        #expect(resumed == .completed)
        #expect(messages.lastMessage(in: conversationID)?.content == "好的，继续")
    }
}
