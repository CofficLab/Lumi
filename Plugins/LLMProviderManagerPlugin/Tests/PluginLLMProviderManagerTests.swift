import Foundation
import LumiKernel
import Testing
@testable import LLMProviderManagerPlugin

// MARK: - ModelCheckState

@Test func modelCheckStateDefaultsAreNotChecked() {
    let s = ModelCheckState()
    #expect(s.phase == .notChecked)
    #expect(s.result == nil)
    #expect(s.isChecking == false)
    #expect(s.isAvailable == false)
    #expect(s.failure == nil)
    #expect(s.isReconfigurableFailure == false)
}

@Test func modelCheckStateAvailableHasNoFailure() {
    let s = ModelCheckState(result: .available)
    #expect(s.isAvailable)
    #expect(s.failure == nil)
    #expect(s.isReconfigurableFailure == false)
}

@Test func modelCheckStateUnsupportedFailureIsNotReconfigurable() {
    let failure = LumiLLMFailureDetail(
        summary: "not in plan",
        reason: .unsupportedModel
    )
    let s = ModelCheckState(result: .unavailable(failure))
    #expect(s.failure?.reason == .unsupportedModel)
    #expect(s.isReconfigurableFailure == false)
}

@Test func modelCheckStateReconfigurableFailure() {
    let failure = LumiLLMFailureDetail(summary: "401 unauthorized")
    let s = ModelCheckState(result: .unavailable(failure))
    #expect(s.isReconfigurableFailure)
}

@Test func modelCheckStateIsEquatable() {
    #expect(ModelCheckState() == ModelCheckState())
    #expect(
        ModelCheckState(phase: .checking)
            != ModelCheckState(phase: .notChecked)
    )
}

// MARK: - ModelAvailabilityState

@MainActor
@Test func modelAvailabilityStateStartsEmpty() {
    let state = ModelAvailabilityState()
    #expect(state.states.isEmpty)
    #expect(state.checkingProviderIDs.isEmpty)
    #expect(state.state(providerId: "any", modelId: "any") == ModelCheckState())
}

@MainActor
@Test func modelAvailabilityStateCheckProviderUpdatesState() async {
    let state = ModelAvailabilityState()
    let info = MockLLMProvider.info
    let provider = MockLLMProvider()

    await state.checkProvider(info, providerInstance: provider)

    #expect(state.checkingProviderIDs.isEmpty)
    #expect(state.availableCount(for: info) == 2)
    #expect(state.isProviderAvailable(info))

    for model in info.availableModels {
        let s = state.state(providerId: info.id, modelId: model)
        #expect(s.isAvailable)
        #expect(s.phase == .notChecked)
    }
}

@MainActor
@Test func modelAvailabilityStateCapturesFailures() async {
    let state = ModelAvailabilityState()
    let info = MockLLMProvider.info
    let provider = MockLLMProvider(
        resultForModel: { model in
            model == "mock-model-a"
                ? .available
                : .unavailable(.message("401 unauthorized"))
        }
    )

    await state.checkProvider(info, providerInstance: provider)

    // 至少一个可用,provider 算"可用"(UI 显示 1/2 绿)
    #expect(state.availableCount(for: info) == 1)
    #expect(state.isProviderAvailable(info))

    // 但失败原因应当被捕获,"重配" 入口出现
    let failure = state.firstReconfigurableFailure(for: info)
    #expect(failure?.logSummary == "401 unauthorized")
}

@MainActor
@Test func modelAvailabilityStateAllFailedMeansUnavailable() async {
    let state = ModelAvailabilityState()
    let info = MockLLMProvider.info
    let provider = MockLLMProvider(
        resultForModel: { _ in .unavailable(.message("network timeout")) }
    )

    await state.checkProvider(info, providerInstance: provider)

    #expect(state.availableCount(for: info) == 0)
    #expect(!state.isProviderAvailable(info))
    #expect(state.firstReconfigurableFailure(for: info)?.logSummary == "network timeout")
}

@MainActor
@Test func modelAvailabilityStateIgnoresUnsupportedModelInReconfigurable() async {
    let state = ModelAvailabilityState()
    let info = MockLLMProvider.info
    let provider = MockLLMProvider(
        resultForModel: { _ in
            .unavailable(LumiLLMFailureDetail(
                summary: "model not in plan",
                reason: .unsupportedModel
            ))
        }
    )

    await state.checkProvider(info, providerInstance: provider)

    // 全部是 unsupportedModel,不算"可重配"
    #expect(state.firstReconfigurableFailure(for: info) == nil)
    #expect(!state.isProviderAvailable(info))
}

@MainActor
@Test func modelAvailabilityStateCheckAllIteratesProviders() async {
    let state = ModelAvailabilityState()
    let infoA = MockLLMProvider.info
    let infoB = LumiLLMProviderInfo(
        id: "mock-b",
        displayName: "Mock B",
        description: "second mock",
        defaultModel: "mock-b-1",
        availableModels: ["mock-b-1"],
        websiteURL: URL(string: "https://example.com")!
    )
    let providerA = MockLLMProvider()
    let providerB = MockLLMProvider()

    await state.checkAll([
        (info: infoA, instance: providerA),
        (info: infoB, instance: providerB),
    ])

    #expect(state.availableCount(for: infoA) == 2)
    #expect(state.availableCount(for: infoB) == 1)
    #expect(state.checkingProviderIDs.isEmpty)
}

@MainActor
@Test func modelAvailabilityStateResetClearsProvider() async {
    let state = ModelAvailabilityState()
    let info = MockLLMProvider.info
    let provider = MockLLMProvider()

    await state.checkProvider(info, providerInstance: provider)
    #expect(state.availableCount(for: info) == 2)

    state.reset(info.id)
    #expect(state.availableCount(for: info) == 0)
    #expect(!state.isChecking(providerId: info.id))
}

// MARK: - Mock LLM Provider

private struct MockLLMProvider: LumiLLMProvider {
    static let info = LumiLLMProviderInfo(
        id: "mock",
        displayName: "Mock",
        description: "Mock provider",
        defaultModel: "mock-model-a",
        availableModels: ["mock-model-a", "mock-model-b"],
        websiteURL: URL(string: "https://example.com")!
    )

    let resultForModel: @Sendable (String) -> LumiModelAvailabilityResult

    init(resultForModel: @escaping @Sendable (String) -> LumiModelAvailabilityResult = { _ in .available }) {
        self.resultForModel = resultForModel
    }

    func lumiResolveAPIKey() throws -> String { "" }
    func hasApiKey() -> Bool { false }
    func getApiKey() -> String { "" }
    func setApiKey(_ apiKey: String) {}
    func removeApiKey() {}

    func send(_ request: LumiLLMRequest) async throws -> LumiChatMessage {
        LumiChatMessage(conversationID: UUID(), role: .assistant, content: "ok")
    }

    func sendStreaming(
        _ request: LumiLLMRequest,
        onChunk: @escaping @Sendable (LumiStreamChunk) async -> Void
    ) async throws -> LumiChatMessage {
        LumiChatMessage(conversationID: UUID(), role: .assistant, content: "ok")
    }

    func checkAvailability(model: String) async -> LumiModelAvailabilityResult {
        resultForModel(model)
    }

    func providerStatus() -> LumiLLMProviderStatus? {
        nil
    }

    func retryDisposition(for error: Error, context: LumiLLMRetryContext) -> LumiLLMErrorDisposition {
        .nonRetryable
    }

    func errorRenderKind(for error: Error) -> String? {
        nil
    }

    func makeErrorMessage(
        conversationID: UUID,
        request: LumiLLMRequest,
        error: Error,
        disposition: LumiLLMErrorDisposition
    ) -> LumiChatMessage {
        LumiChatMessage(conversationID: conversationID, role: .assistant, content: "error")
    }
}
