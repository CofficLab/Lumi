import Foundation
import KitAgentTool
import KernelCore
import ProviderMessage
import ProviderMessageRendering
import ProviderStorage
import ProviderToolManager
import Testing
@testable import FactoryLumi

/// 「LLM 调用工具 → 聊天区出现 HTML 卡片 → 卡片可被渲染」这条主链路的端到端验证。
///
/// ## 为什么要有这组用例
///
/// 前面几组用例分别验证了插件装配与工具行为，但它们是**分段**验证的：
/// 装配层用 `tool(named:)` 看工具在不在，插件层用替身消息管理器看消息有没有插进去。
///
/// 分段验证留了一个缝：**工具真的经由 `ToolManagerProviding.submit` 跑起来时**，
/// 会不会把消息插进消息管理器、渲染器会不会命中这条消息——这两件事没人验证过。
/// 而这正是用户实际会走的路径。
@MainActor
@Suite("FactoryLumi · PluginHTMLCanvas 端到端")
struct HTMLCanvasEndToEndTests {

    private static let pluginID = "com.coffic.lumi.plugin.html-canvas"
    private static let rendererID = "com.coffic.lumi.plugin.html-canvas.card"

    @Test("工具经由工具管理器执行后产生可渲染的画布消息")
    func toolExecutionProducesRenderableCanvasMessage() async throws {
        let kernel = try makeKernelWithHTMLCanvasEnabled()
        let conversationID = UUID()

        let toolManager = try #require(kernel.resolveProvider((any ToolManagerProviding).self))
        let messages = try #require(kernel.resolveProvider((any MessageManaging).self))

        // 走真实路径：提交一次工具调用，由工具管理器执行。
        // 工具调用 ID 用 UUID：工具管理器按 (conversation, turn, toolCallID)
        // 去重，复用同一个 ID 会被当成同一个 job 而不重复执行。
        let html = "<!DOCTYPE html><html><body><h1>Hi</h1></body></html>"
        let jobs = toolManager.submit(
            [ToolCall(
                id: UUID().uuidString,
                name: "show_html",
                arguments: #"{"html":"\#(html)","title":"Greeting"}"#
            )],
            policy: .autoExecute,
            conversationID: conversationID,
            turnID: nil
        )
        #expect(jobs.count == 1)

        // 等工具跑完（工具是异步执行的）。
        let canvas = try await waitForCanvasMessage(
            in: messages,
            conversationID: conversationID
        )

        // 画布消息带正确的 renderKind，且能被渲染器命中。
        #expect(canvas.renderKind == MessageTimelineEvent.htmlCanvasRenderKind)
        #expect(canvas.preferredRendererID == Self.rendererID)

        let rendering = try #require(kernel.resolveProvider((any MessageRenderingProviding).self))
        #expect(rendering.renderer(for: canvas)?.id == Self.rendererID)
    }

    @Test("画布消息不进入发给 LLM 的上下文")
    func canvasMessageIsExcludedFromLLMContext() async throws {
        let kernel = try makeKernelWithHTMLCanvasEnabled()
        let conversationID = UUID()

        let toolManager = try #require(kernel.resolveProvider((any ToolManagerProviding).self))
        let messages = try #require(kernel.resolveProvider((any MessageManaging).self))

        let html = "<!DOCTYPE html><html><body><h1>Hi</h1></body></html>"
        toolManager.submit(
            [ToolCall(
                id: UUID().uuidString,
                name: "show_html",
                arguments: #"{"html":"\#(html)"}"#
            )],
            policy: .autoExecute,
            conversationID: conversationID,
            turnID: nil
        )

        let canvas = try await waitForCanvasMessage(
            in: messages,
            conversationID: conversationID
        )

        // 画布消息只是界面产物，不是一次对话轮次。
        #expect(MessageTimelineEvent.isTimelineEvent(canvas))
        #expect(MessageTimelineEvent.isHTMLCanvas(canvas))
    }

    // MARK: - Helpers

    /// 等待画布消息出现。
    ///
    /// 工具在后台异步执行，消息插入时机与提交调用不在同一拍，
    /// 因此这里轮询等待而不是假设它已经就位。
    /// 等画布消息出现。
    ///
    /// - Important: 超时给到 15s。工具执行链路要经过「提交 → 工具管理器
    ///   调度 → 工具执行 → 消息插入」，在高负载下（CI 上多个包同时跑）
    ///   10s 偶尔不够 → **偶发**失败。上限只影响失败路径。
    private func waitForCanvasMessage(
        in messages: any MessageManaging,
        conversationID: UUID,
        timeout: TimeInterval = 15
    ) async throws -> Message {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if let canvas = messages.messages(for: conversationID).first(where: {
                MessageTimelineEvent.isHTMLCanvas($0)
            }) {
                return canvas
            }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        throw ToolExecutionError.executionFailed(
            toolName: "show_html",
            reason: "canvas message did not appear within \(timeout)s"
        )
    }

    /// 造一个启用了 HTML 画布插件的内核。
    private func makeKernelWithHTMLCanvasEnabled() throws -> KernelCoreContainer {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("HTMLCanvasE2ETests-\(UUID().uuidString)", isDirectory: true)
        let storage = DefaultStorageProvider(dataRootDirectory: root)
        let stateStore = PluginEnabledStateStore(
            pluginDirectory: storage.pluginDataDirectory(for: "com.coffic.lumi.plugin.plugin-manager")
        )
        stateStore.setEnabled(true, pluginID: Self.pluginID)

        let providerFactory = DefaultProviderFactory(dataRootDirectory: root)
        return try KernelFactory.makeKernel(
            providerFactory: providerFactory,
            pluginFactory: DefaultPluginFactory()
        )
    }
}
