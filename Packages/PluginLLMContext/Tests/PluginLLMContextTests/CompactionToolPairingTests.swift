import Foundation
import ProviderConversation
import ProviderLLMContext
import ProviderLLMManager
import ProviderMessage
import Testing

@testable import PluginLLMContext

/// 压缩覆盖边界的 tool-call / tool-result 配对保护（回归 #812）。
///
/// 滚动摘要的覆盖水位可能恰好停在一条带 toolCalls 的 assistant 上，而它的工具
/// 结果落在逐字尾部开头。旧实现只在「尾部被预算截断（tailSourceIndex > 0）」时
/// 才做配对修复，尾部完整装下时孤儿工具结果被原样发出，provider 静默丢弃。
@MainActor
struct CompactionToolPairingTests {
    /// 约 1,096 token 输入上限：被覆盖的超大旧消息推过硬阈值，尾部却完整装下。
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

    private func makeDirectory() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("CompactionToolPairingTests-\(UUID().uuidString)", isDirectory: true)
    }

    /// 输出里任何 tool 结果都必须能在它之前找到携带同一 callID 的 assistant 调用。
    private func assertNoOrphanedToolResults(_ messages: [Message]) {
        for (index, message) in messages.enumerated() where message.role == .tool {
            let callID = message.toolCallID
            let paired = messages[..<index].contains { prior in
                prior.role == .assistant
                    && (prior.toolCalls ?? []).contains { $0.id == callID }
            }
            #expect(paired, "orphaned tool result: \(callID ?? "nil")")
        }
    }

    @Test("水位停在 assistant 声明上、尾部完整装下时，孤儿工具结果要补上声明（#812）")
    func compactionRepairsOrphanAtFullFitTailStart() async throws {
        let conversationID = UUID()
        let base = Date(timeIntervalSince1970: 1_000_000)
        let messages = DefaultMessageManager()

        let huge = Message(
            conversationID: conversationID,
            role: .user,
            content: String(repeating: "old", count: 20_000),
            createdAt: base
        )
        let assistant = Message(
            conversationID: conversationID,
            role: .assistant,
            content: "",
            createdAt: base.addingTimeInterval(1),
            toolCalls: [MessageToolCall(id: "call-1", name: "f", arguments: "{}")]
        )
        let tool = Message(
            conversationID: conversationID,
            role: .tool,
            content: "ok",
            createdAt: base.addingTimeInterval(2),
            toolCallID: "call-1"
        )
        let user = Message(
            conversationID: conversationID,
            role: .user,
            content: "continue",
            createdAt: base.addingTimeInterval(3)
        )
        for message in [huge, assistant, tool, user] {
            messages.insertMessage(message, to: conversationID)
        }

        // 块覆盖到 assistant 声明为止；工具结果落在逐字尾部开头。
        let store = try CompressionBlockStore(directory: makeDirectory())
        let block = CompressionBlock(
            conversationID: conversationID,
            tier: 1,
            summary: "摘要",
            sourceMessageIDs: [huge.id, assistant.id],
            coveredThroughMessageID: assistant.id,
            estimatedTokens: 10
        )
        try await store.save([block])

        let provider = LLMContextProvider(
            messages: messages,
            conversations: DefaultConversationManager(),
            llmProvider: DefaultLLMManager(),
            blockStore: store
        )

        let result = await provider.prepareContext(for: Self.request(conversationID: conversationID))

        #expect(result.didCompact)
        assertNoOrphanedToolResults(result.messages)
        #expect(result.messages.contains { $0.role == .tool && $0.toolCallID == "call-1" })
        #expect(result.messages.contains {
            $0.role == .assistant && ($0.toolCalls ?? []).contains { $0.id == "call-1" }
        })
        #expect(LLMContextTokenEstimator.estimate(messages: result.messages) <= result.inputTokenLimit)
    }

    @Test("水位后的孤儿工具结果找不到声明时直接丢弃，不得发出（#812）")
    func compactionDropsOrphanWithoutDeclaration() async throws {
        let conversationID = UUID()
        let base = Date(timeIntervalSince1970: 1_000_000)
        let messages = DefaultMessageManager()

        let huge = Message(
            conversationID: conversationID,
            role: .user,
            content: String(repeating: "old", count: 20_000),
            createdAt: base
        )
        // 水位是一条普通 user 消息，不携带任何 toolCalls。
        let watermark = Message(
            conversationID: conversationID,
            role: .user,
            content: "covered",
            createdAt: base.addingTimeInterval(1)
        )
        let orphanTool = Message(
            conversationID: conversationID,
            role: .tool,
            content: "ok",
            createdAt: base.addingTimeInterval(2),
            toolCallID: "call-missing"
        )
        let user = Message(
            conversationID: conversationID,
            role: .user,
            content: "continue",
            createdAt: base.addingTimeInterval(3)
        )
        for message in [huge, watermark, orphanTool, user] {
            messages.insertMessage(message, to: conversationID)
        }

        let store = try CompressionBlockStore(directory: makeDirectory())
        let block = CompressionBlock(
            conversationID: conversationID,
            tier: 1,
            summary: "摘要",
            sourceMessageIDs: [huge.id, watermark.id],
            coveredThroughMessageID: watermark.id,
            estimatedTokens: 10
        )
        try await store.save([block])

        let provider = LLMContextProvider(
            messages: messages,
            conversations: DefaultConversationManager(),
            llmProvider: DefaultLLMManager(),
            blockStore: store
        )

        let result = await provider.prepareContext(for: Self.request(conversationID: conversationID))

        #expect(result.didCompact)
        assertNoOrphanedToolResults(result.messages)
        #expect(!result.messages.contains { $0.role == .tool })
        #expect(result.messages.contains { $0.role == .user && $0.content == "continue" })
    }

    @Test("多工具调用的 assistant 超预算时，其全部工具结果一起丢弃，不留孤儿（#349）")
    func compactionDropsAllOrphanedResultsOfMultiToolCall() async throws {
        let conversationID = UUID()
        let base = Date(timeIntervalSince1970: 1_000_000)
        let messages = DefaultMessageManager()

        let huge = Message(
            conversationID: conversationID,
            role: .user,
            content: String(repeating: "old", count: 20_000),
            createdAt: base
        )
        let watermark = Message(
            conversationID: conversationID,
            role: .user,
            content: "covered",
            createdAt: base.addingTimeInterval(1)
        )
        // assistant 声明两个调用，参数超大装不下；两条结果都很短能装下。
        let assistant = Message(
            conversationID: conversationID,
            role: .assistant,
            content: "",
            createdAt: base.addingTimeInterval(2),
            toolCalls: [
                MessageToolCall(id: "call-a", name: "f", arguments: String(repeating: "a", count: 40_000)),
                MessageToolCall(id: "call-b", name: "g", arguments: String(repeating: "b", count: 40_000))
            ]
        )
        let resultA = Message(
            conversationID: conversationID,
            role: .tool,
            content: "ok",
            createdAt: base.addingTimeInterval(3),
            toolCallID: "call-a"
        )
        let resultB = Message(
            conversationID: conversationID,
            role: .tool,
            content: "ok",
            createdAt: base.addingTimeInterval(4),
            toolCallID: "call-b"
        )
        let user = Message(
            conversationID: conversationID,
            role: .user,
            content: "continue",
            createdAt: base.addingTimeInterval(5)
        )
        for message in [huge, watermark, assistant, resultA, resultB, user] {
            messages.insertMessage(message, to: conversationID)
        }

        let store = try CompressionBlockStore(directory: makeDirectory())
        let block = CompressionBlock(
            conversationID: conversationID,
            tier: 1,
            summary: "摘要",
            sourceMessageIDs: [huge.id, watermark.id],
            coveredThroughMessageID: watermark.id,
            estimatedTokens: 10
        )
        try await store.save([block])

        let provider = LLMContextProvider(
            messages: messages,
            conversations: DefaultConversationManager(),
            llmProvider: DefaultLLMManager(),
            blockStore: store
        )

        let result = await provider.prepareContext(for: Self.request(conversationID: conversationID))

        #expect(result.didCompact)
        assertNoOrphanedToolResults(result.messages)
        // 声明装不下，两条结果必须一起去掉，而不是只删第一条留下 call-b 孤儿。
        #expect(!result.messages.contains { $0.role == .tool })
        #expect(result.messages.contains { $0.role == .user && $0.content == "continue" })
        #expect(LLMContextTokenEstimator.estimate(messages: result.messages) <= result.inputTokenLimit)
    }

    @Test("多工具调用整组装得下时，声明与全部结果完整保留（#349）")
    func compactionKeepsWholeMultiToolGroupWhenAssistantFits() async throws {
        let conversationID = UUID()
        let base = Date(timeIntervalSince1970: 1_000_000)
        let messages = DefaultMessageManager()

        let huge = Message(
            conversationID: conversationID,
            role: .user,
            content: String(repeating: "old", count: 20_000),
            createdAt: base
        )
        let watermark = Message(
            conversationID: conversationID,
            role: .user,
            content: "covered",
            createdAt: base.addingTimeInterval(1)
        )
        let assistant = Message(
            conversationID: conversationID,
            role: .assistant,
            content: "",
            createdAt: base.addingTimeInterval(2),
            toolCalls: [
                MessageToolCall(id: "call-a", name: "f", arguments: "{}"),
                MessageToolCall(id: "call-b", name: "g", arguments: "{}")
            ]
        )
        let resultA = Message(
            conversationID: conversationID,
            role: .tool,
            content: "ok",
            createdAt: base.addingTimeInterval(3),
            toolCallID: "call-a"
        )
        let resultB = Message(
            conversationID: conversationID,
            role: .tool,
            content: "ok",
            createdAt: base.addingTimeInterval(4),
            toolCallID: "call-b"
        )
        let user = Message(
            conversationID: conversationID,
            role: .user,
            content: "continue",
            createdAt: base.addingTimeInterval(5)
        )
        for message in [huge, watermark, assistant, resultA, resultB, user] {
            messages.insertMessage(message, to: conversationID)
        }

        let store = try CompressionBlockStore(directory: makeDirectory())
        let block = CompressionBlock(
            conversationID: conversationID,
            tier: 1,
            summary: "摘要",
            sourceMessageIDs: [huge.id, watermark.id],
            coveredThroughMessageID: watermark.id,
            estimatedTokens: 10
        )
        try await store.save([block])

        let provider = LLMContextProvider(
            messages: messages,
            conversations: DefaultConversationManager(),
            llmProvider: DefaultLLMManager(),
            blockStore: store
        )

        let result = await provider.prepareContext(for: Self.request(conversationID: conversationID))

        #expect(result.didCompact)
        assertNoOrphanedToolResults(result.messages)
        #expect(result.messages.contains { $0.role == .tool && $0.toolCallID == "call-a" })
        #expect(result.messages.contains { $0.role == .tool && $0.toolCallID == "call-b" })
        #expect(result.messages.contains {
            $0.role == .assistant && ($0.toolCalls ?? []).count == 2
        })
        #expect(LLMContextTokenEstimator.estimate(messages: result.messages) <= result.inputTokenLimit)
    }
}