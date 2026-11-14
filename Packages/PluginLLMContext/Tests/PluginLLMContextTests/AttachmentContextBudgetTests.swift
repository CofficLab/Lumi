import Foundation
import KitLLM
import ProviderConversation
import ProviderLLMContext
import ProviderLLMManager
import ProviderMessage
import Testing

@testable import PluginLLMContext

/// 文本附件必须计入上下文预算，并能被降级裁剪（回归 #814）。
///
/// 附件正文存在 `metadata["fileAttachments"]`，转换阶段才拼进真实请求。
/// 若估算只算短正文、降级只裁短正文，超大文本附件会让首次请求与紧急重试
/// 都发出同一份超限载荷，自动上下文恢复失效。
@MainActor
struct AttachmentContextBudgetTests {
    /// 约 1,096 token 输入上限：触发确定性降级且不依赖摘要 Provider。
    private static func request(conversationID: UUID) -> LLMContextPreparationRequest {
        LLMContextPreparationRequest(
            conversationID: conversationID,
            providerID: nil,
            model: nil,
            budget: LLMContextBudget(
                contextWindowTokens: 4_096,
                reservedOutputTokens: 2_000,
                safetyMarginTokens: 1_000
            ),
            mode: .beforeSend
        )
    }

    private static func makeProvider() -> (LLMContextProvider, DefaultMessageManager) {
        let messages = DefaultMessageManager()
        let provider = LLMContextProvider(
            messages: messages,
            conversations: DefaultConversationManager(),
            llmProvider: DefaultLLMManager()
        )
        return (provider, messages)
    }

    private static func attachmentMessage(
        conversationID: UUID,
        body: String,
        text: String
    ) -> Message {
        let file = UserFileAttachment(
            fileName: "big.txt",
            mimeType: "text/plain",
            textContent: text
        )
        return Message(
            conversationID: conversationID,
            role: .user,
            content: body,
            metadata: UserAttachmentMetadata.encodeFileAttachments([file])
        )
    }

    /// 转换阶段真正发给模型的正文。
    private func convertedContent(of message: Message) -> String {
        UserAttachmentMetadata.appendingFileAttachments(
            UserAttachmentMetadata.decodeFileAttachments(from: message.metadata),
            to: message.content
        )
    }

    @Test("估算必须覆盖文本附件正文，而不是只算短正文（#814）")
    func estimateIncludesTextAttachment() {
        let conversationID = UUID()
        let body = "hi"
        let message = Self.attachmentMessage(
            conversationID: conversationID,
            body: body,
            text: String(repeating: "a", count: 60_000)
        )

        let estimate = LLMContextTokenEstimator.estimate(message: message)
        let converted = convertedContent(of: message)
        // 估算与真实转换正文同量纲，且远大于只算正文的结果。
        #expect(estimate >= LLMContextTokenEstimator.estimate(text: converted))
        #expect(estimate > LLMContextTokenEstimator.estimate(text: body) + 1_000)
    }

    @Test("超大文本附件的紧急重试必须真正裁剪附件正文，不再原样超限（#814）")
    func emergencyFallbackTrimsOversizedTextAttachment() async {
        let (provider, messages) = Self.makeProvider()
        let conversationID = UUID()
        messages.insertMessage(
            Self.attachmentMessage(
                conversationID: conversationID,
                body: "hi",
                text: String(repeating: "a", count: 60_000)
            ),
            to: conversationID
        )

        let request = Self.request(conversationID: conversationID)
        // 模拟 provider 返回上下文超限：学习倍率并标记强制压缩。
        provider.reportContextLimitExceeded(for: request)
        let result = await provider.prepareContext(for: request)

        #expect(result.didFallback)
        #expect(!result.messages.isEmpty)
        // 真实转换后的载荷必须落在输入上限内：附件正文被裁剪，而不是原样拼回。
        for message in result.messages {
            let converted = convertedContent(of: message)
            #expect(LLMContextTokenEstimator.estimate(text: converted) <= result.inputTokenLimit)
        }
        #expect(result.estimatedInputTokens <= result.inputTokenLimit)
    }
}