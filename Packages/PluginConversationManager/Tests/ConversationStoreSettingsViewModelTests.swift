import Foundation
import ProviderConversation
import ProviderMessage
import Testing
@testable import PluginConversationManager

@MainActor
@Suite(.serialized)
struct ConversationStoreSettingsViewModelTests {
    @Test func loadsPagesCountsMessagesAndSelectedConversation() async throws {
        let capability = StubConversationStoreCapability()
        let firstPage = makeConversations(count: 40)
        capability.initialPage = firstPage
        capability.nextPage = makeConversations(count: 5, offset: 40, childOf: firstPage[0].id)
        capability.selectedConversationID = firstPage[3].id
        capability.totalCount = 45
        capability.messageCounts = Dictionary(uniqueKeysWithValues: firstPage.map { ($0.id, 2) })
        for conversation in capability.nextPage {
            capability.messageCounts[conversation.id] = 2
        }
        capability.messageCounts[capability.selectedConversationID!] = 45
        let selectedMessages = (0..<45).map { index in
            Message(conversationID: capability.selectedConversationID!, role: .user, content: "message-\(index)")
        }
        capability.messagesByConversation[capability.selectedConversationID!] = selectedMessages
        capability.dailySeries = ConversationDailyCountSeries(points: [
            ConversationDailyCountPoint(day: Date(timeIntervalSince1970: 0), count: 3),
        ])
        let viewModel = ConversationStoreSettingsViewModel(capability: capability)

        await viewModel.loadInitialIfNeeded()

        #expect(viewModel.conversations == firstPage)
        #expect(viewModel.totalConversationCount == 45)
        #expect(!viewModel.isLoadingConversations)
        #expect(viewModel.hasMoreConversations)
        #expect(viewModel.selectedConversationID == firstPage[3].id)
        #expect(viewModel.selectedConversation?.id == firstPage[3].id)
        #expect(viewModel.conversationIDs == firstPage.map(\.id))
        #expect(viewModel.dailyCountSeries.peakCount == 3)
        #expect(viewModel.messageCounts[firstPage[3].id] == 45)

        await viewModel.loadMessages()
        #expect(viewModel.messagesForSelected == Array(selectedMessages.suffix(40)))

        await viewModel.loadMoreIfNeeded()
        #expect(viewModel.conversations.count == 45)
        #expect(viewModel.conversations.suffix(5).map(\.id) == capability.nextPage.map(\.id))
        #expect(!viewModel.hasMoreConversations)
        #expect(!viewModel.isLoadingMoreConversations)
        #expect(viewModel.selectedConversation?.id == firstPage[3].id)
        #expect(viewModel.messageCounts[capability.nextPage[0].id] == 2)
        #expect(capability.pageRequests.count == 2)
        #expect(capability.pageRequests[1].limit == 40)
        #expect(capability.pageRequests[1].beforeID == firstPage.last?.id)
        #expect(capability.pageRequests[1].beforeUpdatedAt == firstPage.last?.lastMessageAt)
        #expect(capability.pageRequests[1].includingChildConversations)

        await viewModel.loadInitialIfNeeded()
        await viewModel.loadMoreIfNeeded()
        #expect(capability.pageRequests.count == 2)
    }

    @Test func selectionFallsBackWhenMissingAndReloadsForStructuralEvents() async throws {
        let capability = StubConversationStoreCapability()
        let initial = makeConversations(count: 2)
        capability.initialPage = initial
        capability.selectedConversationID = UUID()
        let viewModel = ConversationStoreSettingsViewModel(capability: capability)
        await viewModel.loadInitialIfNeeded()
        #expect(viewModel.selectedConversationID == initial[0].id)

        viewModel.selectConversation(id: initial[1].id)
        viewModel.updateMigration(isActive: true)
        #expect(viewModel.selectedConversation?.id == initial[1].id)
        #expect(viewModel.isMigrationActive)
        viewModel.handleConversationEvent(.selected(initial[0].id))
        viewModel.handleConversationEvent(.markedActive(initial[0].id))
        viewModel.handleConversationEvent(.providerChanged(initial[0].id))
        viewModel.handleConversationEvent(.verbosityChanged(initial[0].id))
        viewModel.handleConversationEvent(.reasoningChanged(initial[0].id))
        viewModel.handleConversationEvent(.automationChanged(initial[0].id))
        viewModel.handleConversationEvent(.languageChanged(initial[0].id))
        #expect(capability.pageRequests.count == 1)

        capability.initialPage = [initial[0]]
        viewModel.handleConversationEvent(.updated(initial[1].id))
        for _ in 0..<20 where viewModel.conversations.count != 1 {
            await Task.yield()
        }

        #expect(capability.pageRequests.count == 2)
        #expect(viewModel.conversations.map(\.id) == [initial[0].id])
        #expect(viewModel.selectedConversationID == initial[0].id)
        #expect(!viewModel.isLoadingConversations)
        viewModel.updateMigration(isActive: false)
        #expect(!viewModel.isMigrationActive)
    }

    @Test func preferenceEventsRefreshCachedSummaries() async throws {
        let capability = StubConversationStoreCapability()
        let initial = makeConversations(count: 3)
        capability.initialPage = initial
        capability.summariesByID = Dictionary(uniqueKeysWithValues: initial.map { ($0.id, $0) })
        let viewModel = ConversationStoreSettingsViewModel(capability: capability)
        await viewModel.loadInitialIfNeeded()

        // Manager 在广播事件前已同步更新内存摘要，设置页应按 ID 拉取最新值。
        var updated = initial[1]
        updated.modelID = ConversationSummary(providerID: "openai", modelName: "gpt-4.1").modelID
        updated.verbosity = .brief
        updated.reasoningEffort = .high
        updated.automationLevel = .autonomous
        updated.language = .english
        capability.summariesByID[updated.id] = updated

        viewModel.handleConversationEvent(.providerChanged(updated.id))
        viewModel.handleConversationEvent(.verbosityChanged(updated.id))
        viewModel.handleConversationEvent(.reasoningChanged(updated.id))
        viewModel.handleConversationEvent(.automationChanged(updated.id))
        viewModel.handleConversationEvent(.languageChanged(updated.id))

        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: .seconds(1))
        while viewModel.conversations[1] != updated, clock.now < deadline {
            await Task.yield()
        }

        #expect(viewModel.conversations[1] == updated)
        #expect(viewModel.conversations[0] == initial[0])
        #expect(capability.pageRequests.count == 1, "偏好事件只更新单条摘要，不应整页重载")
    }

    @Test func reopeningRefreshesStaleSummaries() async throws {
        let capability = StubConversationStoreCapability()
        let initial = makeConversations(count: 3)
        capability.initialPage = initial
        capability.summariesByID = Dictionary(uniqueKeysWithValues: initial.map { ($0.id, $0) })
        let viewModel = ConversationStoreSettingsViewModel(capability: capability)
        await viewModel.loadInitialIfNeeded()

        // 设置页关闭期间 Manager 已更新偏好，但没有可观察的事件送达。
        var updated = initial[0]
        updated.verbosity = .brief
        capability.summariesByID[updated.id] = updated

        await viewModel.loadInitialIfNeeded()

        #expect(viewModel.conversations[0] == updated)
        #expect(capability.pageRequests.count == 1, "重进页面只刷新已加载摘要，不整页重载")
    }

    @Test func emptyLoadsFinishAndMessagesClearWithoutSelection() async {
        let capability = StubConversationStoreCapability()
        let viewModel = ConversationStoreSettingsViewModel(capability: capability)
        await viewModel.loadMessages()
        #expect(viewModel.messagesForSelected.isEmpty)

        await viewModel.loadInitialIfNeeded()
        #expect(viewModel.conversations.isEmpty)
        #expect(!viewModel.isLoadingConversations)
        #expect(viewModel.totalConversationCount == 0)
        await viewModel.loadInitialIfNeeded()
        #expect(capability.pageRequests.count == 1)
    }

    @Test func loadMoreDoesNotAppendStalePageAfterReload() async throws {
        let capability = StubConversationStoreCapability()
        let firstPage = makeConversations(count: 40)
        capability.initialPage = firstPage
        capability.totalCount = 45
        let viewModel = ConversationStoreSettingsViewModel(capability: capability)

        await viewModel.loadInitialIfNeeded()
        #expect(viewModel.conversations.count == 40)
        #expect(viewModel.hasMoreConversations)

        capability.nextPage = makeConversations(count: 5, offset: 100)
        capability.nextPageDelay = .milliseconds(400)

        let more = Task { await viewModel.loadMoreIfNeeded() }
        try await Task.sleep(for: .milliseconds(50))

        let refreshed = makeConversations(count: 40, offset: 200)
        capability.initialPage = refreshed
        await viewModel.reloadConversations()

        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: .seconds(1))
        while viewModel.conversations.first?.id != refreshed.first?.id, clock.now < deadline {
            try await Task.sleep(for: .milliseconds(5))
        }

        await more.value

        #expect(
            viewModel.conversations.map(\.id) == refreshed.map(\.id),
            "旧分页不能追加到刷新后的列表"
        )
    }

    @Test func messageChangeRefreshesCountAndSelectedPreview() async throws {
        let capability = StubConversationStoreCapability()
        let initial = makeConversations(count: 2)
        let selectedID = initial[0].id
        let backgroundID = initial[1].id
        capability.initialPage = initial
        capability.selectedConversationID = selectedID
        capability.messageCounts = [selectedID: 2, backgroundID: 1]
        capability.messagesByConversation[selectedID] = [
            Message(conversationID: selectedID, role: .user, content: "m0"),
            Message(conversationID: selectedID, role: .assistant, content: "m1"),
        ]
        let viewModel = ConversationStoreSettingsViewModel(capability: capability)
        await viewModel.loadInitialIfNeeded()
        await viewModel.loadMessages()
        #expect(viewModel.messageCounts[selectedID] == 2)
        #expect(viewModel.messagesForSelected.count == 2)

        // 新消息不会改变会话摘要身份，只能靠消息变化事件驱动刷新。
        let inserted = Message(conversationID: selectedID, role: .assistant, content: "m2")
        capability.messageCounts[selectedID] = 3
        capability.messagesByConversation[selectedID]?.append(inserted)
        viewModel.handleMessageChange(.inserted(inserted, conversationID: selectedID))

        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: .seconds(1))
        while viewModel.messagesForSelected.count != 3, clock.now < deadline {
            try await Task.sleep(for: .milliseconds(10))
        }

        #expect(viewModel.messageCounts[selectedID] == 3)
        #expect(viewModel.messagesForSelected.last?.content == "m2")

        // 非选中会话：只更新计数，不刷新当前预览。
        viewModel.handleMessageChange(.updated(conversationID: backgroundID))
        #expect(viewModel.messageCounts[backgroundID] == 1)
        #expect(viewModel.messagesForSelected.count == 3)
    }

    private func makeConversations(count: Int, offset: Int = 0, childOf parentID: UUID? = nil) -> [ConversationSummary] {
        (offset..<(offset + count)).map { index in
            let date = Date(timeIntervalSince1970: TimeInterval(index + 1))
            return ConversationSummary(
                id: UUID(),
                title: "Conversation \(index)",
                createdAt: date,
                lastMessageAt: date,
                parentConversationID: parentID
            )
        }
    }
}

@MainActor
final class StubConversationStoreCapability: ConversationStoreCapability {
    struct PageRequest {
        let limit: Int
        let beforeUpdatedAt: Date?
        let beforeID: UUID?
        let includingChildConversations: Bool
    }

    var selectedConversationID: UUID?
    var initialPage: [ConversationSummary] = []
    var nextPage: [ConversationSummary] = []
    var totalCount = 0
    var dailySeries = ConversationDailyCountSeries(points: [])
    var messagesByConversation: [UUID: [Message]] = [:]
    var messageCounts: [UUID: Int] = [:]
    var summariesByID: [UUID: ConversationSummary] = [:]
    var pageRequests: [PageRequest] = []
    /// 首屏/刷新页与翻页的注入延迟，用于构造「旧分页晚到」场景。
    var pageDelay: Duration?
    var nextPageDelay: Duration?
    private var conversationObserver: ((ConversationEvent) -> Void)?
    private var messageChangeObserver: ((MessageChange) -> Void)?

    func fetchConversationPage(
        limit: Int,
        beforeUpdatedAt: Date?,
        beforeID: UUID?,
        includingChildConversations: Bool
    ) async -> [ConversationSummary] {
        pageRequests.append(PageRequest(
            limit: limit,
            beforeUpdatedAt: beforeUpdatedAt,
            beforeID: beforeID,
            includingChildConversations: includingChildConversations
        ))
        let delay = beforeID == nil ? pageDelay : nextPageDelay
        if let delay { try? await Task.sleep(for: delay) }
        return beforeID == nil ? initialPage : nextPage
    }

    func conversationCount(projectPath: String?, includingChildConversations: Bool) async -> Int {
        totalCount
    }

    func fetchDailyCountSeries() async -> ConversationDailyCountSeries {
        dailySeries
    }

    func messagesSnapshot(in conversationID: UUID) async -> [Message] {
        messagesByConversation[conversationID] ?? []
    }

    func fetchConversationSummary(id: UUID) async -> ConversationSummary? {
        summariesByID[id]
    }

    func messageCount(for conversationID: UUID) -> Int {
        messageCounts[conversationID] ?? 0
    }

    func addConversationObserver(_ callback: @escaping (ConversationEvent) -> Void) -> any ConversationObserverHandle {
        conversationObserver = callback
        return NoopConversationObserverHandle()
    }

    func emit(_ event: ConversationEvent) {
        conversationObserver?(event)
    }

    func addMessageChangeObserver(_ callback: @escaping (MessageChange) -> Void) -> any MessageChangeObserverHandle {
        messageChangeObserver = callback
        return NoopMessageChangeObserverHandle()
    }

    func emitMessageChange(_ change: MessageChange) {
        messageChangeObserver?(change)
    }
}
