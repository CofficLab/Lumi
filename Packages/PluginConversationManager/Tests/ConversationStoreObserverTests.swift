import Foundation
import ProviderConversation
import Testing
@testable import PluginConversationManager

@MainActor
@Suite(.serialized)
struct ConversationStoreObserverTests {
    @Test func forwardsEventsAndMigrationStateUntilCancelled() async {
        let capability = StubConversationStoreCapability()
        let first = ConversationSummary(title: "first")
        let second = ConversationSummary(title: "second")
        let third = ConversationSummary(title: "third")
        let fourth = ConversationSummary(title: "fourth")
        capability.initialPage = [first]
        capability.totalCount = 1
        let viewModel = ConversationStoreSettingsViewModel(capability: capability)
        let progress = ConversationMigrationProgressStore()
        let observer = ConversationStoreObserver(
            capability: capability,
            viewModel: viewModel,
            migrationProgress: progress
        )
        defer { observer.cancel() }

        await waitUntil { viewModel.conversations == [first] }
        #expect(capability.pageRequests.count == 1)

        progress.start()
        await waitUntil { viewModel.isMigrationActive }
        #expect(viewModel.isMigrationActive)
        capability.initialPage = [second]
        progress.finish()
        await waitUntil { !viewModel.isMigrationActive && viewModel.conversations == [second] }
        #expect(!viewModel.isMigrationActive)

        capability.initialPage = [third]
        capability.emit(.updated(second.id))
        await waitUntil { viewModel.conversations == [third] }
        #expect(capability.pageRequests.count == 3)

        observer.cancel()
        capability.initialPage = [fourth]
        capability.emit(.listChanged)
        progress.start()
        for _ in 0..<100 { await Task.yield() }
        #expect(viewModel.conversations == [third])
        #expect(!viewModel.isMigrationActive)
        #expect(capability.pageRequests.count == 3)
    }

    @Test func capabilityAdapterUsesManagerAndEmptyMessageFallbacks() async {
        let manager = ConversationManager(
            store: nil,
            dataDirectory: FileManager.default.temporaryDirectory
        )
        let selected = ConversationSummary(title: "selected")
        manager.conversations = [selected]
        manager.selectedConversationID = selected.id
        let capability = ConversationStoreCapabilityAdapter(manager: manager, messageManager: nil)

        #expect(capability.selectedConversationID == selected.id)
        #expect(capability.dataDirectory == manager.dataDirectory)
        #expect(await capability.fetchConversationPage(
            limit: 20,
            beforeUpdatedAt: nil,
            beforeID: nil,
            includingChildConversations: true
        ).isEmpty)
        #expect(await capability.conversationCount(projectPath: nil, includingChildConversations: true) == 0)
        #expect(await capability.fetchDailyCountSeries().points.isEmpty)
        #expect(await capability.messagesSnapshot(in: selected.id).isEmpty)
        #expect(capability.messageCount(for: selected.id) == 0)

        var events: [ConversationEvent] = []
        let handle = capability.addConversationObserver { events.append($0) }
        manager.notifyConversationObservers(.updated(selected.id))
        #expect(events == [.updated(selected.id)])
        handle.cancel()
        manager.notifyConversationObservers(.deleted(selected.id))
        #expect(events == [.updated(selected.id)])
    }

    private func waitUntil(_ condition: () -> Bool) async {
        for _ in 0..<100 {
            if condition() { return }
            await Task.yield()
        }
    }
}
