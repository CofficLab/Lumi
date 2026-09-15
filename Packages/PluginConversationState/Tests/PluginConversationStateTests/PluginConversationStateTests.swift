import Foundation
import ProviderConversationState
import Testing
@testable import PluginConversationState

@Suite("PluginConversationState")
struct PluginConversationStateTests {
    @Test @MainActor
    func pluginMetadataIsStable() {
        let plugin = ConversationStatePlugin()

        #expect(plugin.id == "com.coffic.lumi.plugin.conversation-state")
        #expect(plugin.order == 10)
        #expect(plugin.metadata.policy == .alwaysOn)
    }

    @Test
    @MainActor
    func providerPublishesStateEvents() {
        let provider = ConversationStateProvider()
        let conversationID = UUID()
        var events: [ConversationStateEvent] = []
        let handle = provider.addConversationStateObserver { events.append($0) }

        provider.update(conversationID: conversationID, agentLoopState: .running)
        provider.remove(conversationID: conversationID)

        #expect(events == [.updated(conversationID), .removed(conversationID)])
        handle.cancel()
    }

    @Test
    @MainActor
    func partialUpdatePreservesUnchangedFields() {
        let provider = ConversationStateProvider()
        let conversationID = UUID()
        let turnID = UUID()

        provider.update(
            conversationID: conversationID,
            turnID: turnID,
            agentLoopState: .running,
            toolState: .executing,
            authorizationState: .required,
            activity: .thinking,
            lastError: "boom"
        )

        provider.update(conversationID: conversationID, toolState: .completed)

        let snapshot = provider.state(for: conversationID)
        #expect(snapshot.turnID == turnID)
        #expect(snapshot.agentLoopState == .running)
        #expect(snapshot.toolState == .completed)
        #expect(snapshot.activity == .thinking)
        #expect(snapshot.authorizationState == .required)
        #expect(snapshot.lastError == "boom")
        #expect(snapshot.isSending)
    }

    @Test
    @MainActor
    func clearFlagsResetActivityAndErrorWithoutTouchingOtherFields() {
        let provider = ConversationStateProvider()
        let conversationID = UUID()

        provider.update(
            conversationID: conversationID,
            agentLoopState: .running,
            activity: .sending,
            lastError: "stale"
        )
        provider.update(conversationID: conversationID, clearActivity: true, clearError: true)

        let snapshot = provider.state(for: conversationID)
        #expect(snapshot.activity == nil)
        #expect(snapshot.lastError == nil)
        #expect(snapshot.agentLoopState == .running)
    }

    @Test
    @MainActor
    func stateForUnknownConversationReturnsIdleDefault() {
        let provider = ConversationStateProvider()

        let snapshot = provider.state(for: UUID())

        #expect(snapshot.turnID == nil)
        #expect(snapshot.agentLoopState == .idle)
        #expect(snapshot.toolState == .idle)
        #expect(snapshot.authorizationState == .none)
        #expect(snapshot.activity == nil)
        #expect(snapshot.lastError == nil)
        #expect(!snapshot.isSending)
        #expect(!snapshot.jobActivity.hasJobs)
    }

    @Test
    @MainActor
    func removeUnknownConversationDoesNotNotify() {
        let provider = ConversationStateProvider()
        var events: [ConversationStateEvent] = []
        let handle = provider.addConversationStateObserver { events.append($0) }

        provider.remove(conversationID: UUID())

        #expect(events.isEmpty)
        handle.cancel()
    }

    @Test
    @MainActor
    func observerStopsReceivingAfterCancel() {
        let provider = ConversationStateProvider()
        var count = 0
        let handle = provider.addConversationStateObserver { _ in count += 1 }

        handle.cancel()
        provider.update(conversationID: UUID(), agentLoopState: .running)

        #expect(count == 0)
    }

    @Test
    @MainActor
    func jobActivityMergesIntoSnapshot() {
        let provider = ConversationStateProvider()
        let conversationID = UUID()

        provider.update(
            conversationID: conversationID,
            jobActivity: ConversationJobActivity(
                currentJobCount: 3,
                runningJobCount: 2,
                recentJobDescription: "build"
            )
        )

        let activity = provider.state(for: conversationID).jobActivity
        #expect(activity.currentJobCount == 3)
        #expect(activity.runningJobCount == 2)
        #expect(activity.recentJobDescription == "build")
        #expect(activity.hasJobs)
    }
}
