import Foundation
import HttpKit
import LumiKernel
import LumiKernel
import SwiftData
import Testing
@testable import RequestLogPlugin

@Test func pluginPolicyIsAlwaysOn() {
    #expect(RequestLogPlugin.policy == .alwaysOn)
    #expect(RequestLogPlugin.policy.isConfigurable == false)
}

@MainActor
@Test func requestLogPluginContributesSendMiddleware() {
    let context = LumiPluginContext(activeSectionID: ChatPanelSection.id, activeSectionTitle: "Chat")
    let middlewares = RequestLogPlugin.sendMiddlewares(context: context)
    #expect(middlewares.count == 1)
}

@MainActor
@Test func requestLogPluginContributesStatusBarOnChatPanel() {
    let context = LumiPluginContext(
        activeSectionID: "editor",
        activeSectionTitle: "Editor",
        chatSection: .wide,
        isChatSectionVisible: true,
        dependencies: LumiPluginDependencies { dependencies in
            dependencies.register((any LumiChatServicing).self, MockChatService())
        }
    )
    let items = RequestLogPlugin.statusBarItems(context: context)
    #expect(items.count == 1)
    #expect(items.first?.systemImage == "list.clipboard.fill")
}

@MainActor
@Test func requestLogPluginHidesStatusBarOutsideChatPanel() {
    let context = LumiPluginContext(
        activeSectionID: "editor",
        activeSectionTitle: "Editor",
        chatSection: .wide,
        isChatSectionVisible: false
    )
    #expect(RequestLogPlugin.statusBarItems(context: context).isEmpty)
}

@Test func requestLogSummaryStoreKeepsRecentEntries() {
    RequestLogSummaryStore.append(
        RequestLogSummaryStore.Entry(
            conversationID: UUID(),
            messageCount: 3,
            systemPromptLength: 120
        )
    )

    let entries = RequestLogSummaryStore.allEntries()
    #expect(entries.count == 1)
    #expect(entries.first?.messageCount == 3)
    #expect(entries.first?.systemPromptLength == 120)
}

@Test func historyStoreRecoversWhenDatabaseDirectoryIsBlocked() throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("request-log-store-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }

    let blockedDirectory = root.appendingPathComponent("RequestLogPlugin", isDirectory: true)
    try "not a directory".write(to: blockedDirectory, atomically: true, encoding: .utf8)

    let container = RequestLogHistoryManager.makeContainer(databaseRootURL: root)
    let context = ModelContext(container)
    let item = RequestLogItem(
        requestId: UUID(),
        timestamp: Date(),
        method: "GET",
        requestURL: "https://example.com",
        requestHeadersJSON: nil,
        requestBodySize: 0,
        requestBodyPreview: nil,
        responseStatusCode: 200,
        responseHeadersJSON: nil,
        responseBodySize: 2,
        responseBodyPreview: "OK",
        isSuccess: true,
        errorMessage: nil,
        duration: 0.1
    )

    context.insert(item)
    try context.save()

    let fetched = try context.fetch(FetchDescriptor<RequestLogItem>())
    #expect(fetched.count == 1)
    #expect(fetched.first?.requestURL == "https://example.com")
}

@Test func addReportsSuccessfulPersistence() async throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("request-log-add-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }

    let manager = RequestLogHistoryManager(databaseRootURL: root)
    let metadata = HTTPRequestMetadata(
        requestId: UUID(),
        method: "POST",
        url: "https://example.com/chat",
        requestHeaders: ["Content-Type": "application/json"],
        requestBodySizeBytes: 2,
        requestBodyPreview: "{}",
        sentAt: Date(),
        responseStatusCode: 200,
        responseHeaders: ["Content-Type": "application/json"],
        responseBodySizeBytes: 11,
        responseBodyPreview: "{\"ok\":true}",
        duration: 0.25
    )

    let saved = await manager.add(metadata: metadata)
    let latest = await manager.getLatest(limit: 10)

    #expect(saved)
    #expect(latest.count == 1)
    #expect(latest.first?.requestURL == "https://example.com/chat")
    #expect(latest.first?.method == "POST")
}

@Test func requestLogQueriesClampPaginationBeforeFetching() async throws {
    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("request-log-pagination-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }

    let manager = RequestLogHistoryManager(databaseRootURL: root)
    for index in 0..<3 {
        let metadata = HTTPRequestMetadata(
            requestId: UUID(),
            method: "GET",
            url: "https://example.com/\(index)",
            requestHeaders: [:],
            requestBodySizeBytes: 0,
            requestBodyPreview: nil,
            sentAt: Date().addingTimeInterval(Double(index)),
            responseStatusCode: index == 0 ? 500 : 200,
            responseHeaders: [:],
            responseBodySizeBytes: nil,
            responseBodyPreview: nil,
            duration: 0.1,
            error: index == 0
                ? NSError(domain: "RequestLogTests", code: 500)
                : nil
        )
        _ = await manager.add(metadata: metadata)
    }

    let latest = await manager.getLatest(limit: -10, offset: -50)
    let failed = await manager.query(isSuccess: false, limit: 0, offset: -1)

    #expect(latest.count == 1)
    #expect(latest.first?.requestURL == "https://example.com/2")
    #expect(failed.count == 1)
    #expect(failed.first?.responseStatusCode == 500)
}

@MainActor
@Test func requestLogBrowserUsesFilteredCountsForPagination() {
    let viewModel = RequestLogBrowserViewModel()
    viewModel.stats = RequestLogStats(
        totalRequests: 125,
        successCount: 120,
        failedCount: 5
    )

    #expect(viewModel.totalPages == 3)

    viewModel.filterSuccess = false
    #expect(viewModel.totalPages == 1)

    viewModel.filterSuccess = true
    #expect(viewModel.totalPages == 3)
}

@MainActor
@Test func requestLogBrowserIgnoresStaleItemsAfterFilterSwitch() async {
    let staleItem = RequestLogItemDTO.fixture(requestURL: "https://example.com/stale", isSuccess: true)
    let currentItem = RequestLogItemDTO.fixture(requestURL: "https://example.com/current", isSuccess: false)
    let history = MockRequestLogHistory(
        stats: RequestLogStats(totalRequests: 2, successCount: 1, failedCount: 1),
        latestItems: [staleItem],
        failedItems: [currentItem]
    )
    history.latestDelayNanoseconds = 100_000_000

    let viewModel = RequestLogBrowserViewModel(history: history)
    let staleReload = Task { await viewModel.reload() }
    try? await Task.sleep(nanoseconds: 10_000_000)

    viewModel.setFilterSuccess(false)
    await viewModel.reload()
    await staleReload.value

    #expect(viewModel.filterSuccess == false)
    #expect(viewModel.items.map(\.requestURL) == ["https://example.com/current"])
}

private final class MockChatService: LumiChatServicing {
    var conversations: [LumiConversationSummary] = []
    var selectedConversationID: UUID?
    var providerInfos: [LumiLLMProviderInfo] = []
    var selectedProviderID: String?
    var selectedModel: String?
    var messageRenderers: [LumiMessageRendererItem] = []
    var revision = 0
    var agentTools: [any LumiAgentTool] = []
    var pendingMessages: [LumiPendingMessage] = []
    var routingMode: LumiModelRoutingMode = .manual
    var pendingToolConfirmation: LumiPendingToolConfirmation?

    func isSending(for conversationID: UUID?) -> Bool { false }
    func createConversation(title: String?) -> UUID { UUID() }
    func createConversation(title: String?, projectPath: String?, language: LumiConversationLanguage?) -> UUID { UUID() }
    func selectConversation(id: UUID) {}
    func deleteConversation(id: UUID) {}
    func updateConversationTitle(_ title: String, for conversationID: UUID) -> Bool { false }
    func setConversationProjectPath(_ projectPath: String?, for conversationID: UUID) -> Bool { false }
    func selectProvider(id: String, model: String?) {}
    func selectProvider(id: String, model: String?, for conversationID: UUID?) {}
    func providerID(for conversationID: UUID?) -> String? { nil }
    func modelName(for conversationID: UUID?) -> String? { nil }
    func setRoutingMode(_ mode: LumiModelRoutingMode) {}
    func language(for conversationID: UUID?) -> LumiConversationLanguage { .chinese }
    func setLanguage(_ language: LumiConversationLanguage, for conversationID: UUID?) {}
    func automationLevel(for conversationID: UUID?) -> LumiAutomationLevel { .chat }
    func setAutomationLevel(_ automationLevel: LumiAutomationLevel, for conversationID: UUID?) {}
    func verbosity(for conversationID: UUID?) -> LumiResponseVerbosity { .standard }
    func setVerbosity(_ verbosity: LumiResponseVerbosity, for conversationID: UUID?) {}
    func registerToolService(_ toolService: (any LumiToolServicing)?) {}
    func renderer(for message: LumiChatMessage) -> LumiMessageRendererItem? { nil }
    func messages(for conversationID: UUID) -> [LumiChatMessage] { [] }
    func displayMessages(for conversationID: UUID) -> [LumiChatMessage] { [] }
    func transientStatusMessage(for conversationID: UUID) -> LumiChatMessage? { nil }
    func visibleMessages(for conversationID: UUID, limit: Int, beforeMessageID: UUID?) -> [LumiChatMessage] { [] }
    func hasEarlierMessages(for conversationID: UUID, beforeMessageID: UUID?) -> Bool { false }
    func enqueueText(_ text: String, in conversationID: UUID?) {}
    func enqueueText(_ text: String, imageAttachments: [LumiImageAttachment], in conversationID: UUID?) {}
    func continueTurn(in conversationID: UUID) {}
    func cancelSending(for conversationID: UUID?) {}
    func approvePendingTool() {}
    func rejectPendingTool() {}
    func removePendingMessage(id: UUID) {}
    func deleteMessage(id: UUID, in conversationID: UUID) {}
    func resendMessage(id: UUID, in conversationID: UUID) async {}
    func send(_ text: String, in conversationID: UUID?) async {}
    func generateEphemeralCompletion(messages: [LumiChatMessage], model: String, conversationID: UUID) async throws -> LumiChatMessage {
        LumiChatMessage(conversationID: conversationID, role: .assistant, content: "")
    }
    func conversationContextUsage(for conversationID: UUID) -> LumiConversationContextUsage {
        .init(currentTokens: 0, limit: 0)
    }
}

private final class MockRequestLogHistory: RequestLogHistoryQuerying, @unchecked Sendable {
    var stats: RequestLogStats
    var latestItems: [RequestLogItemDTO]
    var successItems: [RequestLogItemDTO]
    var failedItems: [RequestLogItemDTO]
    var latestDelayNanoseconds: UInt64 = 0
    var queryDelayNanoseconds: UInt64 = 0

    init(
        stats: RequestLogStats = .init(),
        latestItems: [RequestLogItemDTO] = [],
        successItems: [RequestLogItemDTO] = [],
        failedItems: [RequestLogItemDTO] = []
    ) {
        self.stats = stats
        self.latestItems = latestItems
        self.successItems = successItems
        self.failedItems = failedItems
    }

    func getStats() async -> RequestLogStats {
        stats
    }

    func getLatest(limit: Int, offset: Int) async -> [RequestLogItemDTO] {
        if latestDelayNanoseconds > 0 {
            try? await Task.sleep(nanoseconds: latestDelayNanoseconds)
        }
        return latestItems
    }

    func query(isSuccess: Bool, limit: Int, offset: Int) async -> [RequestLogItemDTO] {
        if queryDelayNanoseconds > 0 {
            try? await Task.sleep(nanoseconds: queryDelayNanoseconds)
        }
        return isSuccess ? successItems : failedItems
    }
}

private extension RequestLogItemDTO {
    static func fixture(
        requestURL: String,
        isSuccess: Bool
    ) -> RequestLogItemDTO {
        RequestLogItemDTO(from: RequestLogItem(
            requestId: UUID(),
            timestamp: Date(),
            method: "GET",
            requestURL: requestURL,
            requestHeadersJSON: nil,
            requestBodySize: 0,
            requestBodyPreview: nil,
            responseStatusCode: isSuccess ? 200 : 500,
            responseHeadersJSON: nil,
            responseBodySize: nil,
            responseBodyPreview: nil,
            isSuccess: isSuccess,
            errorMessage: isSuccess ? nil : "failed",
            duration: 0.1
        ))
    }
}
