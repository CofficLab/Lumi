import Foundation
import KitLLM
import ProviderConversation
import ProviderLLMContext
import ProviderLLMManager
import ProviderMessage
import Testing

@testable import PluginLLMContext

@MainActor
struct LLMContextPluginTests {
    @Test("时间线消息只展示给用户，不进入 LLM 历史")
    func timelineMessagesAreExcludedFromLLMHistory() async {
        let messages = DefaultMessageManager()
        let conversations = DefaultConversationManager()
        let llm = DefaultLLMManager()
        let provider = LLMContextProvider(
            messages: messages,
            conversations: conversations,
            llmProvider: llm
        )
        let conversationID = UUID()
        let retryTimeline = Message(
            conversationID: conversationID,
            role: .status,
            content: "正在重试",
            metadata: [MessageTimelineEvent.metadataKey: MessageTimelineEvent.agentLoopRetry],
            renderKind: MessageTimelineEvent.agentLoopRetryRenderKind
        )

        messages.insertMessage(
            Message(conversationID: conversationID, role: .user, content: "你好"),
            to: conversationID
        )
        messages.insertMessage(retryTimeline, to: conversationID)

        let result = await provider.messagesForLLM(in: conversationID)

        #expect(result.count == 1)
        #expect(result.first?.role == .user)
        #expect(result.first?.content == "你好")
    }

    @Test("短会话透传完整历史")
    func shortConversationUsesFullHistory() async {
        let messages = DefaultMessageManager()
        let conversations = DefaultConversationManager()
        let llm = DefaultLLMManager()
        let provider = LLMContextProvider(
            messages: messages,
            conversations: conversations,
            llmProvider: llm
        )
        let conversationID = UUID()

        messages.insertMessage(
            Message(conversationID: conversationID, role: .user, content: "你好"),
            to: conversationID
        )

        let result = await provider.messagesForLLM(in: conversationID)

        #expect(result.count == 1)
        #expect(result[0].content == "你好")
    }

    @Test("工具栏统计复用 LLMContext 请求的估算和预算")
    func contextWindowUsageMatchesPreparedRequest() async throws {
        let messages = DefaultMessageManager()
        let conversations = DefaultConversationManager()
        let llm = DefaultLLMManager()
        let summaryProvider = SummaryLLMProvider(contextWindowTokens: 24_000)
        try llm.register(summaryProvider)
        llm.select(providerID: summaryProvider.providerID, model: "summary-model", reason: .userSelected)

        let provider = LLMContextProvider(
            messages: messages,
            conversations: conversations,
            llmProvider: llm
        )
        let conversationID = UUID()
        let request = LLMContextPreparationRequest(
            conversationID: conversationID,
            providerID: summaryProvider.providerID,
            model: "summary-model",
            budget: LLMContextBudget(
                contextWindowTokens: 24_000,
                reservedOutputTokens: 2_000,
                toolSchemaTokens: 400,
                safetyMarginTokens: 1_000
            )
        )
        messages.insertMessage(
            Message(conversationID: conversationID, role: .user, content: "第一条消息"),
            to: conversationID
        )

        let prepared = await provider.prepareContext(for: request)
        let initialUsage = await provider.contextWindowUsage(for: conversationID)

        #expect(initialUsage?.contextWindowTokens == 24_000)
        #expect(initialUsage?.inputTokenLimit == prepared.inputTokenLimit)
        #expect(initialUsage?.estimatedInputTokens == prepared.estimatedInputTokens)

        messages.insertMessage(
            Message(conversationID: conversationID, role: .user, content: "第二条消息"),
            to: conversationID
        )
        let updatedUsage = await provider.contextWindowUsage(for: conversationID)
        #expect((updatedUsage?.estimatedInputTokens ?? 0) > (initialUsage?.estimatedInputTokens ?? 0))
    }

    @Test("摘要生成失败时不阻塞，继续返回完整历史")
    func summaryFailureFallsBackToFullHistory() async {
        let messages = DefaultMessageManager()
        let conversations = DefaultConversationManager()
        let llm = DefaultLLMManager()
        let provider = LLMContextProvider(
            messages: messages,
            conversations: conversations,
            llmProvider: llm
        )
        let conversationID = UUID()

        for index in 0..<LLMContextProvider.compactionMessageThreshold + 1 {
            messages.insertMessage(
                Message(conversationID: conversationID, role: .user, content: "消息 \(index)"),
                to: conversationID
            )
        }

        let result = await provider.messagesForLLM(in: conversationID)

        #expect(result.count == LLMContextProvider.compactionMessageThreshold + 1)
    }

    @Test("生成摘要时使用防提示注入的摘要指令")
    func summaryPromptTreatsConversationAsData() {
        #expect(LLMContextProvider.summarySystemPrompt.contains("untrusted data"))
        #expect(LLMContextProvider.summarySystemPrompt.contains("Do not invent facts"))
    }

    @Test("后台生成摘要后返回摘要和最近消息")
    func backgroundSummaryCompactsHistory() async throws {
        let messages = DefaultMessageManager()
        let conversations = DefaultConversationManager()
        let llm = DefaultLLMManager()
        let summaryProvider = SummaryLLMProvider()
        try llm.register(summaryProvider)
        llm.select(providerID: summaryProvider.providerID, model: "summary-model", reason: .userSelected)

        let provider = LLMContextProvider(
            messages: messages,
            conversations: conversations,
            llmProvider: llm
        )
        let conversationID = UUID()
        for index in 0...LLMContextProvider.compactionMessageThreshold {
            messages.insertMessage(
                Message(
                    conversationID: conversationID,
                    role: .user,
                    content: String(repeating: "历史内容 ", count: 100) + "\(index)"
                ),
                to: conversationID
            )
        }

        // 第一次请求不等待摘要，触发后台刷新。
        let initial = await provider.messagesForLLM(in: conversationID)
        #expect(initial.count == LLMContextProvider.compactionMessageThreshold + 1)
        #expect(!messages.messages(for: conversationID).contains {
            MessageTimelineEvent.isActualContextCompaction($0)
        })

        for _ in 0..<12 {
            try await Task.sleep(nanoseconds: 100_000_000)
            if summaryProvider.completeCalls == 1 {
                let request = LLMContextPreparationRequest(
                    conversationID: conversationID,
                    providerID: summaryProvider.providerID,
                    model: "summary-model",
                    budget: LLMContextBudget(
                        contextWindowTokens: 5_000,
                        reservedOutputTokens: 500,
                        safetyMarginTokens: 500
                    ),
                    mode: .beforeSend
                )
                let compacted = await provider.prepareContext(for: request)
                #expect(compacted.didCompact)
                #expect(compacted.messages.contains { $0.metadata["llmContext"] == "summary" })
                #expect(messages.messages(for: conversationID).contains {
                    MessageTimelineEvent.isActualContextCompaction($0)
                })
                let event = messages.messages(for: conversationID).first {
                    MessageTimelineEvent.isActualContextCompaction($0)
                }
                #expect(event?.providerID == summaryProvider.providerID)
                #expect(event?.modelName == "summary-model")
                #expect(event?.metadata[MessageTimelineEvent.contextCompactionReasonKey] == "hard-threshold")
                #expect(event?.metadata[MessageTimelineEvent.contextCompactionContextWindowTokensKey] == "5000")
                #expect(!messages.messages(for: conversationID).contains {
                    MessageTimelineEvent.isContextCompaction($0)
                        && !MessageTimelineEvent.isActualContextCompaction($0)
                })
                #expect(summaryProvider.completeCalls == 1)
                return
            }
        }

        #expect(Bool(false), "后台摘要未在测试窗口内生成")
    }

    @Test("后台摘要沿用对话模型 ID，不会误路由到同名全局模型")
    func backgroundSummaryUsesConversationModelID() async throws {
        let messages = DefaultMessageManager()
        let conversations = DefaultConversationManager()
        let llm = DefaultLLMManager()
        let globalProvider = SummaryLLMProvider(id: "global-summary-provider")
        let conversationProvider = SummaryLLMProvider(id: "conversation-summary-provider")
        try llm.register(globalProvider)
        try llm.register(conversationProvider)
        llm.select(providerID: globalProvider.providerID, model: "summary-model", reason: .userSelected)

        let conversationID = try conversations.createConversation(
            title: nil,
            projectPath: nil,
            providerID: nil,
            modelName: nil
        )
        let conversationModelID = try #require(
            llm.modelID(providerID: conversationProvider.providerID, model: "summary-model")
        )
        conversations.selectModel(id: conversationModelID.rawValue, for: conversationID)

        let provider = LLMContextProvider(
            messages: messages,
            conversations: conversations,
            llmProvider: llm
        )
        for index in 0...LLMContextProvider.compactionMessageThreshold {
            messages.insertMessage(
                Message(
                    conversationID: conversationID,
                    role: .user,
                    content: String(repeating: "按对话模型生成摘要 ", count: 100) + "\(index)"
                ),
                to: conversationID
            )
        }

        _ = await provider.messagesForLLM(in: conversationID)
        for _ in 0..<12 {
            if conversationProvider.completeCalls > 0 { break }
            try await Task.sleep(nanoseconds: 100_000_000)
        }

        #expect(conversationProvider.completeCalls == 1)
        #expect(globalProvider.completeCalls == 0)
    }

    @Test("硬阈值请求会在发送前等待摘要")
    func hardBudgetWaitsForCompaction() async {
        let messages = DefaultMessageManager()
        let conversations = DefaultConversationManager()
        let llm = DefaultLLMManager()
        let summaryProvider = SummaryLLMProvider()
        try? llm.register(summaryProvider)
        llm.select(providerID: summaryProvider.providerID, model: "summary-model", reason: .userSelected)

        let provider = LLMContextProvider(
            messages: messages,
            conversations: conversations,
            llmProvider: llm
        )
        let conversationID = UUID()
        for index in 0..<60 {
            messages.insertMessage(
                Message(
                    conversationID: conversationID,
                    role: .user,
                    content: String(repeating: "长对话内容 ", count: 600) + "\(index)"
                ),
                to: conversationID
            )
        }

        let request = LLMContextPreparationRequest(
            conversationID: conversationID,
            providerID: summaryProvider.providerID,
            model: "summary-model",
            budget: LLMContextBudget(
                contextWindowTokens: 20_000,
                reservedOutputTokens: 2_000,
                safetyMarginTokens: 1_000
            ),
            mode: .beforeSend
        )
        let result = await provider.prepareContext(for: request)

        #expect(result.didCompact)
        #expect(!result.didFallback)
        #expect(result.estimatedInputTokens <= result.inputTokenLimit)
        #expect(result.messages.contains { $0.metadata["llmContext"] == "summary" })
        #expect(messages.messages(for: conversationID).contains {
            MessageTimelineEvent.isActualContextCompaction($0)
        })
        let event = messages.messages(for: conversationID).first {
            MessageTimelineEvent.isActualContextCompaction($0)
        }
        #expect(event?.providerID == summaryProvider.providerID)
        #expect(event?.modelName == "summary-model")
        #expect(event?.metadata[MessageTimelineEvent.contextCompactionReasonKey] == "hard-threshold")
        #expect(event?.metadata[MessageTimelineEvent.contextCompactionContextWindowTokensKey] == "20000")
    }

    @Test("软阈值只预热，不记录实际压缩")
    func softThresholdOnlyPrewarms() async throws {
        let messages = DefaultMessageManager()
        let conversations = DefaultConversationManager()
        let llm = DefaultLLMManager()
        let summaryProvider = SummaryLLMProvider()
        try llm.register(summaryProvider)
        llm.select(providerID: summaryProvider.providerID, model: "summary-model", reason: .userSelected)

        let provider = LLMContextProvider(
            messages: messages,
            conversations: conversations,
            llmProvider: llm
        )
        let conversationID = UUID()
        for index in 0..<17 {
            messages.insertMessage(
                Message(
                    conversationID: conversationID,
                    role: .user,
                    content: String(repeating: "短内容 ", count: 150) + "\(index)"
                ),
                to: conversationID
            )
        }

        let prewarmRequest = LLMContextPreparationRequest(
            conversationID: conversationID,
            providerID: summaryProvider.providerID,
            model: "summary-model",
            budget: LLMContextBudget(
                contextWindowTokens: 15_000,
                reservedOutputTokens: 2_000,
                safetyMarginTokens: 1_000
            ),
            mode: .prewarm
        )
        _ = await provider.prepareContext(for: prewarmRequest)

        for _ in 0..<12 {
            try await Task.sleep(nanoseconds: 100_000_000)
            if summaryProvider.completeCalls == 1 { break }
        }
        #expect(summaryProvider.completeCalls == 1)

        let beforeSendRequest = LLMContextPreparationRequest(
            conversationID: conversationID,
            providerID: summaryProvider.providerID,
            model: "summary-model",
            budget: prewarmRequest.budget,
            mode: .beforeSend
        )
        let result = await provider.prepareContext(for: beforeSendRequest)

        #expect(!result.didCompact)
        #expect(!messages.messages(for: conversationID).contains {
            MessageTimelineEvent.isActualContextCompaction($0)
        })
    }

    @Test("工具 schema usage 不会放大后续消息上下文估算")
    func toolSchemaUsageDoesNotInflateMessageCalibration() async {
        let messages = DefaultMessageManager()
        let conversations = DefaultConversationManager()
        let llm = DefaultLLMManager()
        let provider = LLMContextProvider(
            messages: messages,
            conversations: conversations,
            llmProvider: llm
        )
        let conversationID = UUID()
        let toolSchemaTokens = 100_000
        let request = LLMContextPreparationRequest(
            conversationID: conversationID,
            providerID: "calibration-provider",
            model: "calibration-model",
            budget: LLMContextBudget(
                contextWindowTokens: 1_000_000,
                reservedOutputTokens: 8_000,
                toolSchemaTokens: toolSchemaTokens,
                safetyMarginTokens: 2_000
            )
        )
        messages.insertMessage(
            Message(
                conversationID: conversationID,
                role: .user,
                content: String(repeating: "x", count: 30_000)
            ),
            to: conversationID
        )

        let first = await provider.prepareContext(for: request)
        provider.reportInputUsage(
            first.estimatedInputTokens + toolSchemaTokens,
            for: request,
            estimatedInputTokens: first.estimatedInputTokens
        )
        let next = await provider.prepareContext(for: request)

        #expect(next.estimatedInputTokens == first.estimatedInputTokens)
    }

    @Test("成功请求会逐步修正过高的历史校准倍率")
    func successfulUsageReducesInflatedCalibration() async {
        let messages = DefaultMessageManager()
        let conversations = DefaultConversationManager()
        let llm = DefaultLLMManager()
        let provider = LLMContextProvider(
            messages: messages,
            conversations: conversations,
            llmProvider: llm
        )
        let conversationID = UUID()
        let request = LLMContextPreparationRequest(
            conversationID: conversationID,
            providerID: "calibration-provider",
            model: "calibration-model",
            budget: LLMContextBudget(
                contextWindowTokens: 1_000_000,
                reservedOutputTokens: 8_000,
                safetyMarginTokens: 2_000
            )
        )
        messages.insertMessage(
            Message(
                conversationID: conversationID,
                role: .user,
                content: String(repeating: "x", count: 30_000)
            ),
            to: conversationID
        )

        let baseline = await provider.prepareContext(for: request)
        provider.reportInputUsage(
            baseline.estimatedInputTokens * 4,
            for: request,
            estimatedInputTokens: baseline.estimatedInputTokens
        )
        let inflated = await provider.prepareContext(for: request)
        provider.reportInputUsage(
            baseline.estimatedInputTokens,
            for: request,
            estimatedInputTokens: inflated.estimatedInputTokens
        )
        let recovered = await provider.prepareContext(for: request)

        #expect(inflated.estimatedInputTokens == baseline.estimatedInputTokens * 4)
        #expect(recovered.estimatedInputTokens < inflated.estimatedInputTokens)
        #expect(recovered.estimatedInputTokens > baseline.estimatedInputTokens)
    }

    @Test("超过原先消息上限后仍能滚动生成摘要")
    func rollingSummaryContinuesPastLegacyMessageLimit() async throws {
        let messages = DefaultMessageManager()
        let conversations = DefaultConversationManager()
        let llm = DefaultLLMManager()
        let summaryProvider = SummaryLLMProvider()
        try llm.register(summaryProvider)
        llm.select(providerID: summaryProvider.providerID, model: "summary-model", reason: .userSelected)

        let provider = LLMContextProvider(
            messages: messages,
            conversations: conversations,
            llmProvider: llm
        )
        let conversationID = UUID()
        for index in 0..<130 {
            messages.insertMessage(
                Message(
                    conversationID: conversationID,
                    role: .user,
                    content: String(repeating: "滚动摘要内容 ", count: 400) + "\(index)"
                ),
                to: conversationID
            )
        }

        let request = LLMContextPreparationRequest(
            conversationID: conversationID,
            providerID: summaryProvider.providerID,
            model: "summary-model",
            budget: LLMContextBudget(
                contextWindowTokens: 20_000,
                reservedOutputTokens: 2_000,
                safetyMarginTokens: 1_000
            ),
            mode: .beforeSend
        )

        _ = await provider.prepareContext(for: request)
        for _ in 0..<20 {
            try await Task.sleep(nanoseconds: 100_000_000)
            _ = await provider.prepareContext(for: request)
            if summaryProvider.completeCalls >= 2 {
                #expect(summaryProvider.completeCalls >= 2)
                return
            }
        }

        #expect(Bool(false), "滚动摘要未继续推进")
    }

    @Test("重新创建 Provider 后复用磁盘压缩块")
    func persistedSummarySurvivesProviderRecreation() async throws {
        let messages = DefaultMessageManager()
        let conversations = DefaultConversationManager()
        let llm = DefaultLLMManager()
        let summaryProvider = SummaryLLMProvider()
        try llm.register(summaryProvider)
        llm.select(providerID: summaryProvider.providerID, model: "summary-model", reason: .userSelected)

        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("LLMContextStoreTests-\(UUID().uuidString)", isDirectory: true)
        let store = try CompressionBlockStore(directory: directory)
        let conversationID = UUID()
        for index in 0...LLMContextProvider.compactionMessageThreshold {
            messages.insertMessage(
                Message(
                    conversationID: conversationID,
                    role: .user,
                    content: String(repeating: "持久化摘要内容 ", count: 100) + "\(index)"
                ),
                to: conversationID
            )
        }

        let firstProvider = LLMContextProvider(
            messages: messages,
            conversations: conversations,
            llmProvider: llm,
            blockStore: store
        )
        _ = await firstProvider.messagesForLLM(in: conversationID)

        for _ in 0..<12 {
            try await Task.sleep(nanoseconds: 100_000_000)
            let result = await firstProvider.messagesForLLM(in: conversationID)
            if result.contains(where: { $0.metadata["llmContext"] == "summary" }) {
                break
            }
        }

        #expect(FileManager.default.fileExists(
            atPath: directory.appendingPathComponent(CompressionBlockStore.databaseFileName).path
        ))
        #expect(summaryProvider.completeCalls == 1)

        let secondProvider = LLMContextProvider(
            messages: messages,
            conversations: conversations,
            llmProvider: llm,
            blockStore: store
        )
        let restored = await secondProvider.messagesForLLM(in: conversationID)

        #expect(restored.contains { $0.metadata["llmContext"] == "summary" })
        #expect(restored.contains { $0.content.contains("摘要结果") })
        #expect(summaryProvider.completeCalls == 1)
    }

    @Test("旧单摘要记录迁移为 tier-1 压缩块后复用")
    func legacySummaryMigratesToCompressionBlock() async throws {
        let messages = DefaultMessageManager()
        let conversations = DefaultConversationManager()
        let llm = DefaultLLMManager()
        let summaryProvider = SummaryLLMProvider()
        try llm.register(summaryProvider)
        llm.select(providerID: summaryProvider.providerID, model: "summary-model", reason: .userSelected)

        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("LLMContextMigrationTests-\(UUID().uuidString)", isDirectory: true)
        let legacyStore = try ContextSummaryStore(directory: directory)
        let blockStore = try CompressionBlockStore(directory: directory)
        let conversationID = UUID()
        var history: [Message] = []
        for index in 0...LLMContextProvider.compactionMessageThreshold {
            let message = Message(
                conversationID: conversationID,
                role: .user,
                content: String(repeating: "迁移摘要内容 ", count: 100) + "\(index)"
            )
            history.append(message)
            messages.insertMessage(message, to: conversationID)
        }

        // 预置一条旧格式摘要：覆盖到倒数第 17 条（保留最近 16 条逐字区间）。
        let coveredThrough = history[history.count - 17].id
        try await legacyStore.save(ContextSummaryRecord(
            conversationID: conversationID,
            text: "旧版滚动摘要",
            coveredThroughMessageID: coveredThrough,
            sourceLastMessageID: history[history.count - 1].id,
            providerID: summaryProvider.providerID,
            modelName: "summary-model",
            sourceMessageCount: history.count,
            updatedAt: Date()
        ))

        let provider = LLMContextProvider(
            messages: messages,
            conversations: conversations,
            llmProvider: llm,
            summaryStore: legacyStore,
            blockStore: blockStore
        )
        let budget = LLMContextBudget(
            contextWindowTokens: 5_000,
            reservedOutputTokens: 500,
            safetyMarginTokens: 500
        )
        let request = LLMContextPreparationRequest(
            conversationID: conversationID,
            providerID: summaryProvider.providerID,
            model: "summary-model",
            budget: budget,
            mode: .beforeSend
        )
        let result = await provider.prepareContext(for: request)

        // 迁移块直接复用：渲染旧摘要正文，不触发新的摘要调用。
        #expect(result.didCompact)
        #expect(result.messages.contains { $0.content.contains("旧版滚动摘要") })
        #expect(summaryProvider.completeCalls == 0)
        // 旧记录已升级并删除，块存储里能读到迁移块。
        let persisted = try await blockStore.load(conversationID: conversationID)
        #expect(persisted.count == 1)
        #expect(persisted.first?.tier == 1)
        #expect(persisted.first?.summary == "旧版滚动摘要")
        #expect(try await legacyStore.load(conversationID: conversationID) == nil)
    }

    @Test("压缩结果落在目标水位内，不会把预算填满")
    func compactionResultStaysUnderTargetWatermark() async {
        let messages = DefaultMessageManager()
        let conversations = DefaultConversationManager()
        let llm = DefaultLLMManager()
        let summaryProvider = SummaryLLMProvider()
        try? llm.register(summaryProvider)
        llm.select(providerID: summaryProvider.providerID, model: "summary-model", reason: .userSelected)

        let provider = LLMContextProvider(
            messages: messages,
            conversations: conversations,
            llmProvider: llm
        )
        let conversationID = UUID()
        for index in 0..<400 {
            messages.insertMessage(
                Message(
                    conversationID: conversationID,
                    role: .user,
                    content: String(repeating: "长对话内容 ", count: 150) + "\(index)"
                ),
                to: conversationID
            )
        }

        let budget = LLMContextBudget(
            contextWindowTokens: 200_000,
            reservedOutputTokens: 8_000,
            safetyMarginTokens: 4_000
        )
        let request = LLMContextPreparationRequest(
            conversationID: conversationID,
            providerID: summaryProvider.providerID,
            model: "summary-model",
            budget: budget,
            mode: .beforeSend
        )
        let result = await provider.prepareContext(for: request)

        #expect(result.didCompact)
        #expect(result.estimatedInputTokens <= budget.compactionTargetTokens)
        #expect(result.estimatedInputTokens < budget.inputTokenLimit)
    }

    @Test("摘要仍然覆盖得住最近区间时不会重新生成")
    func validSnapshotIsReusedWithoutNewSummary() async {
        let messages = DefaultMessageManager()
        let conversations = DefaultConversationManager()
        let llm = DefaultLLMManager()
        let summaryProvider = SummaryLLMProvider()
        try? llm.register(summaryProvider)
        llm.select(providerID: summaryProvider.providerID, model: "summary-model", reason: .userSelected)

        let provider = LLMContextProvider(
            messages: messages,
            conversations: conversations,
            llmProvider: llm
        )
        let conversationID = UUID()
        for index in 0..<400 {
            messages.insertMessage(
                Message(
                    conversationID: conversationID,
                    role: .user,
                    content: String(repeating: "长对话内容 ", count: 150) + "\(index)"
                ),
                to: conversationID
            )
        }

        let budget = LLMContextBudget(
            contextWindowTokens: 200_000,
            reservedOutputTokens: 8_000,
            safetyMarginTokens: 4_000
        )
        let request = LLMContextPreparationRequest(
            conversationID: conversationID,
            providerID: summaryProvider.providerID,
            model: "summary-model",
            budget: budget,
            mode: .beforeSend
        )

        let first = await provider.prepareContext(for: request)
        #expect(first.didCompact)

        // 摘要水位需要先把未折叠的中间段吸收掉，压缩结果落进目标水位后即���收敛。
        var converged = false
        for _ in 0..<8 {
            let result = await provider.prepareContext(for: request)
            if result.estimatedInputTokens <= Int(Double(budget.compactionTargetTokens) * 0.8) {
                converged = true
                break
            }
        }
        #expect(converged)
        let callsAfterConvergence = summaryProvider.completeCalls

        // 收敛之后继续推进对话，不应再触发新的摘要。
        for index in 0..<3 {
            messages.insertMessage(
                Message(
                    conversationID: conversationID,
                    role: .user,
                    content: String(repeating: "新增内容 ", count: 150) + "\(index)"
                ),
                to: conversationID
            )
        }
        let second = await provider.prepareContext(for: request)

        #expect(second.didCompact)
        #expect(second.estimatedInputTokens <= budget.compactionTargetTokens)
        #expect(summaryProvider.completeCalls == callsAfterConvergence)
    }

    @Test("压缩上下文会裁剪超大的旧工具输出")
    func oversizedToolOutputIsTruncatedInCompactedContext() async {
        let messages = DefaultMessageManager()
        let conversations = DefaultConversationManager()
        let llm = DefaultLLMManager()
        let summaryProvider = SummaryLLMProvider()
        try? llm.register(summaryProvider)
        llm.select(providerID: summaryProvider.providerID, model: "summary-model", reason: .userSelected)

        let provider = LLMContextProvider(
            messages: messages,
            conversations: conversations,
            llmProvider: llm
        )
        let conversationID = UUID()
        for index in 0..<100 {
            messages.insertMessage(
                Message(
                    conversationID: conversationID,
                    role: .user,
                    content: String(repeating: "长对话内容 ", count: 150) + "\(index)"
                ),
                to: conversationID
            )
        }
        // 一条超大的旧工具输出：必须被裁剪，否则它会吃掉整个预算。
        messages.insertMessage(
            Message(
                conversationID: conversationID,
                role: .tool,
                content: String(repeating: "工具输出", count: 25_000),
                toolCallID: "call-huge"
            ),
            to: conversationID
        )
        // 最近几条工具结果保持原样，模型可能仍在依赖它们。
        for index in 0..<4 {
            messages.insertMessage(
                Message(
                    conversationID: conversationID,
                    role: .tool,
                    content: "最近工具结果 \(index)",
                    toolCallID: "call-recent-\(index)"
                ),
                to: conversationID
            )
        }
        messages.insertMessage(
            Message(conversationID: conversationID, role: .user, content: "继续"),
            to: conversationID
        )

        let budget = LLMContextBudget(
            contextWindowTokens: 100_000,
            reservedOutputTokens: 8_000,
            safetyMarginTokens: 2_000
        )
        let request = LLMContextPreparationRequest(
            conversationID: conversationID,
            providerID: summaryProvider.providerID,
            model: "summary-model",
            budget: budget,
            mode: .beforeSend
        )
        let result = await provider.prepareContext(for: request)

        #expect(result.didCompact)
        let hugeTool = result.messages.first {
            $0.role == .tool && $0.toolCallID == "call-huge"
        }
        #expect(hugeTool != nil)
        #expect(hugeTool?.content.count ?? 0 <= LLMContextProvider.maxToolResultChars + 32)
        #expect(hugeTool?.content.contains("[truncated]") == true)
        // 最近的工具结果保持原样。
        #expect(result.messages.contains { $0.toolCallID == "call-recent-3" && !$0.content.contains("[truncated]") })
    }

    @Test("保留窗口本身就超预算时仍然产出不超过预算的上下文")
    func irreducibleProtectedWindowStillProducesValidContext() async {
        let messages = DefaultMessageManager()
        let conversations = DefaultConversationManager()
        let llm = DefaultLLMManager()
        let summaryProvider = SummaryLLMProvider()
        try? llm.register(summaryProvider)
        llm.select(providerID: summaryProvider.providerID, model: "summary-model", reason: .userSelected)

        let provider = LLMContextProvider(
            messages: messages,
            conversations: conversations,
            llmProvider: llm
        )
        let conversationID = UUID()
        // 单条消息就接近整个输入预算，保留窗口无论如何都装不下。
        for index in 0..<60 {
            messages.insertMessage(
                Message(
                    conversationID: conversationID,
                    role: .user,
                    content: String(repeating: "超长单条内容 ", count: 600) + "\(index)"
                ),
                to: conversationID
            )
        }

        let budget = LLMContextBudget(
            contextWindowTokens: 20_000,
            reservedOutputTokens: 2_000,
            safetyMarginTokens: 1_000
        )
        let request = LLMContextPreparationRequest(
            conversationID: conversationID,
            providerID: summaryProvider.providerID,
            model: "summary-model",
            budget: budget,
            mode: .beforeSend
        )

        let result = await provider.prepareContext(for: request)

        // 即使保留窗口装不下，也必须产出不超过硬上限的上下文。
        #expect(result.estimatedInputTokens <= budget.inputTokenLimit)
        #expect(result.messages.contains { $0.metadata["llmContext"] == "summary" })
    }

    @Test("不可发送的错误与状态消息不进入 LLM 历史")
    func nonSendableRolesAreExcludedFromLLMHistory() async {
        let messages = DefaultMessageManager()
        let conversations = DefaultConversationManager()
        let llm = DefaultLLMManager()
        let provider = LLMContextProvider(
            messages: messages,
            conversations: conversations,
            llmProvider: llm
        )
        let conversationID = UUID()

        messages.insertMessage(
            Message(conversationID: conversationID, role: .user, content: "你好"),
            to: conversationID
        )
        messages.insertMessage(
            Message(conversationID: conversationID, role: .error, content: "provider failed"),
            to: conversationID
        )
        messages.insertMessage(
            Message(conversationID: conversationID, role: .status, content: "后台任务完成"),
            to: conversationID
        )

        let result = await provider.messagesForLLM(in: conversationID)

        #expect(result.map(\.role) == [.user])
        #expect(result.first?.content == "你好")
    }

    @Test("降级裁剪不会让尾部错误消息挤掉真实用户请求")
    func fallbackKeepsUserRequestWhenErrorExceedsBudget() async {
        let messages = DefaultMessageManager()
        let conversations = DefaultConversationManager()
        let llm = DefaultLLMManager()
        let provider = LLMContextProvider(
            messages: messages,
            conversations: conversations,
            llmProvider: llm
        )
        let conversationID = UUID()

        messages.insertMessage(
            Message(conversationID: conversationID, role: .user, content: "hi"),
            to: conversationID
        )
        messages.insertMessage(
            Message(
                conversationID: conversationID,
                role: .error,
                content: String(repeating: "x", count: 5_000)
            ),
            to: conversationID
        )

        // 输入上限约 1,096 token：错误消息原文超预算，旧实现会截断它并 break，
        // 让更早的 "hi" 完全没有机会进入请求。
        let budget = LLMContextBudget(
            contextWindowTokens: 4_096,
            reservedOutputTokens: 2_000,
            safetyMarginTokens: 1_000
        )
        let request = LLMContextPreparationRequest(
            conversationID: conversationID,
            providerID: nil,
            model: nil,
            budget: budget,
            mode: .beforeSend
        )

        let result = await provider.prepareContext(for: request)

        #expect(result.messages.map(\.role) == [.user])
        #expect(result.messages.first?.content == "hi")
    }

    @Test("超长中文用户消息按 token 裁剪后保留，而不是整条丢弃")
    func oversizedChineseUserMessageIsTruncatedInsteadOfDropped() async throws {
        let messages = DefaultMessageManager()
        let conversations = DefaultConversationManager()
        let llm = DefaultLLMManager()
        let provider = LLMContextProvider(
            messages: messages,
            conversations: conversations,
            llmProvider: llm
        )
        let conversationID = UUID()
        let request = Self.fallbackRequest(conversationID: conversationID)

        messages.insertMessage(
            Message(
                conversationID: conversationID,
                role: .user,
                content: String(repeating: "汉", count: 2_000)
            ),
            to: conversationID
        )

        let result = await provider.prepareContext(for: request)

        // 旧实现用「字符数 = token × 2」裁剪：2,000 个汉字（约 2,012 token）
        // 没有超过 2,192 字符上限，正文原样保留后又因超预算被整条省略，
        // 请求里只剩 system（或为空）。
        #expect(result.messages.count == 1)
        let user = try #require(result.messages.first)
        #expect(user.role == .user)
        #expect(user.content.count < 2_000)
        #expect(user.content.hasSuffix("…[truncated]"))
        let estimate = LLMContextTokenEstimator.estimate(messages: result.messages)
        #expect(estimate <= result.inputTokenLimit)
        // 裁剪必须吃到预算：按字符维度的旧上限只会留下约四分之一，
        // 虽然「没丢」，但实际上把用户的大部分问题也丢了。
        #expect(estimate >= result.inputTokenLimit / 2)
    }

    @Test("系统消息占满预算时仍保留本轮用户请求")
    func largeSystemMessageDoesNotEvictUserRequest() async throws {
        let messages = DefaultMessageManager()
        let conversations = DefaultConversationManager()
        let llm = DefaultLLMManager()
        let provider = LLMContextProvider(
            messages: messages,
            conversations: conversations,
            llmProvider: llm
        )
        let conversationID = UUID()
        let request = Self.fallbackRequest(conversationID: conversationID)

        messages.insertMessage(
            Message(
                conversationID: conversationID,
                role: .system,
                content: String(repeating: "系", count: 1_050)
            ),
            to: conversationID
        )
        let question = String(repeating: "问", count: 30)
        messages.insertMessage(
            Message(conversationID: conversationID, role: .user, content: question),
            to: conversationID
        )

        let result = await provider.prepareContext(for: request)

        // 旧的贪婪选择先让 system 吃掉绝大部分预算，尾部用户消息因装不下而
        // 结束遍历，最终请求里没有用户消息，也没有真正的问题内容。
        let system = try #require(result.messages.first)
        #expect(system.role == .system)
        let user = try #require(result.messages.last)
        #expect(result.messages.contains { $0.role == .user })
        #expect(user.role == .user)
        #expect(!user.content.isEmpty)
        #expect(user.content.hasPrefix("问问"))
        #expect(LLMContextTokenEstimator.estimate(messages: result.messages) <= result.inputTokenLimit)
    }

    /// 约 1,096 token 输入上限：触发确定性降级且不依赖摘要 Provider。
    private static func fallbackRequest(conversationID: UUID) -> LLMContextPreparationRequest {
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

    @Test("复用压缩上下文的重复请求不再同步全量读取会话（#1256）")
    func duplicateGuardAvoidsSynchronousFullRead() async throws {
        let messages = CountingMessageManager()
        let conversations = DefaultConversationManager()
        let llm = DefaultLLMManager()
        let summaryProvider = SummaryLLMProvider()
        try llm.register(summaryProvider)
        llm.select(providerID: summaryProvider.providerID, model: "summary-model", reason: .userSelected)

        let provider = LLMContextProvider(
            messages: messages,
            conversations: conversations,
            llmProvider: llm
        )
        let conversationID = UUID()
        for index in 0..<60 {
            messages.insertMessage(
                Message(
                    conversationID: conversationID,
                    role: .user,
                    content: String(repeating: "长对话内容 ", count: 600) + "\(index)"
                ),
                to: conversationID
            )
        }

        let request = LLMContextPreparationRequest(
            conversationID: conversationID,
            providerID: summaryProvider.providerID,
            model: "summary-model",
            budget: LLMContextBudget(
                contextWindowTokens: 20_000,
                reservedOutputTokens: 2_000,
                safetyMarginTokens: 1_000
            ),
            mode: .beforeSend
        )

        // 首次合格请求：折叠并记录一条压缩事件。
        let first = await provider.prepareContext(for: request)
        #expect(first.didCompact)
        #expect(messages.base.messages(for: conversationID).filter {
            MessageTimelineEvent.isActualContextCompaction($0)
        }.count == 1)

        // 热点路径：复用同一份压缩上下文再次请求，去重守卫必须 O(1) 命中，
        // 不再在 MainActor 同步全量读取会话。
        messages.resetReadCount()
        let second = await provider.prepareContext(for: request)
        #expect(second.didCompact)
        #expect(messages.synchronousFullReads == 0)
        // 去重保护仍在：压缩事件只有一条。
        #expect(messages.base.messages(for: conversationID).filter {
            MessageTimelineEvent.isActualContextCompaction($0)
        }.count == 1)
    }
}

/// 计数 spy：统计 provider 直接发起的同步全量读取 `messages(for:)`。
/// 异步快照（`messagesSnapshot` / `messagesForLLM`）转发给 base，不计入同步次数，
/// 以此锁定「去重守卫不得在 MainActor 同步全量读取」这一性能契约（#1256）。
@MainActor
private final class CountingMessageManager: MessageManaging {
    let base = DefaultMessageManager()
    private(set) var synchronousFullReads = 0

    func resetReadCount() { synchronousFullReads = 0 }

    func messages(for conversationID: UUID) -> [Message] {
        synchronousFullReads += 1
        return base.messages(for: conversationID)
    }

    func messagesSnapshot(in conversationID: UUID) async -> [Message] {
        await base.messagesSnapshot(in: conversationID)
    }

    func messagesForLLM(in conversationID: UUID) async -> [Message] {
        await base.messagesForLLM(in: conversationID)
    }

    func message(id: UUID, in conversationID: UUID) -> Message? {
        base.message(id: id, in: conversationID)
    }

    func lastMessage(in conversationID: UUID) -> Message? {
        base.lastMessage(in: conversationID)
    }

    func messageCount(for conversationID: UUID) -> Int {
        base.messageCount(for: conversationID)
    }

    func insertMessage(_ message: Message, to conversationID: UUID) {
        base.insertMessage(message, to: conversationID)
    }

    func updateMessage(id: UUID, in conversationID: UUID, content: String) {
        base.updateMessage(id: id, in: conversationID, content: content)
    }

    func deleteMessage(id: UUID, in conversationID: UUID) {
        base.deleteMessage(id: id, in: conversationID)
    }

    func clearMessages(in conversationID: UUID) {
        base.clearMessages(in: conversationID)
    }

    func updateToolCallResult(
        _ result: MessageToolResult,
        toolCallID: String,
        assistantMessageID: UUID,
        in conversationID: UUID,
        authorizationState: String?
    ) {
        base.updateToolCallResult(
            result,
            toolCallID: toolCallID,
            assistantMessageID: assistantMessageID,
            in: conversationID,
            authorizationState: authorizationState
        )
    }
}

@MainActor
private final class SummaryLLMProvider: SuperLLMProvider {
    let providerInfo: LLMProviderInfo

    init(id: String = "summary-test-provider", contextWindowTokens: Int? = nil) {
        providerInfo = LLMProviderInfo(
            id: id,
            displayName: "Summary Test Provider",
            defaultModel: "summary-model",
            models: [LLMModelInfo(id: "summary-model", contextWindowSize: contextWindowTokens)]
        )
    }
    private(set) var completeCalls = 0

    var providerID: String { providerInfo.id }

    func complete(_ request: LLMRequest) async throws -> LLMResponse {
        completeCalls += 1
        return LLMResponse(content: "摘要结果", model: request.model)
    }
}


/// 压缩块的**并发加载**。
///
/// ## 回归背景
///
/// `LLMContextProvider.loadBlocksIfNeeded` 曾在**任何 await 之前**同步置位
/// 「已加载」标记。主流程（`prepareContext`）与后台压缩任务
/// （`scheduleBackgroundCompaction`）会并发调用它，于是：
///
/// - 先到者置位标记后进入 await（让出主 actor）；
/// - 后到者看到「已加载」标记，**直接返回**，读到**空块**。
///
/// 症状：迁移后的块偶发丢失、`persisted.count` 断言偶发为 0，
/// 且**只在并发时出现**，单跑必过 —— 极难归因。
///
/// 现在改成三态（未加载 / 加载中 / 已加载）：重复调用者会 await
/// 同一个加载任务，拿到一致结果。
@MainActor
@Suite("压缩块的并发加载")
struct ConcurrentBlockLoadTests {

    @Test("并发调用时两个调用者都读到迁移后的块")
    func concurrentLoadersSeeTheSameMigratedBlock() async throws {
        let messages = DefaultMessageManager()
        let conversations = DefaultConversationManager()
        let llm = DefaultLLMManager()
        let summaryProvider = SummaryLLMProvider()
        try llm.register(summaryProvider)
        llm.select(providerID: summaryProvider.providerID, model: "summary-model", reason: .userSelected)

        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("LLMContextConcurrentLoad-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let legacyStore = try ContextSummaryStore(directory: directory)
        let blockStore = try CompressionBlockStore(directory: directory)
        let conversationID = UUID()

        var history: [Message] = []
        for index in 0...LLMContextProvider.compactionMessageThreshold {
            let message = Message(
                conversationID: conversationID,
                role: .user,
                content: String(repeating: "并发加载内容 ", count: 100) + "\(index)"
            )
            history.append(message)
            messages.insertMessage(message, to: conversationID)
        }

        // 预置一条旧格式摘要，迁移路径才会被走到。
        let coveredThrough = history[history.count - 17].id
        try await legacyStore.save(ContextSummaryRecord(
            conversationID: conversationID,
            text: "旧版滚动摘要",
            coveredThroughMessageID: coveredThrough,
            sourceLastMessageID: history[history.count - 1].id,
            providerID: summaryProvider.providerID,
            modelName: "summary-model",
            sourceMessageCount: history.count,
            updatedAt: Date()
        ))

        let budget = LLMContextBudget(
            contextWindowTokens: 5_000,
            reservedOutputTokens: 500,
            safetyMarginTokens: 500
        )
        let request = LLMContextPreparationRequest(
            conversationID: conversationID,
            providerID: summaryProvider.providerID,
            model: "summary-model",
            budget: budget,
            mode: .beforeSend
        )

        let provider = LLMContextProvider(
            messages: messages,
            conversations: conversations,
            llmProvider: llm,
            summaryStore: legacyStore,
            blockStore: blockStore
        )

        // 两个**非结构化** Task 并发进入 `loadBlocksIfNeeded`。
        //
        // - Important: 必须用 `Task { }` 而不是 `async let` —— 后者是
        //   结构化并发，在 MainActor 上两个子任务仍然**串行**执行，
        //   根本构造不出竞争（实测：换 `async let` 后本用例无法复现缺陷）。
        //   `Task { }` 才是真正并发的两个 Task。
        //
        //   修复前：先到者置位「已加载」后 await 存储加载，后到者看到
        //   标记直接返回 → 读到**空块**。修复后：后到者等待同一个
        //   加载任务 → 两个调用者都拿到迁移后的块。
        let first = Task { @MainActor in
            await provider.compressionBlocks(for: conversationID)
        }
        let second = Task { @MainActor in
            await provider.compressionBlocks(for: conversationID)
        }
        let results = [await first.value, await second.value]

        // 两个调用者都必须看到迁移后的块。
        for (index, blocks) in results.enumerated() {
            #expect(
                blocks.count == 1,
                "并发调用者必须都读到迁移后的块（调用者 \(index) 实得 \(blocks.count) 个）"
            )
            #expect(blocks.first?.summary == "旧版滚动摘要")
        }

        // 迁移**只发生一次**（修复前会各写一个块）。
        let persisted = try await blockStore.load(conversationID: conversationID)
        #expect(
            persisted.count == 1,
            """
            迁移只应发生一次，实际写入 \(persisted.count) 个块 —— \
            并发调用者重复迁移了。
            """
        )
        #expect(persisted.first?.tier == 1)
        #expect(persisted.first?.summary == "旧版滚动摘要")
        #expect(try await legacyStore.load(conversationID: conversationID) == nil)
    }

    @Test("并发调用不因重复加载而产生重复的迁移块")
    func concurrentLoadersDoNotProduceDuplicateMigratedBlocks() async throws {
        let messages = DefaultMessageManager()
        let conversations = DefaultConversationManager()
        let llm = DefaultLLMManager()
        let summaryProvider = SummaryLLMProvider()
        try llm.register(summaryProvider)
        llm.select(providerID: summaryProvider.providerID, model: "summary-model", reason: .userSelected)

        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("LLMContextConcurrentSummary-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let legacyStore = try ContextSummaryStore(directory: directory)
        let blockStore = try CompressionBlockStore(directory: directory)
        let conversationID = UUID()

        for index in 0...LLMContextProvider.compactionMessageThreshold {
            let message = Message(
                conversationID: conversationID,
                role: .user,
                content: String(repeating: "并发摘要内容 ", count: 100) + "\(index)"
            )
            messages.insertMessage(message, to: conversationID)
        }

        let provider = LLMContextProvider(
            messages: messages,
            conversations: conversations,
            llmProvider: llm,
            summaryStore: legacyStore,
            blockStore: blockStore
        )
        let budget = LLMContextBudget(
            contextWindowTokens: 5_000,
            reservedOutputTokens: 500,
            safetyMarginTokens: 500
        )
        let request = LLMContextPreparationRequest(
            conversationID: conversationID,
            providerID: summaryProvider.providerID,
            model: "summary-model",
            budget: budget,
            mode: .beforeSend
        )

        async let first = provider.prepareContext(for: request)
        async let second = provider.prepareContext(for: request)
        _ = await [first, second]

        // 没有旧摘要可迁移时走正常的压缩流程，摘要调用次数由引擎决定，
        // 这里只断言**块存储里没有重复块** —— 并发加载不应各写一份。
        let persisted = try await blockStore.load(conversationID: conversationID)
        let tier1 = persisted.filter { $0.tier == 1 }
        #expect(tier1.count <= 1, "并发加载不应写出重复的块")
    }
}
