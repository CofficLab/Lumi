import Foundation
import ProviderConversation
import ProviderConversationState
import ProviderProject
import Testing
@testable import PluginConversationList

@Test @MainActor func contextPublishesSelectionChangesOnceAndConversationRefreshes() {
    let context = ConversationListContext(
        conversations: DefaultConversationManager(),
        project: nil,
        agentTurn: nil,
        conversationState: nil,
        chat: nil
    )
    var events: [ContextEventSnapshot] = []
    let handle = context.addObserver { event in
        switch event {
        case .selectedConversationChanged(let id): events.append(.selection(id))
        case .conversationsChanged: events.append(.conversationsChanged)
        }
    }
    let conversationID = UUID()

    context.setSelectedConversationID(conversationID)
    context.setSelectedConversationID(conversationID)
    context.markConversationsChanged()
    context.setSelectedConversationID(nil)

    #expect(context.selectedConversationID == nil)
    #expect(events == [.selection(conversationID), .conversationsChanged, .selection(nil)])

    handle.cancel()
    handle.cancel()
    context.markConversationsChanged()
    #expect(events.count == 3)
}

@Test @MainActor func contextTracksTheCurrentProjectNameAndPath() async throws {
    let project = DefaultProjectProvider()
    let context = ConversationListContext(
        conversations: DefaultConversationManager(),
        project: project,
        agentTurn: nil,
        conversationState: nil,
        chat: nil
    )

    #expect(context.currentProjectPath == nil)
    #expect(context.currentProjectName == nil)
    try await project.openProject(at: "/workspace/My Project")
    #expect(context.currentProjectPath == "/workspace/My Project")
    #expect(context.currentProjectName == "My Project")
}

@Test @MainActor func contextObserverRefreshesForStructureAndStateButIgnoresVerbosity() throws {
    let conversations = DefaultConversationManager()
    let state = TestConversationStateProvider()
    let context = ConversationListContext(
        conversations: conversations,
        project: nil,
        agentTurn: nil,
        conversationState: state,
        chat: nil
    )
    let observer = ConversationListContextObserver(
        conversations: conversations,
        conversationState: state,
        context: context
    )
    var conversationChanges = 0
    var selectionChanges = 0
    let handle = context.addObserver { event in
        switch event {
        case .selectedConversationChanged:
            selectionChanges += 1
        case .conversationsChanged:
            conversationChanges += 1
        }
    }

    let conversationID = try conversations.createConversation(
        title: "First",
        projectPath: nil,
        providerID: nil,
        modelName: nil
    )
    #expect(conversationChanges == 1)
    #expect(selectionChanges == 1)

    conversations.setGlobalVerbosity(.brief)
    conversations.setVerbosity(.detailed, for: conversationID)
    #expect(conversationChanges == 1)

    state.publish(.updated(conversationID))
    #expect(conversationChanges == 2)

    observer.cancel()
    observer.cancel()
    _ = try conversations.createConversation(title: "After cancel", projectPath: nil, providerID: nil, modelName: nil)
    state.publish(.removed(conversationID))
    #expect(conversationChanges == 2)
    #expect(selectionChanges == 1)

    handle.cancel()
}

private enum ContextEventSnapshot: Equatable {
    case selection(UUID?)
    case conversationsChanged
}

@MainActor
private final class TestConversationStateProvider: ConversationStateProviding {
    private var observers: [UUID: (ConversationStateEvent) -> Void] = [:]

    var states: [UUID: ConversationStateSnapshot] { [:] }

    func state(for conversationID: UUID) -> ConversationStateSnapshot {
        ConversationStateSnapshot(conversationID: conversationID)
    }

    func addConversationStateObserver(
        _ callback: @escaping (ConversationStateEvent) -> Void
    ) -> any ConversationStateObserverHandle {
        let id = UUID()
        observers[id] = callback
        return TestConversationStateObserverHandle { [weak self] in
            self?.observers.removeValue(forKey: id)
        }
    }

    func publish(_ event: ConversationStateEvent) {
        for callback in observers.values { callback(event) }
    }
}

@MainActor
private final class TestConversationStateObserverHandle: ConversationStateObserverHandle {
    private var cancelAction: (() -> Void)?

    init(cancelAction: @escaping () -> Void) {
        self.cancelAction = cancelAction
    }

    func cancel() {
        cancelAction?()
        cancelAction = nil
    }
}
