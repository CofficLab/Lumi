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
    let dataDirectory = FileManager.default.temporaryDirectory
    var initialPage: [ConversationSummary] = []
    var nextPage: [ConversationSummary] = []
    var totalCount = 0
    var dailySeries = ConversationDailyCountSeries(points: [])
    var messagesByConversation: [UUID: [Message]] = [:]
    var messageCounts: [UUID: Int] = [:]
    var pageRequests: [PageRequest] = []
    private var conversationObserver: ((ConversationEvent) -> Void)?

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
}
