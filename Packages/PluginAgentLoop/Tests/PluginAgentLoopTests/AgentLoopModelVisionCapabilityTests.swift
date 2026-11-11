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

/// 模型声明不支持视觉时，不得把图片发给它。
///
/// ## 为什么要有这条测试
///
/// `LLMModelInfo.supportsVision` 与 `supportsTools` 一样是**能力契约**，
/// 但此前只用于模型列表的展示（分类、图标、角标），请求构建链完全不读它。
///
/// 结果是：明确声明为纯文本的模型（内置的 `gpt-4` / `gpt-3.5-turbo` 等）
/// 仍然收到 base64 图片块——一个本地就能拦下的能力错误被推迟成供应商的
/// 协议失败，用户看到的是无意义的供应商报错。
@MainActor
@Suite("AgentLoop 按模型能力过滤图片")
struct AgentLoopModelVisionCapabilityTests {

    /// 记录收到的请求的 LLM 管理器替身。
    private final class VisionRecordingLLMManager: LLMManaging, LLMStreamingProviding, @unchecked Sendable {
        private let provider: VisionCapabilityProvider
        private(set) var requests: [LLMRequest] = []

        init(provider: VisionCapabilityProvider) {
            self.provider = provider
        }

        var providerID: String { Self.managerProviderID }
        var providerInfo: LLMProviderInfo {
            LLMProviderInfo(id: providerID, displayName: "Test Manager", defaultModel: "", models: [], isLocal: true)
        }

        func complete(_ request: LLMRequest) async throws -> LLMResponse {
            requests.append(request)
            return LLMResponse(content: "ok", model: request.model)
        }

        func streamComplete(
            _ request: LLMRequest,
            onChunk: @escaping @Sendable (LLMStreamChunk) async -> Void
        ) async throws -> LLMResponse {
            requests.append(request)
            return LLMResponse(content: "ok", model: request.model)
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

    /// 声明了视觉能力的供应商替身。
    private final class VisionCapabilityProvider: SuperLLMProvider {
        let providerInfo: LLMProviderInfo

        init(modelID: String, supportsVision: Bool) {
            providerInfo = LLMProviderInfo(
                id: "vision-capability-provider",
                displayName: "Vision Capability Provider",
                defaultModel: modelID,
                models: [LLMModelInfo(id: modelID, supportsVision: supportsVision)],
                isLocal: true
            )
        }

        var providerID: String { providerInfo.id }

        func complete(_ request: LLMRequest) async throws -> LLMResponse {
            LLMResponse(content: "ok", model: request.model)
        }
    }

    private func makeManager(
        llmManager: any LLMManaging,
        messages: DefaultMessageManager
    ) -> AgentLoopManager {
        AgentLoopManager(
            messages: messages,
            llmManager: llmManager,
            toolManager: DefaultToolManagerProviding(),
            streaming: DefaultMessageStreamingProviding(),
            conversations: DefaultConversationManager(),
            contextProvider: PassthroughLLMContextProvider(messages: messages)
        )
    }

    /// 写一条带图片附件的用户消息。
    private func insertUserMessageWithImage(
        into messages: DefaultMessageManager,
        conversationID: UUID
    ) throws {
        let attachment = UserImageAttachment(
            mimeType: "image/png",
            base64Data: Data([0x89, 0x50, 0x4E, 0x47]).base64EncodedString()
        )
        let message = Message(
            conversationID: conversationID,
            role: .user,
            content: "看这张图",
            metadata: UserAttachmentMetadata.encodeImageAttachments([attachment])
        )
        messages.insertMessage(message, to: conversationID)
    }

    // MARK: - Tests

    @Test("模型声明不支持视觉时请求不带图片")
    func requestOmitsImagesWhenModelDoesNotSupportVision() async throws {
        let provider = VisionCapabilityProvider(modelID: "text-only", supportsVision: false)
        let llmManager = VisionRecordingLLMManager(provider: provider)
        let messages = DefaultMessageManager()
        let manager = makeManager(llmManager: llmManager, messages: messages)
        let conversationID = UUID()
        try insertUserMessageWithImage(into: messages, conversationID: conversationID)

        try await manager.runTurn(in: conversationID)

        let request = try #require(llmManager.requests.first, "本轮应发出过一次 LLM 请求")
        #expect(
            request.messages.allSatisfy { $0.images.isEmpty },
            "不支持视觉的模型不应收到图片"
        )
    }

    @Test("模型声明支持视觉时请求保留图片")
    func requestKeepsImagesWhenModelSupportsVision() async throws {
        let provider = VisionCapabilityProvider(modelID: "vision-capable", supportsVision: true)
        let llmManager = VisionRecordingLLMManager(provider: provider)
        let messages = DefaultMessageManager()
        let manager = makeManager(llmManager: llmManager, messages: messages)
        let conversationID = UUID()
        try insertUserMessageWithImage(into: messages, conversationID: conversationID)

        try await manager.runTurn(in: conversationID)

        let request = try #require(llmManager.requests.first, "本轮应发出过一次 LLM 请求")
        #expect(
            request.messages.contains { !$0.images.isEmpty },
            "支持视觉的模型应正常收到图片"
        )
    }
}
