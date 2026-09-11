import LumiUI
import ProviderConversation
import ProviderMessage
import SwiftUI

/// ChatToolbar 上的上下文压缩记录入口。
@MainActor
struct ContextCompactionToolbarView: View {
    @LumiTheme private var theme

    let messages: any MessageManaging
    let state: ContextCompactionToolbarState

    @State private var isPopoverPresented = false
    @State private var selectedConversationID: UUID?
    @State private var events: [Message] = []
    @State private var refreshRevision = 0
    @State private var observerHandle: (any ContextCompactionToolbarState.ObserverHandle)?

    var body: some View {
        Button {
            isPopoverPresented.toggle()
        } label: {
            HStack(spacing: 3) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 10, weight: .medium))
                if !events.isEmpty {
                    Text("\(events.count)")
                        .font(.system(size: 10, weight: .medium))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                }
            }
            .foregroundColor(events.isEmpty ? theme.textSecondary : theme.warning)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                (events.isEmpty ? theme.appStatusMutedFill : theme.warning.opacity(0.14)),
                in: RoundedRectangle(cornerRadius: DesignTokens.Radius.sm, style: .continuous)
            )
            .contentShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.sm, style: .continuous))
        }
        .buttonStyle(.plain)
        .help(String(localized: "Context compaction history", defaultValue: "上下文压缩记录"))
        .popover(isPresented: $isPopoverPresented, arrowEdge: .bottom) {
            ContextCompactionPopover(events: events)
        }
        .task(id: "\(selectedConversationID?.uuidString ?? "nil")-\(refreshRevision)") {
            await refreshEvents(for: selectedConversationID)
        }
        .onAppear {
            guard observerHandle == nil else { return }
            selectedConversationID = state.selectedConversationID
            observerHandle = state.addObserver { event in
                switch event {
                case let .selectedConversationChanged(id):
                    selectedConversationID = id
                    isPopoverPresented = false
                case let .messagesChanged(conversationID):
                    guard conversationID == selectedConversationID else { return }
                    refreshRevision &+= 1
                }
            }
        }
        .onDisappear {
            observerHandle?.cancel()
            observerHandle = nil
        }
    }

    private func refreshEvents(for conversationID: UUID?) async {
        guard let conversationID else {
            events = []
            return
        }
        let snapshot = await messages.messagesSnapshot(in: conversationID)
        guard !Task.isCancelled, selectedConversationID == conversationID else { return }
        events = snapshot
            .filter(MessageTimelineEvent.isActualContextCompaction)
            .sorted { lhs, rhs in
                if lhs.createdAt == rhs.createdAt { return lhs.id > rhs.id }
                return lhs.createdAt > rhs.createdAt
            }
    }
}

@MainActor
final class ContextCompactionToolbarState {
    enum Event {
        case selectedConversationChanged(UUID?)
        case messagesChanged(conversationID: UUID)
    }

    protocol ObserverHandle: AnyObject {
        func cancel()
    }

    private final class Handle: ObserverHandle {
        private let cancelAction: () -> Void
        private var isCancelled = false

        init(cancelAction: @escaping () -> Void) {
            self.cancelAction = cancelAction
        }

        func cancel() {
            guard !isCancelled else { return }
            isCancelled = true
            cancelAction()
        }
    }

    private(set) var selectedConversationID: UUID?
    private var observers: [UUID: (Event) -> Void] = [:]

    @discardableResult
    func addObserver(_ callback: @escaping (Event) -> Void) -> any ObserverHandle {
        let id = UUID()
        observers[id] = callback
        return Handle { [weak self] in
            self?.observers.removeValue(forKey: id)
        }
    }

    func setSelectedConversationID(_ id: UUID?) {
        guard selectedConversationID != id else { return }
        selectedConversationID = id
        notify(.selectedConversationChanged(id))
    }

    func markMessagesChanged(conversationID: UUID) {
        notify(.messagesChanged(conversationID: conversationID))
    }

    private func notify(_ event: Event) {
        for callback in Array(observers.values) {
            callback(event)
        }
    }
}

@MainActor
final class ContextCompactionToolbarObserver {
    private var conversationHandle: (any SelectedConversationObserverHandle)?
    private var messageHandle: (any MessageInsertedObserverHandle)?

    init(
        conversations: any ConversationManaging,
        messages: any MessageManaging,
        onConversationChange: @escaping (UUID?) -> Void,
        onMessageInsert: @escaping (UUID) -> Void
    ) {
        onConversationChange(conversations.selectedConversationID)
        conversationHandle = conversations.addSelectedConversationObserver { id in
            onConversationChange(id)
        }
        messageHandle = messages.addMessageInsertedObserver { _, conversationID in
            onMessageInsert(conversationID)
        }
    }

    func cancel() {
        conversationHandle?.cancel()
        conversationHandle = nil
        messageHandle?.cancel()
        messageHandle = nil
    }
}
