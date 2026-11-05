import Foundation
import KitAgentTool
import ProviderMessage
import ProviderMessageRendering
import SwiftUI
import Testing
@testable import PluginFinder

/// 「LLM 调用工具 → 聊天区出现一张卡片」这条主链路的单元测试。
///
/// ## 为什么要有这组用例
///
/// 这个插件的价值全在「工具执行后，聊天区真的多了一张能点开文件夹的卡片」。
/// 这条链路横跨三个部件（工具 → 时间线消息 → 渲染器），任何一环断了都表现为
/// 「点了没反应」或「卡片不出现」，很难靠读代码定位。因此这里把三环分别钉住：
///
/// 1. 工具能产出带正确载荷的时间线消息；
/// 2. 该消息是**时间线事件**，不会回流到 LLM 上下文；
/// 3. 渲染器只认这类消息，且优先级高到不会被通用渲染器抢走。
@MainActor
@Suite(.serialized)
struct FinderCardTests {

    // MARK: - 工具产出消息

    @Test func toolProducesTimelineMessageWithPayload() async throws {
        let manager = RecordingMessageManager()
        let bridge = FinderMessageBridge()
        bridge.configure(messages: manager)

        let conversationID = UUID()
        let tool = ShowFolderCardTool(bridge: bridge)
        let result = try await tool.executeResult(
            context: ToolExecutionContext(
                jobID: "job-1",
                conversationID: conversationID,
                turnID: UUID()
            ),
            arguments: [
                "path": ToolArgument("/tmp/demo"),
                "title": ToolArgument("Demo Folder"),
                "description": ToolArgument("Sample assets"),
            ]
        )

        #expect(!result.isError)
        #expect(manager.inserted.count == 1)

        let message = try #require(manager.inserted.first?.message)
        #expect(message.conversationID == conversationID)
        #expect(message.renderKind == MessageTimelineEvent.finderRenderKind)

        let payload = try #require(FinderTimeline.decodePayload(from: message.metadata))
        #expect(payload.path == "/tmp/demo")
        #expect(payload.title == "Demo Folder")
        #expect(payload.description == "Sample assets")
    }

    @Test func toolWithoutConversationContextProducesNoMessage() async throws {
        let manager = RecordingMessageManager()
        let bridge = FinderMessageBridge()
        bridge.configure(messages: manager)

        let tool = ShowFolderCardTool(bridge: bridge)
        let result = try await tool.executeResult(arguments: ["path": ToolArgument("/tmp/demo")])

        #expect(!result.isError)
        #expect(manager.inserted.isEmpty)
    }

    @Test func toolRejectsEmptyPath() async throws {
        let manager = RecordingMessageManager()
        let bridge = FinderMessageBridge()
        bridge.configure(messages: manager)

        let tool = ShowFolderCardTool(bridge: bridge)
        let result = try await tool.executeResult(arguments: ["path": ToolArgument("   ")])

        #expect(result.isError)
        #expect(manager.inserted.isEmpty)
    }

    // MARK: - 时间线事件过滤

    @Test func cardMessageIsFilteredOutOfLLMContext() {
        let message = FinderTimeline.message(
            conversationID: UUID(),
            turnID: nil,
            payload: FinderCardPayload(path: "/tmp/demo")
        )

        #expect(MessageTimelineEvent.isFinder(message))
        #expect(MessageTimelineEvent.isTimelineEvent(message))
    }

    @Test func ordinaryMessageIsNotFilteredOutOfLLMContext() {
        let message = Message(
            conversationID: UUID(),
            role: .assistant,
            content: "hello"
        )

        #expect(!MessageTimelineEvent.isFinder(message))
        #expect(!MessageTimelineEvent.isTimelineEvent(message))
    }

    // MARK: - 渲染器

    @Test func rendererMatchesCardMessageOnly() {
        let renderer = FinderCardRenderer.item(order: 89)

        let card = FinderTimeline.message(
            conversationID: UUID(),
            turnID: nil,
            payload: FinderCardPayload(path: "/tmp/demo")
        )
        let ordinary = Message(
            conversationID: UUID(),
            role: .assistant,
            content: "hello"
        )

        #expect(renderer.canRender(card))
        #expect(!renderer.canRender(ordinary))
    }

    @Test func rendererPriorityBeatsGenericRenderers() {
        // 核心渲染器的兜底项 order 为 base - 10（base = 10），
        // 系统消息项为 base + 150。插件 order 必须高于后者，
        // 否则卡片消息（role = .system）会被通用系统消息渲染器接管。
        let coreBase = 10
        let coreSystemMessageOrder = coreBase + 150
        let renderer = FinderCardRenderer.item(order: FinderPlugin().order)

        #expect(renderer.order > coreSystemMessageOrder)
        #expect(renderer.order > coreBase - 10)
    }

    @Test func rendererIsSelectedForCardMessageByProvider() {
        let provider = DefaultMessageRenderingProviding()
        provider.register(MessageRendererItem(
            id: "core-default-markdown",
            order: 0
        ) { _, _ in
            AnyView(EmptyView())
        })
        provider.register(FinderCardRenderer.item(order: FinderPlugin().order))

        let card = FinderTimeline.message(
            conversationID: UUID(),
            turnID: nil,
            payload: FinderCardPayload(path: "/tmp/demo")
        )

        let selected = provider.renderer(for: card)
        #expect(selected?.id == FinderTimeline.rendererID)
    }

    @Test func rendererWinsOverCoreSystemMessageRenderer() {
        // 卡片消息的 role 是 .system，核心渲染器里 `core-system-message`
        // 也会认领它。两者同时注册时，卡片渲染器必须胜出，
        // 否则用户看到的是一行纯文本而不是可点击的卡片。
        let provider = DefaultMessageRenderingProviding()
        provider.register(MessageRendererItem(
            id: "core-system-message",
            order: 160
        ) { _, _ in
            AnyView(EmptyView())
        })
        provider.register(FinderCardRenderer.item(order: FinderPlugin().order))

        let card = FinderTimeline.message(
            conversationID: UUID(),
            turnID: nil,
            payload: FinderCardPayload(path: "/tmp/demo")
        )

        #expect(card.role == .system)
        #expect(provider.renderer(for: card)?.id == FinderTimeline.rendererID)
    }

    // MARK: - 载荷编解码

    @Test func payloadSurvivesEncodingRoundTrip() throws {
        let payload = FinderCardPayload(
            title: "Title",
            description: "Desc",
            path: "/tmp/demo",
            actionTitle: "Open"
        )

        let metadata = FinderTimeline.metadata(for: payload)
        let decoded = try #require(FinderTimeline.decodePayload(from: metadata))

        #expect(decoded == payload)
    }

    @Test func missingPayloadDecodesToNil() {
        #expect(FinderTimeline.decodePayload(from: [:]) == nil)
    }

    @Test func payloadFallsBackToFolderNameForTitle() {
        let payload = FinderCardPayload(path: "/tmp/demo")
        #expect(payload.displayTitle == "demo")
    }

    @Test func payloadTreatsBlankDescriptionAsAbsent() {
        let payload = FinderCardPayload(
            description: "   ",
            path: "/tmp/demo"
        )
        #expect(payload.displayDescription == nil)
    }

    // MARK: - Finder 路径校验

    @Test func finderOpenerRejectsMissingDirectory() {
        #expect(FinderOpener.validatedURL(for: "/definitely/not/here/xyz") == nil)
    }

    @Test func finderOpenerRejectsEmptyPath() {
        #expect(FinderOpener.validatedURL(for: "   ") == nil)
    }

    @Test func finderOpenerAcceptsExistingDirectory() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("finder-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: directory) }

        let url = try #require(FinderOpener.validatedURL(for: directory.path))
        #expect(url.path == directory.path)
    }

    @Test func finderOpenerRejectsFileInsteadOfDirectory() throws {
        // 工具允许传文件路径，但卡片按钮的语义是「打开文件夹」。
        // 这里确认文件不会被当成目录放行。
        let file = FileManager.default.temporaryDirectory
            .appendingPathComponent("finder-file-\(UUID().uuidString).txt")
        try Data("x".utf8).write(to: file)
        defer { try? FileManager.default.removeItem(at: file) }

        #expect(FinderOpener.validatedURL(for: file.path) == nil)
    }
}

/// 记录插入的消息，替代真实 `MessageManaging`。
@MainActor
private final class RecordingMessageManager: MessageManaging {
    private(set) var inserted: [(message: Message, conversationID: UUID)] = []

    func insertMessage(_ message: Message, to conversationID: UUID) {
        inserted.append((message, conversationID))
    }

    func messages(for conversationID: UUID) -> [Message] { [] }
    func messagesSnapshot(in conversationID: UUID) async -> [Message] { [] }
    func firstUserMessage(in conversationID: UUID) async -> Message? { nil }
    func messagesForLLM(in conversationID: UUID) async -> [Message] { [] }
    func messagePage(
        for conversationID: UUID,
        limit: Int,
        beforeMessageID: UUID?,
        includesToolMessages: Bool
    ) -> [Message] { [] }
    func messagePageAsync(
        for conversationID: UUID,
        limit: Int,
        beforeMessageID: UUID?,
        includesToolMessages: Bool
    ) async -> [Message] { [] }
    func hasEarlierMessages(
        for conversationID: UUID,
        beforeMessageID: UUID?,
        includesToolMessages: Bool
    ) -> Bool { false }
    func hasEarlierMessagesAsync(
        for conversationID: UUID,
        beforeMessageID: UUID?,
        includesToolMessages: Bool
    ) -> Bool { false }
    func message(id: UUID, in conversationID: UUID) -> Message? { nil }
    func lastMessage(in conversationID: UUID) -> Message? { nil }
    func messageCount(for conversationID: UUID) -> Int { 0 }
    func dailyMessageCounts(since: Date) -> [Date: Int] { [:] }
    func dailyMessageCountsAsync(since: Date) async -> [Date: Int] { [:] }
    func dailyTokenCounts(since: Date) -> [Date: Int] { [:] }
    func dailyTokenCountsAsync(since: Date) async -> [Date: Int] { [:] }
    func dailyMessageCountsAsync(since: Date, conversationIDs: [String]?) async -> [Date: Int] { [:] }
    func dailyTokenCountsAsync(since: Date, conversationIDs: [String]?) async -> [Date: Int] { [:] }
    func updateMessage(id: UUID, in conversationID: UUID, content: String) {}
    func updateToolCallResult(
        _ result: MessageToolResult,
        toolCallID: String,
        assistantMessageID: UUID,
        in conversationID: UUID,
        authorizationState: String?
    ) {}
    func deleteMessage(id: UUID, in conversationID: UUID) {}
    func clearMessages(in conversationID: UUID) {}
}
