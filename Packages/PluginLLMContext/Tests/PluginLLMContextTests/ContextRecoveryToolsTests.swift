import Foundation
import KitAgentTool
import KitLLM
import ProviderConversation
import ProviderLLMContext
import ProviderLLMManager
import ProviderMessage
import Testing

@testable import PluginLLMContext

/// #1160 Phase C 恢复工具与删除清理的回归测试。
@MainActor
struct ContextRecoveryToolsTests {
    private func makeDirectory() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("ContextRecoveryToolsTests-\(UUID().uuidString)", isDirectory: true)
    }

    private func message(
        _ conversationID: UUID,
        id: UUID = UUID(),
        role: ProviderMessage.MessageRole = .user,
        content: String
    ) -> Message {
        Message(id: id, conversationID: conversationID, role: role, content: content)
    }

    private func makeProvider(
        messages: DefaultMessageManager,
        blockStore: CompressionBlockStore? = nil,
        summaryStore: ContextSummaryStore? = nil,
        ledger: AuxiliaryUsageLedger? = nil
    ) -> LLMContextProvider {
        LLMContextProvider(
            messages: messages,
            conversations: DefaultConversationManager(),
            llmProvider: DefaultLLMManager(),
            summaryStore: summaryStore,
            blockStore: blockStore,
            auxiliaryUsage: ledger
        )
    }

    private func context(_ conversationID: UUID) -> ToolExecutionContext {
        ToolExecutionContext(jobID: "job", conversationID: conversationID)
    }

    // MARK: - decompress_context

    @Test("tier-1 块沿血缘还原原始消息并写入文件，不改对话历史")
    func decompressTier1RestoresOriginals() async throws {
        let conversationID = UUID()
        let messages = DefaultMessageManager()
        let originals = (0 ..< 3).map { message(conversationID, content: "原始内容 \($0)") }
        originals.forEach { messages.insertMessage($0, to: conversationID) }

        let block = CompressionBlock(
            conversationID: conversationID,
            tier: 1,
            summary: "块摘要",
            sourceMessageIDs: originals.map(\.id),
            coveredThroughMessageID: originals[2].id,
            providerID: "p",
            modelName: "m",
            estimatedTokens: 10
        )
        let store = try CompressionBlockStore(directory: makeDirectory())
        try await store.save([block])
        let provider = makeProvider(messages: messages, blockStore: store)
        let directory = makeDirectory()
        let tool = DecompressContextTool(provider: provider, directory: directory)

        let result = try await tool.executeResult(
            context: context(conversationID),
            arguments: ["blockID": ToolArgument(block.id.uuidString)]
        )

        let fileURL = directory
            .appendingPathComponent(conversationID.uuidString, isDirectory: true)
            .appendingPathComponent("\(block.id.uuidString).md", isDirectory: false)
        #expect(FileManager.default.fileExists(atPath: fileURL.path))
        let written = try String(contentsOf: fileURL, encoding: .utf8)
        for original in originals {
            #expect(written.contains(original.content))
        }
        #expect(result.content.contains(fileURL.path))
        #expect(result.content.contains("Restored 3 original message(s)"))
        // 还原只写文件，绝不把原始消息塞回对话（保前缀缓存）。
        #expect(messages.messageCount(for: conversationID) == 3)
    }

    @Test("tier-2 块逐层回溯到全部原始消息")
    func decompressTier2TransitiveLineage() async throws {
        let conversationID = UUID()
        let messages = DefaultMessageManager()
        let originals = (0 ..< 4).map { message(conversationID, content: "原文 \($0)") }
        originals.forEach { messages.insertMessage($0, to: conversationID) }

        let lower1 = CompressionBlock(
            conversationID: conversationID, tier: 1, summary: "L1",
            sourceMessageIDs: [originals[0].id, originals[1].id],
            coveredThroughMessageID: originals[1].id, estimatedTokens: 10, active: false
        )
        let lower2 = CompressionBlock(
            conversationID: conversationID, tier: 1, summary: "L2",
            sourceMessageIDs: [originals[2].id, originals[3].id],
            coveredThroughMessageID: originals[3].id, estimatedTokens: 10, active: false
        )
        let upper = CompressionBlock(
            conversationID: conversationID, tier: 2, summary: "U",
            sourceBlockIDs: [lower1.id, lower2.id],
            coveredThroughMessageID: originals[3].id, estimatedTokens: 10
        )
        let store = try CompressionBlockStore(directory: makeDirectory())
        try await store.save([lower1, lower2, upper])
        let provider = makeProvider(messages: messages, blockStore: store)
        let tool = DecompressContextTool(provider: provider, directory: makeDirectory())

        let result = try await tool.executeResult(
            context: context(conversationID),
            arguments: ["blockID": ToolArgument(upper.id.uuidString)]
        )
        #expect(result.content.contains("Restored 4 original message(s)"))
    }

    @Test("迁移块无血缘时返回说明而非报错，也不写文件")
    func decompressLegacyBlockWithoutLineage() async throws {
        let conversationID = UUID()
        let messages = DefaultMessageManager()
        let block = CompressionBlock(
            conversationID: conversationID, tier: 1, summary: "旧版滚动摘要",
            sourceMessageIDs: [], coveredThroughMessageID: UUID(), estimatedTokens: 10
        )
        let store = try CompressionBlockStore(directory: makeDirectory())
        try await store.save([block])
        let provider = makeProvider(messages: messages, blockStore: store)
        let directory = makeDirectory()
        let tool = DecompressContextTool(provider: provider, directory: directory)

        let result = try await tool.executeResult(
            context: context(conversationID),
            arguments: ["blockID": ToolArgument(block.id.uuidString)]
        )
        #expect(result.content.contains("No Restorable Lineage"))
        #expect(result.content.contains("旧版滚动摘要"))
        #expect(!FileManager.default.fileExists(
            atPath: directory.appendingPathComponent(conversationID.uuidString).path
        ))
    }

    @Test("非法 blockID 抛出工具执行错误")
    func decompressInvalidBlockIDThrows() async throws {
        let provider = makeProvider(messages: DefaultMessageManager())
        let tool = DecompressContextTool(provider: provider, directory: makeDirectory())
        await #expect(throws: ToolExecutionError.self) {
            try await tool.executeResult(
                context: self.context(UUID()),
                arguments: ["blockID": ToolArgument("not-a-uuid")]
            )
        }
    }

    @Test("未知 blockID 抛出工具执行错误")
    func decompressUnknownBlockThrows() async throws {
        let conversationID = UUID()
        let provider = makeProvider(messages: DefaultMessageManager())
        let tool = DecompressContextTool(provider: provider, directory: makeDirectory())
        await #expect(throws: ToolExecutionError.self) {
            try await tool.executeResult(
                context: self.context(conversationID),
                arguments: ["blockID": ToolArgument(UUID().uuidString)]
            )
        }
    }

    @Test("缺少存储目录时解压明确报错")
    func decompressWithoutDirectoryThrows() async throws {
        let conversationID = UUID()
        let messages = DefaultMessageManager()
        let original = message(conversationID, content: "原文")
        messages.insertMessage(original, to: conversationID)
        let block = CompressionBlock(
            conversationID: conversationID, tier: 1, summary: "s",
            sourceMessageIDs: [original.id], coveredThroughMessageID: original.id, estimatedTokens: 10
        )
        let store = try CompressionBlockStore(directory: makeDirectory())
        try await store.save([block])
        let provider = makeProvider(messages: messages, blockStore: store)
        let tool = DecompressContextTool(provider: provider, directory: nil)
        await #expect(throws: ToolExecutionError.self) {
            try await tool.executeResult(
                context: self.context(conversationID),
                arguments: ["blockID": ToolArgument(block.id.uuidString)]
            )
        }
    }

    // MARK: - search_context

    @Test("搜索同时命中块摘要与原始消息并返回 ID")
    func searchFindsSummariesAndMessages() async throws {
        let conversationID = UUID()
        let messages = DefaultMessageManager()
        let hit = message(conversationID, content: "这里有一个 needle 关键词")
        let miss = message(conversationID, content: "无关内容")
        messages.insertMessage(hit, to: conversationID)
        messages.insertMessage(miss, to: conversationID)
        let block = CompressionBlock(
            conversationID: conversationID, tier: 1, summary: "摘要里也提到 needle",
            sourceMessageIDs: [hit.id], coveredThroughMessageID: hit.id, estimatedTokens: 10
        )
        let store = try CompressionBlockStore(directory: makeDirectory())
        try await store.save([block])
        let provider = makeProvider(messages: messages, blockStore: store)
        let tool = SearchContextTool(provider: provider)

        let result = try await tool.executeResult(
            context: context(conversationID),
            arguments: ["query": ToolArgument("needle")]
        )
        #expect(result.content.contains(block.id.uuidString))
        #expect(result.content.contains(hit.id.uuidString))
        #expect(!result.content.contains(miss.id.uuidString))
    }

    @Test("scope 限定只搜摘要或只搜消息")
    func searchScopeFilters() async throws {
        let conversationID = UUID()
        let messages = DefaultMessageManager()
        let hit = message(conversationID, content: "needle 在消息里")
        messages.insertMessage(hit, to: conversationID)
        let block = CompressionBlock(
            conversationID: conversationID, tier: 1, summary: "needle 在摘要里",
            coveredThroughMessageID: hit.id, estimatedTokens: 10
        )
        let store = try CompressionBlockStore(directory: makeDirectory())
        try await store.save([block])
        let provider = makeProvider(messages: messages, blockStore: store)
        let tool = SearchContextTool(provider: provider)

        let summaries = try await tool.executeResult(
            context: context(conversationID),
            arguments: ["query": ToolArgument("needle"), "scope": ToolArgument("summaries")]
        )
        #expect(summaries.content.contains(block.id.uuidString))
        #expect(!summaries.content.contains(hit.id.uuidString))

        let onlyMessages = try await tool.executeResult(
            context: context(conversationID),
            arguments: ["query": ToolArgument("needle"), "scope": ToolArgument("messages")]
        )
        #expect(onlyMessages.content.contains(hit.id.uuidString))
        #expect(!onlyMessages.content.contains(block.id.uuidString))
    }

    @Test("limit 钳制命中数量")
    func searchLimitClamps() async throws {
        let conversationID = UUID()
        let messages = DefaultMessageManager()
        for index in 0 ..< 5 {
            messages.insertMessage(message(conversationID, content: "needle \(index)"), to: conversationID)
        }
        let provider = makeProvider(messages: messages)
        let tool = SearchContextTool(provider: provider)
        let result = try await tool.executeResult(
            context: context(conversationID),
            arguments: ["query": ToolArgument("needle"), "scope": ToolArgument("messages"), "limit": ToolArgument(1)]
        )
        #expect(result.content.contains("1 match(es)"))
    }

    @Test("空查询抛出工具执行错误")
    func searchEmptyQueryThrows() async throws {
        let provider = makeProvider(messages: DefaultMessageManager())
        let tool = SearchContextTool(provider: provider)
        await #expect(throws: ToolExecutionError.self) {
            try await tool.executeResult(
                context: self.context(UUID()),
                arguments: ["query": ToolArgument("   ")]
            )
        }
    }

    @Test("无命中时返回友好提示")
    func searchNoMatches() async throws {
        let conversationID = UUID()
        let messages = DefaultMessageManager()
        messages.insertMessage(message(conversationID, content: "无关"), to: conversationID)
        let provider = makeProvider(messages: messages)
        let tool = SearchContextTool(provider: provider)
        let result = try await tool.executeResult(
            context: context(conversationID),
            arguments: ["query": ToolArgument("不存在")]
        )
        #expect(result.content.contains("No matches"))
    }

    // MARK: - context_status

    @Test("组成报告含分层块数、覆盖水位与幕后压缩开销")
    func statusReportsComposition() async throws {
        let conversationID = UUID()
        let messages = DefaultMessageManager()
        let originals = (0 ..< 20).map { message(conversationID, content: "消息 \($0)") }
        originals.forEach { messages.insertMessage($0, to: conversationID) }
        let block1 = CompressionBlock(
            conversationID: conversationID, tier: 1, summary: "A",
            sourceMessageIDs: [originals[0].id], coveredThroughMessageID: originals[2].id,
            estimatedTokens: 10
        )
        let block2 = CompressionBlock(
            conversationID: conversationID, tier: 1, summary: "B",
            sourceMessageIDs: [originals[3].id], coveredThroughMessageID: originals[5].id,
            estimatedTokens: 12
        )
        let store = try CompressionBlockStore(directory: makeDirectory())
        try await store.save([block1, block2])
        let ledger = AuxiliaryUsageLedger()
        await ledger.record(LLMAuxiliaryUsageEntry(
            conversationID: conversationID, purpose: .compaction,
            providerID: "p", modelName: "m",
            inputTokenCount: 100, outputTokenCount: 50, isEstimated: false
        ))
        let provider = makeProvider(messages: messages, blockStore: store, ledger: ledger)
        let tool = ContextStatusTool(provider: provider)

        let result = try await tool.executeResult(context: context(conversationID), arguments: [:])
        #expect(result.content.contains("tier 1: 2 block(s)"))
        #expect(result.content.contains("Coverage watermark: \(originals[5].id.uuidString)"))
        #expect(result.content.contains("6 message(s) folded"))
        #expect(result.content.contains("Verbatim recent zone: last 16 message(s)"))
        #expect(result.content.contains("Calls: 1"))
        #expect(result.content.contains("Spent: 150 token(s)"))
    }

    @Test("无块时报告说明尚未折叠")
    func statusWithoutBlocks() async throws {
        let conversationID = UUID()
        let messages = DefaultMessageManager()
        messages.insertMessage(message(conversationID, content: "你好"), to: conversationID)
        let provider = makeProvider(messages: messages)
        let tool = ContextStatusTool(provider: provider)
        let result = try await tool.executeResult(context: context(conversationID), arguments: [:])
        #expect(result.content.contains("no compression blocks yet"))
        #expect(result.content.contains("Coverage watermark: none"))
    }

    // MARK: - #350 deletion cleanup

    @Test("purgeConversation 清空内存与磁盘块")
    func purgeRemovesBlocks() async throws {
        let conversationID = UUID()
        let messages = DefaultMessageManager()
        let block = CompressionBlock(
            conversationID: conversationID, tier: 1, summary: "s",
            coveredThroughMessageID: UUID(), estimatedTokens: 10
        )
        let store = try CompressionBlockStore(directory: makeDirectory())
        try await store.save([block])
        let provider = makeProvider(messages: messages, blockStore: store)
        // 先加载进内存，再清理。
        #expect(await provider.compressionBlocks(for: conversationID).count == 1)

        await provider.purgeConversation(conversationID)

        #expect(try await store.load(conversationID: conversationID).isEmpty)
        #expect(await provider.compressionBlocks(for: conversationID).isEmpty)
    }

    @Test("账本 remove 清空某会话幕后用量")
    func ledgerRemoveClearsEntries() async throws {
        let conversationID = UUID()
        let ledger = AuxiliaryUsageLedger()
        await ledger.record(LLMAuxiliaryUsageEntry(
            conversationID: conversationID, purpose: .compaction,
            providerID: "p", modelName: "m",
            inputTokenCount: 10, outputTokenCount: 5, isEstimated: false
        ))
        #expect(await ledger.entries(for: conversationID).count == 1)
        await ledger.remove(conversationID: conversationID)
        #expect(await ledger.entries(for: conversationID).isEmpty)
    }

    @Test("会话删除事件触发压缩数据清理")
    func deletionObserverCleansUp() async throws {
        let conversations = DefaultConversationManager()
        let conversationID = try conversations.createConversation(
            title: nil, projectPath: nil, providerID: nil, modelName: nil
        )
        let messages = DefaultMessageManager()
        let block = CompressionBlock(
            conversationID: conversationID, tier: 1, summary: "s",
            coveredThroughMessageID: UUID(), estimatedTokens: 10
        )
        let store = try CompressionBlockStore(directory: makeDirectory())
        try await store.save([block])
        let ledger = AuxiliaryUsageLedger()
        await ledger.record(LLMAuxiliaryUsageEntry(
            conversationID: conversationID, purpose: .compaction,
            providerID: "p", modelName: "m",
            inputTokenCount: 10, outputTokenCount: 5, isEstimated: false
        ))
        let provider = LLMContextProvider(
            messages: messages, conversations: conversations,
            llmProvider: DefaultLLMManager(), blockStore: store, auxiliaryUsage: ledger
        )
        let observer = LLMContextConversationDeletionObserver(conversations: conversations) {
            [weak provider, weak ledger] id in
            await provider?.purgeConversation(id)
            await ledger?.remove(conversationID: id)
        }

        conversations.deleteConversation(id: conversationID)
        await observer.waitForPendingDeletion()

        #expect(try await store.load(conversationID: conversationID).isEmpty)
        #expect(await ledger.entries(for: conversationID).isEmpty)
        observer.cancel()
    }

    // MARK: - doctrine refusal

    @Test("摘要模型拒绝折叠时不产出块，历史走确定性降级")
    func doctrineRefusalSkipsBlock() async throws {
        let conversationID = UUID()
        let messages = DefaultMessageManager()
        for index in 0 ..< 100 {
            messages.insertMessage(
                message(conversationID, content: String(repeating: "逐字关键内容 ", count: 60) + "\(index)"),
                to: conversationID
            )
        }
        let llm = DefaultLLMManager()
        let refusing = RefusingSummaryProvider()
        try llm.register(refusing)
        llm.select(providerID: refusing.providerID, model: "summary-model", reason: .userSelected)
        let store = try CompressionBlockStore(directory: makeDirectory())
        let provider = LLMContextProvider(
            messages: messages, conversations: DefaultConversationManager(),
            llmProvider: llm, blockStore: store
        )
        let request = LLMContextPreparationRequest(
            conversationID: conversationID,
            providerID: refusing.providerID,
            model: "summary-model",
            budget: LLMContextBudget(contextWindowTokens: 5_000, reservedOutputTokens: 500, safetyMarginTokens: 500),
            mode: .beforeSend
        )

        let result = await provider.prepareContext(for: request)

        #expect(refusing.completeCalls >= 1)
        #expect(try await store.load(conversationID: conversationID).isEmpty)
        #expect(!result.didCompact)
        #expect(result.didFallback)
    }

    @Test("教义包含中途拒绝条款与防注入措辞")
    func doctrineContainsRefusalClause() {
        #expect(LLMContextProvider.summarySystemPrompt.contains(LLMContextProvider.compressionRefusalSentinel))
        #expect(LLMContextProvider.summarySystemPrompt.contains("refuse to compress mid-task"))
        #expect(LLMContextProvider.summarySystemPrompt.contains("untrusted data"))
    }
}

/// 始终拒绝折叠的摘要模型替身。
private final class RefusingSummaryProvider: SuperLLMProvider {
    let providerInfo = LLMProviderInfo(
        id: "refusing-test-provider",
        displayName: "Refusing Test Provider",
        defaultModel: "summary-model",
        models: [LLMModelInfo(id: "summary-model", contextWindowSize: 20_000)]
    )
    private(set) var completeCalls = 0
    var providerID: String { providerInfo.id }

    func complete(_ request: LLMRequest) async throws -> LLMResponse {
        completeCalls += 1
        return LLMResponse(content: LLMContextProvider.compressionRefusalSentinel, model: request.model)
    }
}