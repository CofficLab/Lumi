import Foundation
import KernelCore
import KitLLM
import ProviderAgentLoop
import ProviderConversation
import ProviderLLMContext
import ProviderLLMManager
import ProviderMessage
import ProviderMessageStreaming
import ProviderToolManager
import Testing
@testable import PluginAgentLoop

/// 一张 1x1 的 PNG。
private let generatedImagePNGBytes = Data(base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==")!

/// 图像生成模型的「只生成图片」响应是一次**成功**的响应。
///
/// ## 为什么要有这条测试
///
/// OpenRouter 的 Seedream 等图像模型返回的图片在 `message.images` /
/// `delta.images` 里。响应契约此前没有图片的表示，生成的图片被丢弃，
/// 助手消息变成空文本——而空文本响应会被 AgentLoop 判为「空响应失败」。
///
/// 结果是：一次成功的生成被呈现为失败，用户既看不到图片，也收不到任何
/// 错误说明。
@MainActor
@Suite("AgentLoop 图像生成响应")
struct AgentLoopGeneratedImageTests {

    /// 只返回图片的供应商替身。
    private final class ImageOnlyProvider: SuperLLMProvider, LLMStreamingProviding, @unchecked Sendable {
        nonisolated let providerID = "image-only"
        nonisolated let providerInfo = LLMProviderInfo(
            id: "image-only",
            displayName: "Image Only",
            defaultModel: "image-model",
            models: [LLMModelInfo(id: "image-model")],
            isLocal: true
        )

        func complete(_ request: LLMRequest) async throws -> LLMResponse {
            LLMResponse(
                content: "",
                model: "image-model",
                images: [MessageImage(data: generatedImagePNGBytes, mimeType: "image/png")]
            )
        }

        func streamComplete(
            _ request: LLMRequest,
            onChunk: @escaping @Sendable (LLMStreamChunk) async -> Void
        ) async throws -> LLMResponse {
            let image = MessageImage(data: generatedImagePNGBytes, mimeType: "image/png")
            await onChunk(LLMStreamChunk(images: [image]))
            return LLMResponse(content: "", model: "image-model", images: [image])
        }
    }

    /// 记录请求的 LLM 管理器替身。
    private final class ImageRecordingLLMManager: LLMManaging, LLMStreamingProviding, @unchecked Sendable {
        private let provider: ImageOnlyProvider

        init(provider: ImageOnlyProvider) {
            self.provider = provider
        }

        var providerID: String { Self.managerProviderID }
        var providerInfo: LLMProviderInfo {
            LLMProviderInfo(id: providerID, displayName: "Test Manager", defaultModel: "", models: [], isLocal: true)
        }

        func complete(_ request: LLMRequest) async throws -> LLMResponse {
            try await provider.complete(request)
        }

        func streamComplete(
            _ request: LLMRequest,
            onChunk: @escaping @Sendable (LLMStreamChunk) async -> Void
        ) async throws -> LLMResponse {
            try await provider.streamComplete(request, onChunk: onChunk)
        }

        func allProviders() -> [any SuperLLMProvider] { [provider] }
        func provider(id: String) -> (any SuperLLMProvider)? { id == provider.providerInfo.id ? provider : nil }
        var providerCount: Int { 1 }
        func register(_ provider: any SuperLLMProvider) throws {}
        func unregister(id: String) {}
        var selectedProviderID: String? { provider.providerInfo.id }
        var selectedModel: String? { provider.providerInfo.defaultModel }
        func models(for providerID: String) -> [String] { provider.providerInfo.modelIDs }
        func select(providerID: String, model: String?, reason: ModelSelectionReason) {}
    }

    // MARK: - Tests

    @Test("只生成图片的响应不被判为空响应失败")
    func imageOnlyResponseIsNotFailure() async throws {
        let provider = ImageOnlyProvider()
        let llmManager = ImageRecordingLLMManager(provider: provider)
        let messageStore = DefaultMessageManager()
        let manager = AgentLoopManager(
            messages: messageStore,
            llmManager: llmManager,
            toolManager: DefaultToolManagerProviding(),
            streaming: DefaultMessageStreamingProviding(),
            conversations: DefaultConversationManager(),
            contextProvider: PassthroughLLMContextProvider(messages: messageStore)
        )
        let conversationID = UUID()

        let outcome = try await manager.runTurn(in: conversationID)

        #expect(
            outcome == .completed,
            "只生成图片的响应是成功响应，不应走失败链路"
        )
    }

    @Test("生成的图片随助手消息落库")
    func generatedImagesArePersisted() async throws {
        let provider = ImageOnlyProvider()
        let llmManager = ImageRecordingLLMManager(provider: provider)
        let messageStore = DefaultMessageManager()
        let manager = AgentLoopManager(
            messages: messageStore,
            llmManager: llmManager,
            toolManager: DefaultToolManagerProviding(),
            streaming: DefaultMessageStreamingProviding(),
            conversations: DefaultConversationManager(),
            contextProvider: PassthroughLLMContextProvider(messages: messageStore)
        )
        let conversationID = UUID()

        _ = try await manager.runTurn(in: conversationID)

        let assistant = try #require(
            messageStore.messages(for: conversationID).first { $0.role == .assistant },
            "应落库一条助手消息"
        )
        #expect(
            assistant.imageAttachments.count == 1,
            "生成的图片应随助手消息落库，实际 \(assistant.imageAttachments.count)"
        )
        #expect(
            Data(base64Encoded: assistant.imageAttachments.first?.data ?? "") == generatedImagePNGBytes,
            "落库的图片内容应与模型返回的一致"
        )
        #expect(assistant.imageAttachments.first?.mimeType == "image/png")
    }
}
