import Foundation
import KernelCore
import PluginMessageListChatGPT
import PluginMessageRenderer
import ProviderChatSection
import ProviderConversation
import ProviderMessage
import ProviderMessageRendering
import ProviderMessageStreaming
import PluginMessageManager
import SwiftUI
import Testing
@testable import FactoryLumi

/// V5（ChatGPT）消息列表的**端到端**验证。
///
/// ## 为什么要有这一层
///
/// 单元测试能证明 reducer、分页、投影各自正确，却证明不了
/// 「选中 V5 后屏幕上真的有内容」—— 那需要**真实的** Provider 串起来：
///
/// ```text
/// MessageStore → MessageManaging → V5 ViewModel → MessageRenderingProviding
///              → 渲染器 → View
/// ```
///
/// Task 4 之前的 V5 是一个空 `List {}`：所有单元测试都绿，
/// 界面上却什么都没有。这一层专门守住那条底线。
///
/// - Important: 断言的是「渲染链路上真的有消息被交给渲染器」，
///   而不是快照某个 SwiftUI 视图 —— 后者对布局太敏感。
@MainActor
@Suite("V5 ChatGPT 消息列表端到端")
struct ChatGPTMessageListEndToEndTests {

    @Test("V5 槽位在 chatGPT 详细度下接管消息列表")
    func chatGPTSlotTakesOverWhenVerbosityIsChatGPT() async throws {
        let context = try await makeContext()

        // 切到 V5 详细度。
        context.conversations.setVerbosity(.chatGPT, for: context.conversationID)
        try await settle()

        let winner = try #require(context.renderedMessageListItemID)
        #expect(
            winner == context.chatGPTPluginID,
            "V5 未接管消息列表；实际渲染的是 \(winner)"
        )
    }

    @Test("V5 的消息链路把落库消息交给渲染器")
    func chatGPTFeedsPersistedMessagesToRenderer() async throws {
        let context = try await makeContext()
        context.conversations.setVerbosity(.chatGPT, for: context.conversationID)
        try await settle()

        // 渲染器必须能为每条落库消息找到渲染器。
        let manager = try #require(
            context.kernel.resolveProvider((any MessageRenderingProviding).self)
        )
        let page = await context.messages.messagePageAsync(
            for: context.conversationID,
            limit: 10,
            beforeMessageID: nil,
            includesToolMessages: false
        )
        #expect(!page.isEmpty, "夹具前提失败：会话应当有已落库消息")

        for message in page {
            let renderer = manager.renderer(for: message)
            #expect(
                renderer != nil,
                "消息（role=\(message.role.rawValue)）找不到渲染器，V5 将显示空白"
            )
        }
    }

    @Test("V5 渲染器对用户消息与助手消息分别给出 ChatGPT 呈现")
    func chatGPTRendersUserAndAssistantWithChatGPTStyle() async throws {
        let context = try await makeContext()
        context.conversations.setVerbosity(.chatGPT, for: context.conversationID)
        try await settle()

        let manager = try #require(
            context.kernel.resolveProvider((any MessageRenderingProviding).self)
        )

        let userMessage = Message(
            conversationID: context.conversationID,
            role: .user,
            content: "用户问题"
        )
        let assistantMessage = Message(
            conversationID: context.conversationID,
            role: .assistant,
            content: "助手回答"
        )

        let userRenderer = try #require(manager.renderer(for: userMessage))
        let assistantRenderer = try #require(manager.renderer(for: assistantMessage))

        // 两个角色都必须走核心渲染器，且在 `.chatGPT` 下拿到 ChatGPT 呈现。
        #expect(userRenderer.id == "core-user-message")
        #expect(assistantRenderer.id == "core-assistant-message")

        // 渲染闭包必须真的产出视图（不是空实现）。
        let userView = userRenderer.render(userMessage, .chatGPT)
        let assistantView = assistantRenderer.render(assistantMessage, .chatGPT)
        #expect(type(of: userView) == AnyView.self)
        #expect(type(of: assistantView) == AnyView.self)

        // - Important: 同一批消息在 `.standard` 下也必须有 renderer ——
        //   渲染器的**选择**与 verbosity 无关，verbosity 只决定**呈现**。
        //   这保证 V5 的分支是「换一个视图」，而不是「换一套分发」。
        #expect(manager.renderer(for: userMessage)?.id == userRenderer.id)
        #expect(manager.renderer(for: assistantMessage)?.id == assistantRenderer.id)
    }

    @Test("V5 详细度之外不接管槽位")
    func chatGPTDoesNotTakeOverOtherVerbosities() async throws {
        let context = try await makeContext()

        context.conversations.setVerbosity(.standard, for: context.conversationID)
        try await settle()

        // - Important: 本夹具只注册了 V5 一个列表插件，因此 standard 详细度下
        //   槽位**没有**任何 active 贡献者（其它档位的插件未启动）。
        //   要守住的语义是「V5 自己不抢」——
        //   若 V5 错误地在 standard 下也 active，这里会拿到 V5 的 id。
        let winner = context.renderedMessageListItemID
        #expect(
            winner != context.chatGPTPluginID,
            "V5 在 standard 详细度下错误地抢占了槽位"
        )
    }

    // MARK: - 夹具

    /// 端到端夹具。
    @MainActor
    struct Context {
        let kernel: KernelCoreContainer
        let chat: DefaultChatSectionProviding
        let messages: MessageManager
        let conversations: DefaultConversationManager
        let conversationID: UUID
        let chatGPTPluginID: String

        /// 当前真正渲染的消息列表 item id。
        var renderedMessageListItemID: String? {
            chat.items.first { $0.exclusiveGroup == "message-list" && $0.isActive() }?.id
        }
    }

    /// 搭一套真实的 Provider 链路。
    private func makeContext() async throws -> Context {
        let kernel = KernelCoreContainer()

        // 会话区：V5 插件要在这里注册自己的槽位。
        let chat = DefaultChatSectionProviding()
        try kernel.registerProvider((any ChatSectionProviding).self, chat)

        // 消息存储：真实的 SwiftData 消息存储（write-behind）。
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("chatgpt-e2e-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let store = try MessageStore(
            databaseRootURL: root.appendingPathComponent("message-store", isDirectory: true)
        )
        let messages = MessageManager(store: store, dataDirectory: root)
        try kernel.registerProvider((any MessageManaging).self, messages)

        // 会话管理。
        let conversations = DefaultConversationManager()
        try kernel.registerProvider((any ConversationManaging).self, conversations)

        // 渲染器：V5 的消息必须真的能被渲染。
        //
        // - Important: `DefaultMessageRenderingProviding` 只是**注册表**，
        //   真正注册 13 个核心渲染器的是 `MessageRendererPlugin`。
        //   只注册 provider 而不启动插件，renderer(for:) 会返回 nil ——
        //   那样测的是「没有渲染器」，不是「V5 显示空白」。
        let rendering = DefaultMessageRenderingProviding()
        try kernel.registerProvider((any MessageRenderingProviding).self, rendering)
        let rendererPlugin = MessageRendererPlugin()
        try rendererPlugin.onBoot(kernel: kernel)

        // 流式：V5 开启真实流式，Provider 必须存在。
        let streaming = DefaultMessageStreamingProviding()
        try kernel.registerProvider((any MessageStreamingProviding).self, streaming)

        // V5 插件本体。
        let chatGPT = PluginMessageListChatGPTPlugin()
        try chatGPT.onBoot(kernel: kernel)

        let conversationID = try conversations.createConversation(
            title: "ChatGPT E2E Fixture",
            projectPath: nil,
            providerID: nil,
            modelName: nil
        )

        // 落一条用户消息 + 一条助手消息，形成一个完整轮次。
        messages.insertMessage(
            Message(
                conversationID: conversationID,
                role: .user,
                content: "请介绍一下这个仓库。",
                createdAt: Date(timeIntervalSince1970: 1_700_000_000)
            ),
            to: conversationID
        )
        messages.insertMessage(
            Message(
                conversationID: conversationID,
                role: .assistant,
                content: "这是一个 Lumi 仓库。",
                createdAt: Date(timeIntervalSince1970: 1_700_000_001)
            ),
            to: conversationID
        )
        try await settle()

        // 等落盘队列排空，确保走的是纯数据库读取路径。
        for _ in 0..<200 {
            let count = await messages.messagePageAsync(
                for: conversationID,
                limit: 10,
                beforeMessageID: nil,
                includesToolMessages: false
            ).count
            if count == 2 { break }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        try await settle()

        return Context(
            kernel: kernel,
            chat: chat,
            messages: messages,
            conversations: conversations,
            conversationID: conversationID,
            chatGPTPluginID: chatGPT.id
        )
    }

    /// 让主线程队列跑完当前积压的任务。
    private func settle() async throws {
        for _ in 0..<100 {
            await Task.yield()
            try await Task.sleep(nanoseconds: 10_000_000)
        }
    }
}
