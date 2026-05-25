import Foundation
import AgentToolKit
import Testing
@testable import LumiCoreKit

@Suite("LumiCoreKit 基础类型测试")
struct LumiCoreKitTests {

    @Test("ChatMessage 初始化与属性")
    func chatMessageInit() {
        let msg = ChatMessage(
            role: .user,
            conversationId: UUID(),
            content: "Hello"
        )
        #expect(msg.role == .user)
        #expect(msg.content == "Hello")
        #expect(msg.isError == false)
        #expect(msg.toolCalls == nil)
        #expect(msg.shouldSendToLLM == true)
        #expect(msg.hasToolCalls == false)
    }

    @Test("ChatMessage 工具调用")
    func chatMessageWithToolCalls() {
        let toolCall = AgentToolKit.ToolCall(id: "tc_1", name: "read_file", arguments: "{\"path\": \"/tmp/test.txt\"}")
        let msg = ChatMessage(
            role: .assistant,
            conversationId: UUID(),
            content: "",
            toolCalls: [toolCall]
        )
        #expect(msg.hasToolCalls == true)
        #expect(msg.isToolOutput == false)
        #expect(msg.shouldSendToLLM == true)
    }

    @Test("ChatMessage 角色判断")
    func messageRoleSendableToLLM() {
        let cid = UUID()
        #expect(ChatMessage(role: .user, conversationId: cid, content: "").shouldSendToLLM == true)
        #expect(ChatMessage(role: .assistant, conversationId: cid, content: "").shouldSendToLLM == true)
        #expect(ChatMessage(role: .system, conversationId: cid, content: "").shouldSendToLLM == false)
        #expect(ChatMessage(role: .status, conversationId: cid, content: "").shouldSendToLLM == false)
        #expect(ChatMessage(role: .error, conversationId: cid, content: "").shouldSendToLLM == false)
    }

    @Test("PluginCategory 排序")
    func pluginCategorySortOrder() {
        #expect(PluginCategory.agent.sortOrder < PluginCategory.general.sortOrder)
        #expect(PluginCategory.editor.sortOrder < PluginCategory.theme.sortOrder)
    }

    @Test("StreamChunk 构造与属性")
    func streamChunkInit() {
        let chunk = StreamChunk(content: "Hi", isDone: false)
        #expect(chunk.content == "Hi")
        #expect(chunk.isDone == false)
        #expect(chunk.toolCalls == nil)

        let done = StreamChunk(isDone: true)
        #expect(done.isDone == true)
        #expect(done.content == nil)
    }

    @Test("StreamEventType 判断")
    func streamEventTypeChecks() {
        #expect(StreamEventType.thinkingDelta.isThinking() == true)
        #expect(StreamEventType.textDelta.isThinking() == false)
        #expect(StreamEventType.messageStop.isDone() == true)
        #expect(StreamEventType.ping.isReceivingContent() == true)
    }

    @Test("LLMModelSpec 与 LLMModelCapabilities")
    func modelSpecAndCapabilities() {
        let spec = LLMModelSpec(supportsVision: true, supportsTools: false)
        #expect(spec.capabilities.supportsVision == true)
        #expect(spec.capabilities.supportsTools == false)
        #expect(spec.contextWindowSize == nil)

        let specWithCtx = LLMModelSpec(contextWindowSize: 128000, supportsVision: false, supportsTools: true)
        #expect(specWithCtx.contextWindowSize == 128000)
    }

    @Test("LocalModelInfo 初始化")
    func localModelInfo() {
        let info = LocalModelInfo(
            id: "qwen-7b",
            displayName: "Qwen 7B",
            size: "4.2 GB",
            minRAM: 8,
            expectedBytes: 4_500_000_000
        )
        #expect(info.id == "qwen-7b")
        #expect(info.supportsVision == false)
        #expect(info.supportsTools == true)
        #expect(info.series == nil)
    }

    @Test("RailTab Equatable")
    func railTabEquatable() {
        let tab1 = RailTab(id: "tab1", title: "Tab 1", systemImage: "star", priority: 0)
        let tab2 = RailTab(id: "tab1", title: "Tab 2", systemImage: "circle", priority: 1)
        let tab3 = RailTab(id: "tab2", title: "Tab 1", systemImage: "star", priority: 0)
        #expect(tab1 == tab2) // same id
        #expect(tab1 != tab3) // different id
    }
}

// MARK: - MainActor 隔离测试

@Suite("LumiCoreKit MainActor 隔离测试")
@MainActor
struct LumiCoreKitActorTests {

    @Test("SendMessageContext 基本操作")
    func sendMessageContext() async {
        let msg = ChatMessage(role: .user, conversationId: UUID(), content: "test")
        let ctx = SendMessageContext(
            conversationId: msg.conversationId,
            message: msg
        )
        #expect(ctx.transientSystemPrompts.isEmpty)

        ctx.transientSystemPrompts.append("You are helpful")
        #expect(ctx.transientSystemPrompts.count == 1)
    }

    @Test("SendPipeline 中间件排序与执行")
    func sendPipelineOrdering() async {
        let executionOrder = LockedArray<String>()

        let m1 = PipelineTestMiddleware(id: "m1", order: 2, executionOrder: executionOrder)
        let m2 = PipelineTestMiddleware(id: "m2", order: 1, executionOrder: executionOrder)

        let pipeline = SendPipeline(middlewares: [m1, m2])
        let msg = ChatMessage(role: .user, conversationId: UUID(), content: "hi")
        let ctx = SendMessageContext(conversationId: msg.conversationId, message: msg)

        await pipeline.run(ctx: ctx) { _ in }

        let order = executionOrder.all
        #expect(order.count == 2)
        #expect(order[0] == "m2") // order=1 先执行
        #expect(order[1] == "m1") // order=2 后执行
    }
}

// MARK: - Test Helpers

/// 线程安全的数组（用于测试中记录执行顺序）
final class LockedArray<T>: @unchecked Sendable {
    private var _value: [T] = []
    private let lock = NSLock()

    var all: [T] {
        lock.lock()
        defer { lock.unlock() }
        return _value
    }

    func append(_ element: T) {
        lock.lock()
        _value.append(element)
        lock.unlock()
    }
}

/// 测试用中间件
@MainActor
struct PipelineTestMiddleware: SuperSendMiddleware {
    let id: String
    let order: Int
    let executionOrder: LockedArray<String>

    func handle(ctx: SendMessageContext, next: @escaping @MainActor (SendMessageContext) async -> Void) async {
        executionOrder.append(id)
        await next(ctx)
    }
}
