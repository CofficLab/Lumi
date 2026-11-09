import Foundation
import KitAgentTool
import ProviderMessage
import ProviderMessageRendering
import SwiftUI
import Testing
@testable import PluginHTMLCanvas

/// 「LLM 调用工具 → 聊天区出现一张 HTML 界面卡片」这条主链路的单元测试。
///
/// ## 为什么要有这组用例
///
/// 这个插件的价值全在「工具执行后，聊天区真的多了一张能看见的界面」。
/// 这条链路横跨三个部件（工具 → 时间线消息 → 渲染器），任何一环断了都表现为
/// 「卡片不出现」或「界面是空的」，很难靠读代码定位。因此这里把三环分别钉住：
///
/// 1. 工具能产出带正确载荷的时间线消息，且 HTML 真的落盘了；
/// 2. 该消息是**时间线事件**，不会回流到 LLM 上下文；
/// 3. 渲染器只认这类消息，且优先级高到不会被通用渲染器抢走。
@MainActor
@Suite(.serialized)
struct HTMLCanvasCardTests {

    // MARK: - 工具产出消息

    @Test func toolProducesTimelineMessageWithPayload() async throws {
        let manager = RecordingMessageManager()
        let bridge = HTMLCanvasMessageBridge()
        bridge.configure(messages: manager)

        let directory = try makeTemporaryDirectory()
        let conversationID = UUID()
        let tool = ShowHTMLTool(bridge: bridge, storageDirectory: directory)
        let result = try await tool.executeResult(
            context: ToolExecutionContext(
                jobID: "job-1",
                conversationID: conversationID,
                turnID: UUID()
            ),
            arguments: [
                "html": ToolArgument(Self.sampleHTML),
                "title": ToolArgument("Demo Chart"),
            ]
        )

        #expect(!result.isError)
        #expect(manager.inserted.count == 1)

        let message = try #require(manager.inserted.first?.message)
        #expect(message.conversationID == conversationID)
        #expect(message.renderKind == MessageTimelineEvent.htmlCanvasRenderKind)

        let payload = try #require(HTMLCanvasTimeline.decodePayload(from: message.metadata))
        #expect(payload.title == "Demo Chart")
        #expect(payload.hasHTMLFile)
    }

    /// HTML 原文只服务于当次显示：工具必须声明它不进入后续模型上下文（Issue #1053）。
    @Test func toolOmitsHTMLFromModelContext() {
        let tool = ShowHTMLTool(bridge: HTMLCanvasMessageBridge(), storageDirectory: URL(fileURLWithPath: "/tmp"))

        #expect(tool.contextOmittedArgumentKeys == ["html"])
    }

    @Test func toolWritesHTMLToDisk() async throws {
        let manager = RecordingMessageManager()
        let bridge = HTMLCanvasMessageBridge()
        bridge.configure(messages: manager)

        let directory = try makeTemporaryDirectory()
        let tool = ShowHTMLTool(bridge: bridge, storageDirectory: directory)
        _ = try await tool.executeResult(
            context: ToolExecutionContext(
                jobID: "job-1",
                conversationID: UUID(),
                turnID: nil
            ),
            arguments: ["html": ToolArgument(Self.sampleHTML)]
        )

        let message = try #require(manager.inserted.first?.message)
        let payload = try #require(HTMLCanvasTimeline.decodePayload(from: message.metadata))

        // HTML 真的写进了磁盘，而不是留在内存里。
        let written = try String(contentsOf: URL(fileURLWithPath: payload.htmlPath), encoding: .utf8)
        #expect(written.contains("<h1>Demo</h1>"))
    }

    @Test func toolWithoutConversationContextProducesNoMessage() async throws {
        let manager = RecordingMessageManager()
        let bridge = HTMLCanvasMessageBridge()
        bridge.configure(messages: manager)

        let directory = try makeTemporaryDirectory()
        let tool = ShowHTMLTool(bridge: bridge, storageDirectory: directory)
        let result = try await tool.executeResult(arguments: ["html": ToolArgument(Self.sampleHTML)])

        #expect(!result.isError)
        #expect(manager.inserted.isEmpty)
    }

    @Test func toolRejectsEmptyHTML() async throws {
        let manager = RecordingMessageManager()
        let bridge = HTMLCanvasMessageBridge()
        bridge.configure(messages: manager)

        let directory = try makeTemporaryDirectory()
        let tool = ShowHTMLTool(bridge: bridge, storageDirectory: directory)
        let result = try await tool.executeResult(arguments: ["html": ToolArgument("   ")])

        #expect(result.isError)
        #expect(manager.inserted.isEmpty)
    }

    @Test func toolRejectsMissingHTML() async throws {
        let manager = RecordingMessageManager()
        let bridge = HTMLCanvasMessageBridge()
        bridge.configure(messages: manager)

        let directory = try makeTemporaryDirectory()
        let tool = ShowHTMLTool(bridge: bridge, storageDirectory: directory)
        let result = try await tool.executeResult(arguments: [:])

        #expect(result.isError)
        #expect(manager.inserted.isEmpty)
    }

    /// 回归 Issue #1054：开始前已取消的工具不能落盘，也不能插入卡片。
    @Test func toolSkipsTimelineWhenCancelledBeforeStart() async throws {
        let manager = RecordingMessageManager()
        let bridge = HTMLCanvasMessageBridge()
        bridge.configure(messages: manager)

        let directory = try makeTemporaryDirectory()
        let tool = ShowHTMLTool(bridge: bridge, storageDirectory: directory)

        await #expect(throws: CancellationError.self) {
            _ = try await tool.executeResult(
                context: ToolExecutionContext(
                    jobID: "job-cancelled",
                    conversationID: UUID(),
                    turnID: UUID(),
                    isCancelled: { true }
                ),
                arguments: ["html": ToolArgument(Self.sampleHTML)]
            )
        }

        #expect(manager.inserted.isEmpty)
        let contents = try FileManager.default.contentsOfDirectory(atPath: directory.path)
        #expect(contents.isEmpty)
    }

    /// 回归 Issue #1054：快照完成时才发现取消，也不能发布卡片或留下产物。
    @Test func toolSkipsTimelineWhenCancellationArrivesAfterRender() async throws {
        let manager = RecordingMessageManager()
        let bridge = HTMLCanvasMessageBridge()
        bridge.configure(messages: manager)

        // 第一次查询（开始前）返回未取消，让渲染真实跑完；
        // 第二次查询（发布前）返回已取消。
        let probe = ScriptedCancellation(uncancelledCalls: 1)
        let directory = try makeTemporaryDirectory()
        let tool = ShowHTMLTool(bridge: bridge, storageDirectory: directory)

        await #expect(throws: CancellationError.self) {
            _ = try await tool.executeResult(
                context: ToolExecutionContext(
                    jobID: "job-late-cancel",
                    conversationID: UUID(),
                    turnID: UUID(),
                    isCancelled: { probe.isCancelled }
                ),
                arguments: ["html": ToolArgument(Self.sampleHTML)]
            )
        }

        #expect(manager.inserted.isEmpty)
        let contents = try FileManager.default.contentsOfDirectory(atPath: directory.path)
        #expect(contents.isEmpty)
    }

    // MARK: - 参数解析

    @Test func canvasSizeDefaultsWhenAbsent() {
        #expect(ShowHTMLTool.double(from: [:], key: "width") == nil)
        #expect(ShowHTMLTool.defaultWidth == 800)
        #expect(ShowHTMLTool.defaultHeight == 600)
    }

    @Test func canvasSizeClampsOutOfRangeValues() {
        // 过小的画布渲染出来是空白，过大的让快照 PNG 体积失控。
        let tooSmall = ShowHTMLTool.double(from: ["width": ToolArgument(10.0)], key: "width")
        #expect(tooSmall == ShowHTMLTool.minCanvasSize)

        let tooLarge = ShowHTMLTool.double(from: ["height": ToolArgument(99_999.0)], key: "height")
        #expect(tooLarge == ShowHTMLTool.maxCanvasSize)
    }

    @Test func canvasSizeAcceptsIntegerAndStringValues() {
        // 不同 LLM 供应商把 JSON 数字解析成 Int / Double / String 都可能。
        #expect(ShowHTMLTool.double(from: ["width": ToolArgument(640)], key: "width") == 640)
        #expect(ShowHTMLTool.double(from: ["width": ToolArgument("640")], key: "width") == 640)
        #expect(ShowHTMLTool.double(from: ["width": ToolArgument(640.5)], key: "width") == 640.5)
    }

    @Test func canvasSizeRejectsNonFiniteValues() {
        // NaN / Infinity 会让快照渲染拿到非法尺寸。
        #expect(ShowHTMLTool.double(from: ["width": ToolArgument(Double.nan)], key: "width") == nil)
        #expect(ShowHTMLTool.double(from: ["width": ToolArgument(Double.infinity)], key: "width") == nil)
    }

    // MARK: - 时间线事件过滤

    @Test func canvasMessageIsFilteredOutOfLLMContext() {
        let message = HTMLCanvasTimeline.message(
            conversationID: UUID(),
            turnID: nil,
            payload: HTMLCanvasPayload(
                htmlPath: "/tmp/demo.html",
                width: 800,
                height: 600
            )
        )

        #expect(MessageTimelineEvent.isHTMLCanvas(message))
        #expect(MessageTimelineEvent.isTimelineEvent(message))
    }

    @Test func ordinaryMessageIsNotFilteredOutOfLLMContext() {
        let message = Message(
            conversationID: UUID(),
            role: .assistant,
            content: "hello"
        )

        #expect(!MessageTimelineEvent.isHTMLCanvas(message))
        #expect(!MessageTimelineEvent.isTimelineEvent(message))
    }

    // MARK: - 渲染器

    @Test func rendererMatchesCanvasMessageOnly() {
        let renderer = HTMLCanvasRenderer.item(order: 89)

        let canvas = HTMLCanvasTimeline.message(
            conversationID: UUID(),
            turnID: nil,
            payload: HTMLCanvasPayload(
                htmlPath: "/tmp/demo.html",
                width: 800,
                height: 600
            )
        )
        let ordinary = Message(
            conversationID: UUID(),
            role: .assistant,
            content: "hello"
        )

        #expect(renderer.canRender(canvas))
        #expect(!renderer.canRender(ordinary))
    }

    @Test func rendererPriorityBeatsGenericRenderers() {
        // 核心渲染器的系统消息项 order 为 base + 150（base = 10）。
        // 插件 order 必须高于后者，否则画布消息（role = .system）
        // 会被通用系统消息渲染器接管，用户看到的是一行纯文本。
        let coreBase = 10
        let coreSystemMessageOrder = coreBase + 150
        let renderer = HTMLCanvasRenderer.item(order: HTMLCanvasPlugin().order)

        #expect(renderer.order > coreSystemMessageOrder)
    }

    @Test func rendererWinsOverCoreSystemMessageRenderer() {
        let provider = DefaultMessageRenderingProviding()
        provider.register(MessageRendererItem(
            id: "core-system-message",
            order: 160
        ) { _, _ in
            AnyView(EmptyView())
        })
        provider.register(HTMLCanvasRenderer.item(order: HTMLCanvasPlugin().order))

        let canvas = HTMLCanvasTimeline.message(
            conversationID: UUID(),
            turnID: nil,
            payload: HTMLCanvasPayload(
                htmlPath: "/tmp/demo.html",
                width: 800,
                height: 600
            )
        )

        #expect(canvas.role == .system)
        #expect(provider.renderer(for: canvas)?.id == HTMLCanvasTimeline.rendererID)
    }

    // MARK: - 载荷编解码

    @Test func payloadSurvivesEncodingRoundTrip() throws {
        let payload = HTMLCanvasPayload(
            title: "Title",
            htmlPath: "/tmp/demo.html",
            snapshotPath: "/tmp/demo.png",
            width: 640,
            height: 480
        )

        let metadata = HTMLCanvasTimeline.metadata(for: payload)
        let decoded = try #require(HTMLCanvasTimeline.decodePayload(from: metadata))

        #expect(decoded == payload)
    }

    @Test func missingPayloadDecodesToNil() {
        #expect(HTMLCanvasTimeline.decodePayload(from: [:]) == nil)
    }

    @Test func payloadTreatsBlankTitleAsAbsent() {
        let payload = HTMLCanvasPayload(
            title: "   ",
            htmlPath: "/tmp/demo.html",
            width: 800,
            height: 600
        )
        #expect(payload.displayTitle == nil)
    }

    @Test func payloadReportsMissingFilesAsAbsent() {
        let payload = HTMLCanvasPayload(
            htmlPath: "/definitely/not/here/xyz.html",
            snapshotPath: "/definitely/not/here/xyz.png",
            width: 800,
            height: 600
        )
        #expect(!payload.hasHTMLFile)
        #expect(!payload.hasSnapshot)
    }

    // MARK: - Helpers

    /// 造一个用完即删的临时目录。
    private func makeTemporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("html-canvas-test-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    /// 一份最小可渲染的 HTML 文档。
    private static let sampleHTML = """
    <!DOCTYPE html>
    <html><head><meta charset="utf-8"><title>Demo</title></head>
    <body><h1>Demo</h1></body></html>
    """
}

/// 前 N 次查询返回未取消，之后返回已取消；用于复现「渲染完成后才发现取消」。
private final class ScriptedCancellation: @unchecked Sendable {
    private let lock = NSLock()
    private var uncancelledCalls: Int

    init(uncancelledCalls: Int) {
        self.uncancelledCalls = uncancelledCalls
    }

    var isCancelled: Bool {
        lock.lock()
        defer { lock.unlock() }
        if uncancelledCalls > 0 {
            uncancelledCalls -= 1
            return false
        }
        return true
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
    ) async -> Bool { false }
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
