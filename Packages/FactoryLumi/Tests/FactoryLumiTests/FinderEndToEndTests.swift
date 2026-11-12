import Foundation
import KitAgentTool
import KernelCore
import ProviderMessage
import ProviderMessageRendering
import ProviderStorage
import ProviderToolManager
import Testing
@testable import FactoryLumi

/// 「LLM 调用工具 → 聊天区出现卡片 → 卡片可被渲染」这条主链路的端到端验证。
///
/// ## 为什么要有这组用例
///
/// 前面几组用例分别验证了插件装配与工具行为，但它们是**分段**验证的：
/// 装配层用 `tool(named:)` 看工具在不在，插件层用替身消息管理器看消息有没有插进去。
///
/// 分段验证留了一个缝：**工具真的经由 `ToolManagerProviding.submit` 跑起来时**，
/// 会不会把消息插进消息管理器、渲染器会不会命中这条消息——这两件事没人验证过。
/// 而这正是用户实际会走的路径。
///
/// 因此这里用真实的 Kernel 跑一遍：提交一次工具调用，等它结束，
/// 然后检查消息管理器里真的多了一条卡片消息，且渲染器认它。
@MainActor
@Suite("FactoryLumi · PluginFinder 端到端")
struct FinderEndToEndTests {

    private static let pluginID = "com.coffic.lumi.plugin.finder"
    private static let rendererID = "com.coffic.lumi.plugin.finder.card"

    @Test("工具经由工具管理器执行后产生可渲染的卡片消息")
    func toolExecutionProducesRenderableCardMessage() async throws {
        let kernel = try makeKernelWithFinderEnabled()
        let conversationID = UUID()

        let toolManager = try #require(kernel.resolveProvider((any ToolManagerProviding).self))
        let messages = try #require(kernel.resolveProvider((any MessageManaging).self))

        // 走真实路径：提交一次工具调用，由工具管理器执行。
        // 工具调用 ID 用 UUID：工具管理器按 (conversation, turn, toolCallID)
        // 去重，复用同一个 ID 会被当成同一个 job 而不重复执行。
        let jobs = toolManager.submit(
            [ToolCall(
                id: UUID().uuidString,
                name: "show_folder_card",
                arguments: #"{"path":"/tmp","title":"Demo","description":"Sample"}"#
            )],
            policy: .autoExecute,
            conversationID: conversationID,
            turnID: nil
        )
        #expect(jobs.count == 1)

        // 等工具跑完（工具是异步执行的）。
        let card = try await waitForCardMessage(
            in: messages,
            conversationID: conversationID
        )

        // 卡片消息带正确的 renderKind，且能被渲染器命中。
        #expect(card.renderKind == MessageTimelineEvent.finderRenderKind)
        #expect(card.preferredRendererID == Self.rendererID)

        let rendering = try #require(kernel.resolveProvider((any MessageRenderingProviding).self))
        #expect(rendering.renderer(for: card)?.id == Self.rendererID)
    }

    @Test("卡片消息不进入发给 LLM 的上下文")
    func cardMessageIsExcludedFromLLMContext() async throws {
        let kernel = try makeKernelWithFinderEnabled()
        let conversationID = UUID()

        let toolManager = try #require(kernel.resolveProvider((any ToolManagerProviding).self))
        let messages = try #require(kernel.resolveProvider((any MessageManaging).self))

        toolManager.submit(
            [ToolCall(
                id: UUID().uuidString,
                name: "show_folder_card",
                arguments: #"{"path":"/tmp"}"#
            )],
            policy: .autoExecute,
            conversationID: conversationID,
            turnID: nil
        )

        let card = try await waitForCardMessage(
            in: messages,
            conversationID: conversationID
        )

        // 卡片消息只是界面产物，不是一次对话轮次。
        #expect(MessageTimelineEvent.isTimelineEvent(card))
        #expect(MessageTimelineEvent.isFinder(card))
    }

    // MARK: - Helpers

    /// 等待卡片消息出现。
    ///
    /// 工具在后台异步执行，消息插入时机与提交调用不在同一拍，
    /// 因此这里轮询等待而不是假设它已经就位。
    /// 等卡片消息出现。
    ///
    /// - Important: 超时给到 15s。工具执行链路要经过「提交 → 工具管理器
    ///   调度 → 工具执行 → 消息插入」，在高负载下（CI 上多个包同时跑）
    ///   5s 偶尔不够 → **偶发**失败。上限只影响失败路径。
    private func waitForCardMessage(
        in messages: any MessageManaging,
        conversationID: UUID,
        timeout: TimeInterval = 15
    ) async throws -> Message {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if let card = messages.messages(for: conversationID).first(where: {
                MessageTimelineEvent.isFinder($0)
            }) {
                return card
            }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        throw ToolExecutionError.executionFailed(
            toolName: "show_folder_card",
            reason: "card message did not appear within \(timeout)s"
        )
    }

    /// 造一个启用了Finder 插件的内核。
    private func makeKernelWithFinderEnabled() throws -> KernelCoreContainer {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("FinderE2ETests-\(UUID().uuidString)", isDirectory: true)
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
