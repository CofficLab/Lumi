import Combine
import Foundation
import LumiKernel

/// Coordinates the native message list: narrow service subscriptions,
/// pagination, snapshot building, and stale-result rejection.
///
/// Design (mirrors `MessageListViewModel`):
/// - Captures only the services it needs; never subscribes to the kernel-wide
///   `objectWillChange`.
/// - Subscribes to selected-conversation changes, scoped message/turn
///   notifications, and the streaming/sending services' own
///   `objectWillChange` (narrow-cast).
/// - Loads pages off the main actor and builds immutable snapshots before
///   returning to the controller.
/// - Drops results that arrive after the active conversation moved on.
@MainActor
public final class AppKitMessageListCoordinator {
    public struct Dependencies {
        public let conversations: (any ConversationManaging)?
        public let messageManager: (any MessageManaging)?
        public let agentTurnManager: (any AgentTurnManaging)?
        public let messageStreaming: (any MessageStreaming)?
        public let messageSender: (any MessageSending)?

        public init(
            conversations: (any ConversationManaging)? = nil,
            messageManager: (any MessageManaging)? = nil,
            agentTurnManager: (any AgentTurnManaging)? = nil,
            messageStreaming: (any MessageStreaming)? = nil,
            messageSender: (any MessageSending)? = nil
        ) {
            self.conversations = conversations
            self.messageManager = messageManager
            self.agentTurnManager = agentTurnManager
            self.messageStreaming = messageStreaming
            self.messageSender = messageSender
        }
    }

    /// Snapshot sink; the controller replaces its previous snapshot on call.
    public var onSnapshot: (@MainActor (AppKitMessageListSnapshot) -> Void)?

    public private(set) var latestSnapshot: AppKitMessageListSnapshot = .empty

    private let dependencies: Dependencies
    private let pagination: AppKitMessagePagination
    private let refreshGate = AppKitSnapshotRefreshGate()
    private let briefProjector = BriefTurnProjector()
    private let timelineProjector = TimelineProjector()

    private var activeConversationID: UUID?
    /// Persisted message window, newest-last (display order).
    private var persistedMessages: [LumiChatMessage] = []
    /// V1 turn records, newest-first (projector sorts internally).
    private var records: [AgentTurnRecord] = []
    /// V2: whether an earlier message page exists above the window.
    private var hasEarlierMessages = false
    /// V1: whether an earlier turn page exists above the turn window.
    private var hasEarlierTurns = false
    private var isLoadingEarlier = false
    private var didBind = false
    /// Coalesces streaming bursts to at most one update per display frame.
    private var streamingRefreshTask: Task<Void, Never>?
    private var cancellables: Set<AnyCancellable> = []

    public init(
        dependencies: Dependencies,
        pageSize: Int = 40,
        maxRetainedCount: Int = 300
    ) {
        self.dependencies = dependencies
        self.pagination = AppKitMessagePagination(
            pageSize: pageSize,
            maxRetainedCount: maxRetainedCount
        )
    }

    // MARK: - Public API

    /// Switches to a conversation (or clears when `nil`), resets the window and
    /// loads the first page. Idempotently binds service subscriptions.
    ///
    /// Guarantees a final non-loading snapshot is published in every code
    /// path (including `nil` and exception paths) — otherwise the view would
    /// stay on the loading overlay forever.
    public func activate(conversationID: UUID?) async {
        bindServicesIfNeeded()
        activeConversationID = conversationID
        persistedMessages = []
        records = []
        hasEarlierMessages = false
        hasEarlierTurns = false
        isLoadingEarlier = false
        publish(.loading(conversationID: conversationID))

        guard let conversationID else {
            // No conversation selected (initial state or service not ready).
            // Publish an empty snapshot so the controller drops the loading
            // overlay instead of spinning forever.
            publish(.empty)
            return
        }

        do {
            try await loadFirstPage(conversationID: conversationID)
        } catch {
            print("[MessageListAppKit] activate: first-page load failed for \(conversationID.uuidString): \(error)")
        }
        guard activeConversationID == conversationID else { return }
        publish(buildSnapshot())
    }

    /// Refreshes the newest page/turn page, merging into the current window.
    /// Returns true only when the visible snapshot changed.
    @discardableResult
    public func refresh() async -> Bool {
        await refreshGate.run { [weak self] in
            guard let self else { return false }
            return await self.performRefresh()
        }
    }

    /// Prepends one older page. Returns the previously oldest visible message
    /// ID so the controller can restore its scroll anchor (nil when no-op).
    public func loadEarlier(isAtBottom: Bool) async -> UUID? {
        guard let conversationID = activeConversationID,
              !isLoadingEarlier,
              let currentFirstID = persistedMessages.first?.id
        else { return nil }

        isLoadingEarlier = true
        defer { isLoadingEarlier = false }

        guard let result = await pagination.loadEarlier(
            conversationID: conversationID,
            messageManager: dependencies.messageManager,
            currentFirstID: currentFirstID,
            hasEarlier: hasEarlierMessages
        ) else { return nil }
        guard activeConversationID == conversationID else { return nil }

        persistedMessages = result.earlier + persistedMessages
        hasEarlierMessages = result.hasEarlierMessages
        persistedMessages = pagination.evictTailIfNeeded(
            messages: persistedMessages,
            isAtBottom: isAtBottom
        )
        publish(buildSnapshot())
        return result.anchorID
    }

    // MARK: - First page & refresh

    private func loadFirstPage(conversationID: UUID) async {
        let result = await pagination.loadFirstPage(
            conversationID: conversationID,
            messageManager: dependencies.messageManager
        )
        guard activeConversationID == conversationID else { return }
        persistedMessages = result.messages
        hasEarlierMessages = result.hasEarlierMessages
        await refreshTurnRecords(conversationID: conversationID)
    }

    private func performRefresh() async -> Bool {
        guard let conversationID = activeConversationID else { return false }

        let previous = latestSnapshot
        if let result = await pagination.refreshTail(
            conversationID: conversationID,
            messageManager: dependencies.messageManager,
            current: persistedMessages
        ) {
            guard activeConversationID == conversationID else { return false }
            if persistedMessages != result.merged {
                persistedMessages = result.merged
            }
            if let hasEarlier = result.hasEarlierMessages {
                hasEarlierMessages = hasEarlier
            }
        }
        await refreshTurnRecords(conversationID: conversationID)
        guard activeConversationID == conversationID else { return false }

        let next = buildSnapshot()
        publish(next)
        return next != previous
    }

    /// Re-fetches the V1 turn record page (newest page only, deduped by id).
    /// Only touches `hasEarlierTurns` (V1 pagination); never message pagination.
    private func refreshTurnRecords(conversationID: UUID) async {
        guard let turnManager = dependencies.agentTurnManager else { return }
        let page = await turnManager.turnRecords(
            for: conversationID,
            limit: pagination.pageSize + 1,
            before: nil
        )
        guard activeConversationID == conversationID else { return }

        var byID = Dictionary(uniqueKeysWithValues: records.map { ($0.id, $0) })
        for record in page.prefix(pagination.pageSize) {
            byID[record.id] = record
        }
        let merged = byID.values.sorted {
            if $0.startedAt == $1.startedAt { return $0.id.uuidString > $1.id.uuidString }
            return $0.startedAt > $1.startedAt
        }
        if records.count <= pagination.pageSize {
            hasEarlierTurns = page.count > pagination.pageSize
        }
        records = merged
    }

    // MARK: - Snapshot building

    private func buildSnapshot() -> AppKitMessageListSnapshot {
        guard let conversationID = activeConversationID else { return .empty }

        let verbosity = self.verbosity
        let streaming = dependencies.messageStreaming
        let stage = streaming?.streamingStage(for: conversationID) ?? .idle
        let streamingMessage = streaming?.streamingRow(for: conversationID)

        let rows: [AppKitMessageRow]
        if verbosity == .brief {
            let allMessages = dependencies.messageManager?.messages(for: conversationID) ?? []
            let status = dependencies.messageManager?
                .messagePage(for: conversationID, limit: 1, beforeMessageID: nil)
                .last(where: { $0.role == .status })
            rows = briefProjector.project(.init(
                records: records,
                messages: allMessages,
                statusMessage: status
            ))
        } else {
            let input = TimelineProjector.Input(
                persisted: persistedMessages,
                verbosity: verbosity,
                streamingStage: stage,
                streamingRow: streamingMessage
            )
            rows = timelineProjector.projectHistory(input)
        }

        let streamingRow: AppKitMessageRow?
        if verbosity != .brief {
            streamingRow = timelineProjector.projectStreamingRow(.init(
                persisted: persistedMessages,
                verbosity: verbosity,
                streamingStage: stage,
                streamingRow: streamingMessage
            ))
        } else {
            streamingRow = nil
        }

        return AppKitMessageListSnapshot(
            conversationID: conversationID,
            rows: rows,
            streamingRow: streamingRow,
            hasEarlierRows: verbosity == .brief ? hasEarlierTurns : hasEarlierMessages,
            isLoading: false,
            isLive: stage != .idle
        )
    }

    private var verbosity: LumiResponseVerbosity {
        dependencies.conversations?
            .verbosity(for: activeConversationID) ?? .defaultVerbosity
    }

    private func publish(_ snapshot: AppKitMessageListSnapshot) {
        // Temporary diagnostic for "stuck on loading" investigation.
        let conv = snapshot.conversationID?.uuidString ?? "nil"
        print("[MessageListAppKit] publish: isLoading=\(snapshot.isLoading) rows=\(snapshot.rows.count) streaming=\(snapshot.streamingRow != nil) conv=\(conv)")
        latestSnapshot = snapshot
        onSnapshot?(snapshot)
    }

    // MARK: - Narrow subscriptions

    private func bindServicesIfNeeded() {
        guard !didBind else { return }

        // Sinks hop back onto the main actor via `Task { @MainActor }` instead
        // of `receive(on: DispatchQueue.main)`: events may originate on any
        // thread, and a Task scheduled on the MainActor executor cooperates
        // reliably with both the app run loop and Swift Testing.
        NotificationCenter.default.publisher(for: .lumiConversationsDidChange)
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    let selected = self.dependencies.conversations?.selectedConversationID
                    // Only react once we already hold a non-nil active session —
                    // avoids a race where the controller's first activate and
                    // the very first conversationsDidChange notification both
                    // run concurrently and the nil branch never reaches
                    // publish(.empty).
                    guard let current = self.activeConversationID else { return }
                    if selected != current { await self.activate(conversationID: selected) }
                }
            }
            .store(in: &cancellables)

        let messageNotifications: [Notification.Name] = [
            .lumiMessagesDidChange,
            .lumiMessageSaved,
            .lumiTurnStarted,
            .lumiTurnCompleted,
            .lumiTurnFinished,
        ]
        for name in messageNotifications {
            NotificationCenter.default.publisher(for: name)
                .sink { [weak self] notification in
                    Task { @MainActor [weak self] in
                        guard let self,
                              AppKitMessageNotificationFilter.shouldHandle(
                                eventConversationID: notification.lumiConversationID,
                                selectedConversationID: self.activeConversationID
                              )
                        else { return }
                        await self.refresh()
                    }
                }
                .store(in: &cancellables)
        }

        NotificationCenter.default.publisher(for: .lumiConversationDidDelete)
            .sink { [weak self] notification in
                Task { @MainActor [weak self] in
                    guard let self,
                          let deleted = notification.lumiConversationID,
                          deleted == self.activeConversationID
                    else { return }
                    await self.activate(conversationID: nil)
                }
            }
            .store(in: &cancellables)

        if let streaming = dependencies.messageStreaming {
            streaming.objectWillChange
                .sink { [weak self] _ in
                    Task { @MainActor [weak self] in
                        self?.scheduleStreamingPresentation()
                    }
                }
                .store(in: &cancellables)
        }
        if let sender = dependencies.messageSender {
            sender.objectWillChange
                .sink { [weak self] _ in
                    Task { @MainActor [weak self] in
                        guard let self else { return }
                        await self.refresh()
                    }
                }
                .store(in: &cancellables)
        }

        didBind = true
    }

    /// Coalesces streaming bursts to one presentation update per frame.
    ///
    /// History rows are rebuilt only when the streaming boundary actually
    /// changes (streaming row appears/disappears → status drop rules flip);
    /// otherwise the controller diffs a single changed row. V1 (brief) never
    /// updates the table on token chunks — status/terminal changes flow through
    /// the notification path instead.
    private func scheduleStreamingPresentation() {
        guard streamingRefreshTask == nil else { return }
        streamingRefreshTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 16_000_000)
            guard !Task.isCancelled, let self else { return }
            self.streamingRefreshTask = nil
            guard self.activeConversationID != nil, self.verbosity != .brief else { return }
            self.publish(self.buildSnapshot())
        }
    }
}
