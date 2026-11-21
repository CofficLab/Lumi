import Foundation
import ProviderMessage
import Testing
@testable import PluginMessageManager

/// #287：Anthropic thinking 签名必须落库并在 LLM 上下文读取时还原。
///
/// 签名与思考文本配对：下一轮请求重建 thinking 块时必须原样回传，
/// 否则带工具调用的历史会被供应商拒绝。链路上任何一环丢字段——
/// SwiftData 模型、`toMessage()` / `toLLMContextMessage()` 转换、
/// `fetchMessagesForLLMContext` 的原生 SQL 窄读取——都会让重启后的
/// 第二轮请求静默 400。
@Suite("MessageStore thinking 签名持久化（#287）")
struct MessageStoreThinkingSignatureTests {

    private func makeStore() throws -> (store: MessageStore, directory: URL) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MessageStoreSignature-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let store = try MessageStore(databaseRootURL: directory)
        return (store, directory)
    }

    @Test("MessageModel 往返保留 thinking 签名")
    func messageModelRoundTripPreservesSignature() {
        let message = Message(
            conversationID: UUID(),
            role: .assistant,
            content: "答案",
            reasoningContent: "先分析上下文",
            thinkingSignature: "sig-abc123"
        )

        let model = MessageModel.from(message: message)
        #expect(model.thinkingSignature == "sig-abc123")

        let restored = try! #require(model.toMessage())
        #expect(restored.reasoningContent == "先分析上下文")
        #expect(restored.thinkingSignature == "sig-abc123")

        let llmContext = try! #require(model.toLLMContextMessage())
        #expect(llmContext.thinkingSignature == "sig-abc123")
    }

    @Test("LLM 上下文窄读取还原 thinking 签名")
    func llmContextFetchRestoresSignature() throws {
        let (store, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }

        let conversationID = UUID()
        _ = try store.insertMessage(Message(
            conversationID: conversationID,
            role: .assistant,
            content: "答案",
            reasoningContent: "先分析上下文",
            thinkingSignature: "sig-abc123"
        ))

        let messages = store.fetchMessagesForLLMContext(conversationId: conversationID)
        let assistant = try #require(messages.first)
        #expect(assistant.reasoningContent == "先分析上下文")
        #expect(
            assistant.thinkingSignature == "sig-abc123",
            "原生 SQL 窄读取漏掉 ZTHINKINGSIGNATURE 列的话，重启后下一轮请求就会因签名缺失被拒"
        )
    }

    @Test("无签名消息读取结果保持 nil")
    func messageWithoutSignatureStaysNil() throws {
        let (store, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }

        let conversationID = UUID()
        _ = try store.insertMessage(Message(
            conversationID: conversationID,
            role: .assistant,
            content: "普通回复"
        ))

        let messages = store.fetchMessagesForLLMContext(conversationId: conversationID)
        let assistant = try #require(messages.first)
        #expect(assistant.thinkingSignature == nil)
    }
}
