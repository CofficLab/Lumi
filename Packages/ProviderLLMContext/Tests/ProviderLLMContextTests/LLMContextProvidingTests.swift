import Foundation
import Testing
import ProviderMessage
import KitLLM
@testable import ProviderLLMContext

@MainActor
struct LLMContextProvidingTests {
    @Test("上下文预算为输出、工具和安全余量预留空间")
    func contextBudgetReservesSpace() {
        let budget = LLMContextBudget(
            contextWindowTokens: 32_000,
            reservedOutputTokens: 8_000,
            toolSchemaTokens: 2_000,
            safetyMarginTokens: 1_000
        )

        #expect(budget.inputTokenLimit == 21_000)
        #expect(!budget.usesFallbackWindow)
    }

    @Test("未知窗口使用保守 fallback")
    func unknownContextWindowUsesFallback() {
        let budget = LLMContextBudget.conservative(contextWindowTokens: nil)

        #expect(budget.usesFallbackWindow)
        #expect(budget.inputTokenLimit == 22_000)
    }

    @Test("token 估算包含消息正文、reasoning 和工具参数")
    func tokenEstimatorIncludesMessageParts() {
        let message = Message(
            conversationID: UUID(),
            role: .assistant,
            content: "回答",
            reasoningContent: "推理",
            toolCalls: [
                MessageToolCall(id: "call-1", name: "search", arguments: "{\"q\":\"Lumi\"}"),
            ]
        )

        #expect(LLMContextTokenEstimator.estimate(message: message) > 12)
    }

    @Test("透传 Provider 保留消息顺序和内容")
    func passthroughPreservesMessages() async {
        let messages = DefaultMessageManager()
        let provider = PassthroughLLMContextProvider(messages: messages)
        let conversationID = UUID()

        messages.insertMessage(
            Message(conversationID: conversationID, role: .user, content: "第一条"),
            to: conversationID
        )
        messages.insertMessage(
            Message(conversationID: conversationID, role: .assistant, content: "第二条"),
            to: conversationID
        )

        let result = await provider.messagesForLLM(in: conversationID)

        #expect(result.map(\.content) == ["第一条", "第二条"])
        #expect(result.map(\.role) == [.user, .assistant])
    }

    @Test("透传 Provider 不返回其他会话的消息")
    func passthroughScopesConversation() async {
        let messages = DefaultMessageManager()
        let provider = PassthroughLLMContextProvider(messages: messages)
        let conversationID = UUID()
        let otherConversationID = UUID()

        messages.insertMessage(
            Message(conversationID: conversationID, role: .user, content: "目标会话"),
            to: conversationID
        )
        messages.insertMessage(
            Message(conversationID: otherConversationID, role: .user, content: "其他会话"),
            to: otherConversationID
        )

        let result = await provider.messagesForLLM(in: conversationID)

        #expect(result.map(\.content) == ["目标会话"])
    }

    // MARK: - LLMContextBudget clamping & derived values

    @Test("预算将负值输出、工具和安全余量钳为零")
    func budgetClampsNegativeReservations() {
        let budget = LLMContextBudget(
            contextWindowTokens: 32_000,
            reservedOutputTokens: -100,
            toolSchemaTokens: -50,
            safetyMarginTokens: -10
        )
        #expect(budget.reservedOutputTokens == 0)
        #expect(budget.toolSchemaTokens == 0)
        #expect(budget.safetyMarginTokens == 0)
    }

    @Test("effective window 低于 4096 时抬到下限")
    func effectiveWindowFloor() {
        let budget = LLMContextBudget(contextWindowTokens: 2_000)
        #expect(budget.effectiveContextWindowTokens == 4_096)
    }

    @Test("fallback window 低于 4096 时抬到下限")
    func fallbackWindowFloor() {
        let budget = LLMContextBudget(contextWindowTokens: nil, fallbackContextWindowTokens: 100)
        #expect(budget.effectiveContextWindowTokens == 4_096)
        #expect(budget.usesFallbackWindow)
    }

    @Test("inputTokenLimit 不会低于 1024")
    func inputTokenLimitFloor() {
        // Window 4096 minus a huge output reserve must not go below 1024.
        let budget = LLMContextBudget(
            contextWindowTokens: 4_096,
            reservedOutputTokens: 80_000,
            toolSchemaTokens: 0,
            safetyMarginTokens: 0
        )
        #expect(budget.inputTokenLimit == 1_024)
    }

    @Test("usesFallbackWindow 仅在未提供窗口时为真")
    func usesFallbackWindowFlag() {
        #expect(LLMContextBudget(contextWindowTokens: nil).usesFallbackWindow)
        #expect(!LLMContextBudget(contextWindowTokens: 32_000).usesFallbackWindow)
    }

    @Test("保守预算按窗口比例计算输出预留和安全余量")
    func conservativeBudgetScalesWithWindow() {
        let budget = LLMContextBudget.conservative(contextWindowTokens: 100_000)
        // window/5 = 20_000 output reserve, window/20 = 5_000 safety margin.
        #expect(budget.inputTokenLimit == 100_000 - 20_000 - 5_000)
        #expect(!budget.usesFallbackWindow)
    }

    @Test("保守预算对小窗口使用输出预留和安全余量下限")
    func conservativeBudgetFloorsForSmallWindow() {
        let budget = LLMContextBudget.conservative(contextWindowTokens: 8_000)
        // window/5 = 1600 -> clamped up to the 8000 output reserve floor.
        // window/20 = 400 -> clamped up to the 2000 safety margin floor.
        // effective = 8000; 8000 - 8000 - 0 - 2000 = -2000 -> clamped to 1024.
        #expect(budget.inputTokenLimit == 1_024)
    }

    @Test("保守预算将 toolSchemaTokens 计入输入限额")
    func conservativeBudgetCountsToolSchema() {
        let plain = LLMContextBudget.conservative(contextWindowTokens: 100_000, toolSchemaTokens: 4_000)
        // 100_000 - 20_000 (output) - 4_000 (tool) - 5_000 (safety) = 71_000
        #expect(plain.inputTokenLimit == 71_000)
    }

    // MARK: - LLMContextPreparationMode & EstimateSource

    @Test("准备模式暴露三个 release track 及其 rawValue")
    func preparationModeCases() {
        #expect(LLMContextPreparationMode.prewarm.rawValue == "prewarm")
        #expect(LLMContextPreparationMode.beforeSend.rawValue == "beforeSend")
        #expect(LLMContextPreparationMode.emergency.rawValue == "emergency")
    }

    @Test("估算来源暴露三种来源及其 rawValue")
    func estimateSourceCases() {
        #expect(LLMContextEstimateSource.exact.rawValue == "exact")
        #expect(LLMContextEstimateSource.estimated.rawValue == "estimated")
        #expect(LLMContextEstimateSource.fallback.rawValue == "fallback")
        #expect(LLMContextEstimateSource.estimated != .fallback)
    }

    // MARK: - LLMContextPreparationRequest

    @Test("请求优先使用 modelID 解析 provider 和 model")
    func requestPrefersModelID() {
        let modelID = LLMModelID(providerID: "openai", modelID: "gpt-4o")!
        let request = LLMContextPreparationRequest(
            conversationID: UUID(),
            modelID: modelID,
            providerID: "legacy",
            model: "legacy-model",
            budget: LLMContextBudget(contextWindowTokens: 32_000)
        )
        #expect(request.providerID == "openai")
        #expect(request.model == "gpt-4o")
    }

    @Test("请求在未提供 modelID 时从字符串回退构建")
    func requestFallsBackToProviderStrings() {
        let request = LLMContextPreparationRequest(
            conversationID: UUID(),
            providerID: "anthropic",
            model: "claude-3",
            budget: LLMContextBudget(contextWindowTokens: 32_000)
        )
        #expect(request.providerID == "anthropic")
        #expect(request.model == "claude-3")
    }

    @Test("请求在 providerID 或 model 为空时不构造 modelID")
    func requestWithEmptyStringsHasNoModelID() {
        let request = LLMContextPreparationRequest(
            conversationID: UUID(),
            providerID: "",
            model: "gpt-4",
            budget: LLMContextBudget(contextWindowTokens: 32_000)
        )
        // Empty providerID makes LLMModelID init return nil; fallback strings still surface.
        #expect(request.providerID == "")
        #expect(request.model == "gpt-4")
    }

    @Test("请求默认模式为 beforeSend")
    func requestDefaultMode() {
        let request = LLMContextPreparationRequest(
            conversationID: UUID(),
            budget: LLMContextBudget(contextWindowTokens: 32_000)
        )
        #expect(request.mode == .beforeSend)
    }

    @Test("请求相等性比较关键字段")
    func requestEquatable() {
        let id = UUID()
        let budget = LLMContextBudget(contextWindowTokens: 32_000)
        let a = LLMContextPreparationRequest(conversationID: id, budget: budget, mode: .prewarm)
        let b = LLMContextPreparationRequest(conversationID: id, budget: budget, mode: .prewarm)
        let c = LLMContextPreparationRequest(conversationID: id, budget: budget, mode: .emergency)
        #expect(a == b)
        #expect(a != c)
    }

    // MARK: - LLMContextPreparationResult

    @Test("结果默认值为 estimated、未压缩、未降级")
    func resultDefaults() {
        let result = LLMContextPreparationResult(
            messages: [],
            estimatedInputTokens: 0,
            inputTokenLimit: 1_024
        )
        #expect(result.estimateSource == .estimated)
        #expect(result.didCompact == false)
        #expect(result.didFallback == false)
    }

    @Test("结果相等性比较所有字段")
    func resultEquatable() {
        let msg = Message(conversationID: UUID(), role: .user, content: "hi")
        let a = LLMContextPreparationResult(
            messages: [msg], estimatedInputTokens: 5, inputTokenLimit: 1_024,
            estimateSource: .exact, didCompact: true, didFallback: false
        )
        let b = LLMContextPreparationResult(
            messages: [msg], estimatedInputTokens: 5, inputTokenLimit: 1_024,
            estimateSource: .exact, didCompact: true, didFallback: false
        )
        let c = LLMContextPreparationResult(
            messages: [msg], estimatedInputTokens: 6, inputTokenLimit: 1_024
        )
        #expect(a == b)
        #expect(a != c)
    }

    // MARK: - LLMContextTokenEstimator

    @Test("空文本至少估算为 1 个 token")
    func estimateEmptyTextIsOne() {
        #expect(LLMContextTokenEstimator.estimate(text: "") == 1)
    }

    @Test("文本估算基于 UTF-8 字节数")
    func estimateTextUsesUTF8Bytes() {
        // "abc" = 3 bytes -> ceil(3/3) = 1
        #expect(LLMContextTokenEstimator.estimate(text: "abc") == 1)
        // "你好" = 6 bytes -> ceil(6/3) = 2
        #expect(LLMContextTokenEstimator.estimate(text: "你好") == 2)
    }

    @Test("空消息列表估算为零")
    func estimateEmptyMessagesIsZero() {
        #expect(LLMContextTokenEstimator.estimate(messages: []) == 0)
    }

    @Test("纯文本消息估算为内容加固定开销")
    func estimateBareMessage() {
        let message = Message(conversationID: UUID(), role: .user, content: "hi")
        // "hi" = 2 bytes -> 1 token; + 12 overhead = 13
        #expect(LLMContextTokenEstimator.estimate(message: message) == 13)
    }

    @Test("reasoning 内容并入估算")
    func estimateIncludesReasoning() {
        let bare = Message(conversationID: UUID(), role: .assistant, content: "答")
        let withReasoning = Message(
            conversationID: UUID(), role: .assistant, content: "答", reasoningContent: "推理"
        )
        #expect(LLMContextTokenEstimator.estimate(message: withReasoning)
            > LLMContextTokenEstimator.estimate(message: bare))
    }

    // MARK: - Default prepareContext extension & passthrough

    @Test("默认 prepareContext 返回消息、估算 token 并使用预算限额")
    func defaultPrepareContextBuildsResult() async {
        let messages = DefaultMessageManager()
        let provider = PassthroughLLMContextProvider(messages: messages)
        let conversationID = UUID()
        messages.insertMessage(
            Message(conversationID: conversationID, role: .user, content: "hello"),
            to: conversationID
        )

        let budget = LLMContextBudget(contextWindowTokens: 32_000)
        let request = LLMContextPreparationRequest(
            conversationID: conversationID, budget: budget
        )
        let result = await provider.prepareContext(for: request)

        #expect(result.messages.count == 1)
        #expect(result.messages[0].content == "hello")
        #expect(result.inputTokenLimit == budget.inputTokenLimit)
        #expect(result.estimatedInputTokens > 0)
        #expect(result.estimateSource == .estimated)
    }

    @Test("默认 prepareContext 在窗口未知时标记为 fallback 来源")
    func defaultPrepareContextMarksFallbackSource() async {
        let messages = DefaultMessageManager()
        let provider = PassthroughLLMContextProvider(messages: messages)
        let conversationID = UUID()
        messages.insertMessage(
            Message(conversationID: conversationID, role: .user, content: "hi"),
            to: conversationID
        )

        let budget = LLMContextBudget(contextWindowTokens: nil)
        let request = LLMContextPreparationRequest(conversationID: conversationID, budget: budget)
        let result = await provider.prepareContext(for: request)

        #expect(result.estimateSource == .fallback)
        #expect(result.didCompact == false)
        #expect(result.didFallback == false)
    }

    @Test("空会话的 prepareContext 返回空消息和零估算")
    func prepareContextWithEmptyConversation() async {
        let messages = DefaultMessageManager()
        let provider = PassthroughLLMContextProvider(messages: messages)
        let conversationID = UUID()
        let budget = LLMContextBudget(contextWindowTokens: 32_000)
        let request = LLMContextPreparationRequest(conversationID: conversationID, budget: budget)

        let result = await provider.prepareContext(for: request)
        #expect(result.messages.isEmpty)
        #expect(result.estimatedInputTokens == 0)
    }

    @Test("透传 Provider 对空会话返回空消息")
    func passthroughEmptyConversation() async {
        let messages = DefaultMessageManager()
        let provider = PassthroughLLMContextProvider(messages: messages)
        let result = await provider.messagesForLLM(in: UUID())
        #expect(result.isEmpty)
    }
}
