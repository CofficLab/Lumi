import Foundation
import LumiCoreKit
import LumiCoreKit
import Testing
@testable import ModelSelectorPlugin

@MainActor
@Test func chatSectionToolbarItemsRequireVisibleChatSection() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("ModelSelectorPluginTests-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let chatService = try ChatService(configuration: .coreDatabase(directory: directory), agentToolComponent: AgentToolComponent())

    let hiddenContext = LumiPluginContext(
        activeSectionID: "chat",
        activeSectionTitle: "Chat",
        chatSection: .wide,
        isChatSectionVisible: false,
        dependencies: LumiPluginDependencies { dependencies in
            dependencies.register(LumiChatServicing.self, chatService)
        }
    )
    #expect(ModelSelectorPlugin.chatSectionToolbarItems(lumiCore: hiddenContext).isEmpty)

    let shownContext = LumiPluginContext(
        activeSectionID: "chat",
        activeSectionTitle: "Chat",
        chatSection: .wide,
        isChatSectionVisible: true,
        dependencies: LumiPluginDependencies { dependencies in
            dependencies.register(LumiChatServicing.self, chatService)
        }
    )
    #expect(ModelSelectorPlugin.chatSectionToolbarItems(lumiCore: shownContext).count == 1)
    #expect(ModelSelectorPlugin.chatSectionToolbarItems(lumiCore: shownContext).first?.placement == .leading)
}

@MainActor
@Test func chatSectionToolbarItemsRequireChatService() {
    let context = LumiPluginContext(
        activeSectionID: "chat",
        activeSectionTitle: "Chat",
        chatSection: .wide,
        isChatSectionVisible: true
    )
    #expect(ModelSelectorPlugin.chatSectionToolbarItems(lumiCore: context).isEmpty)
}

@MainActor
@Test func chatSectionToolbarBarItemsRequireVisibleChatSection() throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("ModelSelectorPluginTests-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let chatService = try ChatService(configuration: .coreDatabase(directory: directory), agentToolComponent: AgentToolComponent())

    let hiddenContext = LumiPluginContext(
        activeSectionID: "chat",
        activeSectionTitle: "Chat",
        chatSection: .wide,
        isChatSectionVisible: false,
        dependencies: LumiPluginDependencies { dependencies in
            dependencies.register(LumiChatServicing.self, chatService)
        }
    )
    #expect(ModelSelectorPlugin.chatSectionToolbarBarItems(lumiCore: hiddenContext).isEmpty)

    let shownContext = LumiPluginContext(
        activeSectionID: "chat",
        activeSectionTitle: "Chat",
        chatSection: .wide,
        isChatSectionVisible: true,
        dependencies: LumiPluginDependencies { dependencies in
            dependencies.register(LumiChatServicing.self, chatService)
        }
    )
    #expect(ModelSelectorPlugin.chatSectionToolbarBarItems(context: shownContext).count == 1)
    #expect(ModelSelectorPlugin.chatSectionToolbarBarItems(context: shownContext).first?.id == "com.coffic.lumi.plugin.model-selector.tps")
}

@MainActor
@Test func switchModelToolUpdatesConversationPreference() async throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("ModelSelectorPluginTests-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let chatService = try ChatService(configuration: .coreDatabase(directory: directory), agentToolComponent: AgentToolComponent())
    let provider = MockLLMProvider()
    chatService.registerProviders([provider])

    let conversationID = chatService.createConversation(title: "Test")
    chatService.selectConversation(id: conversationID)

    let tool = SwitchModelTool(chatService: chatService)
    let result = try await tool.execute(
        arguments: [
            "providerId": .string("mock"),
            "modelId": .string("mock-model-b")
        ],
        context: LumiToolExecutionContext(
            conversationID: conversationID,
            toolCallID: "tool-call",
            toolName: SwitchModelTool.info.id
        )
    )

    #expect(result.contains("✅"))
    #expect(chatService.providerID(for: conversationID) == "mock")
    #expect(chatService.modelName(for: conversationID) == "mock-model-b")
    #expect(chatService.routingMode == .manual)
}

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

    // 至少一个可用，provider 算"可用"（UI 显示 1/2 绿）
    #expect(state.availableCount(for: info) == 1)
    #expect(state.isProviderAvailable(info))

    // 但失败原因应当被捕获，"重配" 入口出现
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

    // 全部是 unsupportedModel，不算"可重配"
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

// MARK: - Agent Tools

@MainActor
@Test func checkModelAvailabilityToolReportsAvailable() async throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("ModelSelectorPluginTests-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let chatService = try ChatService(configuration: .coreDatabase(directory: directory), agentToolComponent: AgentToolComponent())
    chatService.registerProviders([MockLLMProvider()])

    let tool = CheckModelAvailabilityTool(chatService: chatService)
    let result = try await tool.execute(
        arguments: [
            "providerId": .string("mock"),
            "modelId": .string("mock-model-a"),
        ],
        context: LumiToolExecutionContext(
            conversationID: UUID(),
            toolCallID: "tc",
            toolName: CheckModelAvailabilityTool.info.id
        )
    )

    #expect(result.contains("✅"))
    #expect(result.contains("`mock`"))
    #expect(result.contains("`mock-model-a`"))
}

@MainActor
@Test func checkModelAvailabilityToolReportsFailure() async throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("ModelSelectorPluginTests-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let chatService = try ChatService(configuration: .coreDatabase(directory: directory), agentToolComponent: AgentToolComponent())
    let provider = MockLLMProvider(
        resultForModel: { _ in .unavailable(.message("HTTP 401 unauthorized")) }
    )
    chatService.registerProviders([provider])

    let tool = CheckModelAvailabilityTool(chatService: chatService)
    let result = try await tool.execute(
        arguments: [
            "providerId": .string("mock"),
            "modelId": .string("mock-model-a"),
        ],
        context: LumiToolExecutionContext(
            conversationID: UUID(),
            toolCallID: "tc",
            toolName: CheckModelAvailabilityTool.info.id
        )
    )

    #expect(result.contains("❌"))
    #expect(result.contains("HTTP 401 unauthorized"))
}

@MainActor
@Test func checkModelAvailabilityToolReportsMissingProvider() async throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("ModelSelectorPluginTests-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let chatService = try ChatService(configuration: .coreDatabase(directory: directory), agentToolComponent: AgentToolComponent())
    let tool = CheckModelAvailabilityTool(chatService: chatService)

    let result = try await tool.execute(
        arguments: [
            "providerId": .string("nonexistent"),
            "modelId": .string("any"),
        ],
        context: LumiToolExecutionContext(
            conversationID: UUID(),
            toolCallID: "tc",
            toolName: CheckModelAvailabilityTool.info.id
        )
    )

    #expect(result.contains("❌"))
    #expect(result.contains("未注册"))
}

@MainActor
@Test func listAvailableModelsToolReturnsAvailableModels() async throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("ModelSelectorPluginTests-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let chatService = try ChatService(configuration: .coreDatabase(directory: directory), agentToolComponent: AgentToolComponent())
    let provider = MockLLMProvider(
        resultForModel: { model in
            model == "mock-model-a" ? .available : .unavailable(.message("nope"))
        }
    )
    chatService.registerProviders([provider])

    let tool = ListAvailableModelsTool(chatService: chatService)
    let result = try await tool.execute(
        arguments: [:],
        context: LumiToolExecutionContext(
            conversationID: UUID(),
            toolCallID: "tc",
            toolName: ListAvailableModelsTool.info.id
        )
    )

    #expect(result.contains("可用 LLM"))
    #expect(result.contains("`mock-model-a`"))
    #expect(!result.contains("`mock-model-b`"))
}

@MainActor
@Test func listAvailableModelsToolHandlesEmptyRegistry() async throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("ModelSelectorPluginTests-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let chatService = try ChatService(configuration: .coreDatabase(directory: directory), agentToolComponent: AgentToolComponent())
    let tool = ListAvailableModelsTool(chatService: chatService)

    let result = try await tool.execute(
        arguments: [:],
        context: LumiToolExecutionContext(
            conversationID: UUID(),
            toolCallID: "tc",
            toolName: ListAvailableModelsTool.info.id
        )
    )

    #expect(result.contains("未注册任何 LLM 供应商"))
}

@MainActor
@Test func listAvailableModelsToolFiltersByProvider() async throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("ModelSelectorPluginTests-\(UUID().uuidString)", isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }

    let chatService = try ChatService(configuration: .coreDatabase(directory: directory), agentToolComponent: AgentToolComponent())
    chatService.registerProviders([MockLLMProvider()])

    let tool = ListAvailableModelsTool(chatService: chatService)

    // 过滤到一个不存在的 id：应给出已注册列表
    let missResult = try await tool.execute(
        arguments: ["providerId": .string("nonexistent")],
        context: LumiToolExecutionContext(
            conversationID: UUID(),
            toolCallID: "tc",
            toolName: ListAvailableModelsTool.info.id
        )
    )
    #expect(missResult.contains("未找到供应商"))
    #expect(missResult.contains("`mock`"))

    // 过滤到 mock：应能列出
    let hitResult = try await tool.execute(
        arguments: ["providerId": .string("mock")],
        context: LumiToolExecutionContext(
            conversationID: UUID(),
            toolCallID: "tc",
            toolName: ListAvailableModelsTool.info.id
        )
    )
    #expect(hitResult.contains("Mock"))
    #expect(hitResult.contains("`mock-model-a`"))
}

// MARK: - Mocks

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

    func send(_ request: LumiLLMRequest) async throws -> LumiChatMessage {
        LumiChatMessage(conversationID: UUID(), role: .assistant, content: "ok")
    }

    func checkAvailability(model: String) async -> LumiModelAvailabilityResult {
        resultForModel(model)
    }

    func providerStatus() -> LumiLLMProviderStatus? {
        nil
    }
}
