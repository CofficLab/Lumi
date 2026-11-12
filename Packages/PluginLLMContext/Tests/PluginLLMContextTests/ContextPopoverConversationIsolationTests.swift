import Foundation
import KitLLM
import ProviderConversation
import ProviderLLMContext
import ProviderLLMManager
import ProviderMessage
import Testing

@testable import PluginLLMContext

/// 上下文弹窗的「用量 / 幕后账本 / 趋势曲线」数据源必须严格按对话隔离。
///
/// ## 为什么需要这组测试
///
/// 弹窗除了消息快照，还读取：
/// - `contextWindowUsage(for:)` → 估算输入 token（来自该对话自己的 LLM 历史）；
/// - `auxiliaryUsageEntries(for:)` → 幕后用量账本（压缩 / 标题）；
/// - `ContextUsageHistory.build(from:)` → 趋势曲线（来自传入的快照）。
///
/// 这组测试把「任一对话的用量 / 账本只反映该对话自己的数据」固化成不变量。
/// 若变红，说明弹窗确实会混入其他对话的 token 数据。
///
/// ## 一个刻意保留的共享态
///
/// `calibrationFactors[provider/model]` 是**模型级**估算倍率，跨对话共享：
/// 它用服务端上报 usage 校准「本地估算 → 真实 token」的倍率。它缩放的是
/// 本对话自己历史的估算值，并不把其他对话的 token 数据混进来。最后一个
/// 测试刻画这一设计，避免把它误判成泄漏。
@MainActor
@Suite("上下文弹窗用量与账本的对话隔离")
struct ContextPopoverConversationIsolationTests {

    // MARK: - 最小供应商替身

    private final class IsolationProvider: SuperLLMProvider {
        let providerInfo: LLMProviderInfo
        var availableModels: [LLMModelInfo]
        init() {
            let models = [LLMModelInfo(id: "main-model", contextWindowSize: 200_000)]
            providerInfo = LLMProviderInfo(
                id: "isolation-provider",
                displayName: "isolation-provider",
                defaultModel: "main-model",
                models: models
            )
            availableModels = models
        }
        var providerID: String { providerInfo.id }
        func complete(_ request: LLMRequest) async throws -> LLMResponse {
            LLMResponse(content: "ok", model: request.model ?? "")
        }
    }

    private func makeContext() throws -> (LLMContextProvider, DefaultMessageManager) {
        let messages = DefaultMessageManager()
        let conversations = DefaultConversationManager()
        let llm = DefaultLLMManager()
        let provider = IsolationProvider()
        try llm.register(provider)
        llm.select(providerID: provider.providerID, model: "main-model", reason: .userSelected)
        return (LLMContextProvider(messages: messages, conversations: conversations, llmProvider: llm), messages)
    }

    private func auxEntry(_ conversationID: UUID, input: Int, output: Int) -> LLMAuxiliaryUsageEntry {
        LLMAuxiliaryUsageEntry(
            conversationID: conversationID,
            purpose: .compaction,
            providerID: "isolation-provider",
            modelName: "main-model",
            inputTokenCount: input,
            outputTokenCount: output,
            isEstimated: false
        )
    }

    // MARK: - 幕后账本（内存）

    @Test("内存账本只返回目标对话的幕后用量")
    func auxiliaryLedgerIsConversationScoped() async throws {
        let ledger = AuxiliaryUsageLedger()
        let a = UUID(), b = UUID()
        let entryA = auxEntry(a, input: 1_100, output: 100)
        let entryB = auxEntry(b, input: 9_900, output: 900)
        await ledger.record(entryA)
        await ledger.record(entryB)

        let readA = await ledger.entries(for: a)
        #expect(readA.map(\.id) == [entryA.id])
        #expect(readA.allSatisfy { $0.conversationID == a })
        #expect(readA.allSatisfy { $0.inputTokenCount == 1_100 }, "不得混入 B 的 9900")

        let readB = await ledger.entries(for: b)
        #expect(readB.map(\.id) == [entryB.id])
    }

    // MARK: - 幕后账本（磁盘）

    @Test("磁盘账本只返回目标对话的幕后用量")
    func auxiliaryStoreIsConversationScoped() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("AuxIsolation-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try AuxiliaryUsageStore(directory: directory)
        let a = UUID(), b = UUID()
        let entryA = auxEntry(a, input: 2_200, output: 200)
        let entryB = auxEntry(b, input: 8_800, output: 800)
        try await store.save(entryA)
        try await store.save(entryB)

        let readA = try await store.entries(for: a)
        #expect(readA.map(\.id) == [entryA.id])
        #expect(readA.allSatisfy { $0.conversationID == a })
        #expect(readA.allSatisfy { $0.inputTokenCount == 2_200 })
    }

    @Test("账本首次加载只并入目标对话的磁盘记录")
    func ledgerLoadDoesNotPullOtherConversation() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("AuxLoadIsolation-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try AuxiliaryUsageStore(directory: directory)
        let a = UUID(), b = UUID()
        try await store.save(auxEntry(a, input: 3_300, output: 300))
        try await store.save(auxEntry(b, input: 7_700, output: 700))

        // 全新账本从磁盘加载：ensureLoaded 只能并入 A 自己的记录。
        let ledger = AuxiliaryUsageLedger(store: store)
        let readA = await ledger.entries(for: a)
        #expect(readA.count == 1)
        #expect(readA.allSatisfy { $0.conversationID == a })
        #expect(readA.allSatisfy { $0.inputTokenCount == 3_300 }, "不得把 B 的磁盘记录加载进 A")
    }

    // MARK: - 趋势曲线

    @Test("趋势曲线只绘制传入快照里的采样")
    func usageHistoryPlotsOnlyProvidedSnapshot() throws {
        let a = UUID(), b = UUID()
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let aMessages = (0..<3).map {
            Message(
                conversationID: a, role: .assistant, content: "A\($0)",
                createdAt: base.addingTimeInterval(Double($0) * 60),
                inputTokenCount: 10_000 + $0 * 1_000
            )
        }
        let bMessages = (0..<3).map {
            Message(
                conversationID: b, role: .assistant, content: "B\($0)",
                createdAt: base.addingTimeInterval(Double($0) * 60 + 30),
                inputTokenCount: 90_000 + $0 * 1_000
            )
        }

        // 弹窗实际传入的是「按对话过滤后的快照」：曲线只含 A 的采样。
        let scoped = ContextUsageHistory.build(from: aMessages)
        #expect(scoped.samples.count == 3)
        #expect(scoped.samples.allSatisfy { $0.tokens < 90_000 })
        #expect(Set(scoped.samples.map(\.id)) == Set(aMessages.map(\.id)))

        // 刻画：build 本身不按 conversationID 过滤，它信任调用方传入的快照。
        // 若有人把混合快照传进来，曲线就会画出混合数据 —— 因此隔离保证落在
        // ContextToolbarView 的 messagesSnapshot(in:) 上，而不是 build 内部。
        let mixed = ContextUsageHistory.build(from: aMessages + bMessages)
        #expect(mixed.samples.count == 6)
        #expect(mixed.samples.contains { $0.tokens >= 90_000 })
    }

    // MARK: - 用量估算

    @Test("用量估算只反映目标对话自己的历史")
    func contextWindowUsageEstimateIsConversationScoped() async throws {
        let (context, messages) = try makeContext()
        let a = UUID(), b = UUID()

        // B：短历史。
        messages.insertMessage(Message(conversationID: b, role: .user, content: "短问题"), to: b)
        messages.insertMessage(
            Message(conversationID: b, role: .assistant, content: "短回答", inputTokenCount: 500),
            to: b
        )
        let usageBBefore = try #require(await context.contextWindowUsage(for: b)?.estimatedInputTokens)

        // A：灌入大量长消息。B 的估算不得随之增长。
        for index in 0..<60 {
            messages.insertMessage(
                Message(
                    conversationID: a, role: .user,
                    content: String(repeating: "长对话内容 ", count: 600) + "\(index)"
                ),
                to: a
            )
        }
        let usageBAfter = try #require(await context.contextWindowUsage(for: b)?.estimatedInputTokens)
        let usageA = try #require(await context.contextWindowUsage(for: a)?.estimatedInputTokens)

        #expect(usageBBefore == usageBAfter, "B 的估算不得混入 A 的历史 token")
        #expect(usageA > usageBAfter, "A 的估算应反映自己的大历史")
    }

    @Test("模型级校准倍率跨对话共享（设计如此，非数据混入）")
    func calibrationFactorIsSharedPerModelNotPerConversation() async throws {
        let (context, messages) = try makeContext()
        let a = UUID(), b = UUID()
        messages.insertMessage(Message(conversationID: b, role: .user, content: "问题"), to: b)
        messages.insertMessage(
            Message(conversationID: b, role: .assistant, content: "回答", inputTokenCount: 500),
            to: b
        )
        let before = try #require(await context.contextWindowUsage(for: b)?.estimatedInputTokens)

        // 用 A 的一次服务端上报把 provider/model 倍率向上校准。
        let request = LLMContextPreparationRequest(
            conversationID: a,
            providerID: "isolation-provider",
            model: "main-model",
            budget: LLMContextBudget(
                contextWindowTokens: 200_000,
                reservedOutputTokens: 2_000,
                safetyMarginTokens: 1_000
            ),
            mode: .beforeSend
        )
        context.reportInputUsage(1_000_000, for: request, estimatedInputTokens: 1_000)

        let after = try #require(await context.contextWindowUsage(for: b)?.estimatedInputTokens)
        // 倍率是模型级共享态：B 的「估算值」被同一倍率缩放。
        // 注意缩放的是 B 自己历史的估算，B 的消息集合并未混入 A 的任何 token。
        #expect(after >= before, "共享倍率向上校准后估算不小于校准前")
    }
}