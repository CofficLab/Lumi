import Foundation
import KernelCore
import ProviderChatSection
import ProviderConversation
import ProviderMessage
import Testing
@testable import PluginMessageListEmpty

/// `MessageManaging` stub whose paging query can be suspended on demand.
///
/// Needed to observe the plugin while its empty-state evaluation is still in
/// flight — the one window a test cannot reach through the default manager,
/// because its read resolves immediately.
@MainActor
private final class StallingMessageManager: MessageManaging {
    private let backing = DefaultMessageManager()

    /// When set, the next page query suspends until `releaseQuery()`.
    private var stallNextPageQuery = false
    private var stallResumes: [CheckedContinuation<Void, Never>] = []
    private var stallArrivedWaiters: [CheckedContinuation<Void, Never>] = []

    func stallUpcomingPageQuery() {
        stallNextPageQuery = true
    }

    /// Suspends until a page query has actually entered the stall.
    func waitUntilQueryStalls() async {
        await withCheckedContinuation { continuation in
            stallArrivedWaiters.append(continuation)
        }
    }

    func releaseQuery() {
        let resumes = stallResumes
        stallResumes.removeAll()
        for continuation in resumes { continuation.resume() }

        let waiters = stallArrivedWaiters
        stallArrivedWaiters.removeAll()
        for continuation in waiters { continuation.resume() }
    }

    func insertMessage(_ message: Message, to conversationID: UUID) {
        backing.insertMessage(message, to: conversationID)
    }

    func clearMessages(in conversationID: UUID) {
        backing.clearMessages(in: conversationID)
    }

    func messagePageAsync(
        for conversationID: UUID,
        limit: Int,
        beforeMessageID: UUID?,
        includesToolMessages: Bool
    ) async -> [Message] {
        if stallNextPageQuery {
            stallNextPageQuery = false
            await withCheckedContinuation { continuation in
                stallResumes.append(continuation)
                let waiters = stallArrivedWaiters
                stallArrivedWaiters.removeAll()
                for waiter in waiters { waiter.resume() }
            }
        }
        return await backing.messagePageAsync(
            for: conversationID,
            limit: limit,
            beforeMessageID: beforeMessageID,
            includesToolMessages: includesToolMessages
        )
    }

    // MARK: - Required protocol members

    func messages(for conversationID: UUID) -> [Message] { backing.messages(for: conversationID) }

    func message(id: UUID, in conversationID: UUID) -> Message? { backing.message(id: id, in: conversationID) }

    func lastMessage(in conversationID: UUID) -> Message? { backing.lastMessage(in: conversationID) }

    func messageCount(for conversationID: UUID) -> Int { backing.messageCount(for: conversationID) }

    func updateMessage(id: UUID, in conversationID: UUID, content: String) {
        backing.updateMessage(id: id, in: conversationID, content: content)
    }

    func deleteMessage(id: UUID, in conversationID: UUID) {
        backing.deleteMessage(id: id, in: conversationID)
    }

    func updateToolCallResult(
        _ result: MessageToolResult,
        toolCallID: String,
        assistantMessageID: UUID,
        in conversationID: UUID,
        authorizationState: String?
    ) {}
}

/// Locks the meaning of the `.evaluating` registration state.
///
/// This is the invariant the whole three-state design exists for: while the
/// "does this conversation have messages?" query is in flight, the plugin must
/// **not** compete for the `message-list` slot. Answering "empty" during that
/// window would put a conversation that does have messages behind the empty-state
/// guide; answering "not empty" would claim a verdict it has not earned. Only
/// "I don't know yet" keeps the real message list on screen.
///
/// Every other case in this package asserts a *settled* state, so none of them
/// can catch a regression that inverts the in-flight answer. This one observes
/// the window directly by stalling the query.
@Test @MainActor func emptyStateStaysOutOfTheSlotWhileEvaluationIsInFlight() async throws {
    let kernel = KernelCoreContainer()
    let conversations = DefaultConversationManager()
    let messages = StallingMessageManager()
    let chat = DefaultChatSectionProviding()
    try kernel.registerProvider((any ChatSectionProviding).self, chat)
    try kernel.registerProvider((any ConversationManaging).self, conversations)
    try kernel.registerProvider((any MessageManaging).self, messages)

    let busyID = try conversations.createConversation(title: "Busy", projectPath: nil, providerID: nil, modelName: nil)
    messages.insertMessage(Message(conversationID: busyID, role: .user, content: "hi"), to: busyID)
    conversations.selectConversation(id: busyID)

    let plugin = PluginMessageListEmptyPlugin()
    try plugin.onBoot(kernel: kernel)

    messages.stallUpcomingPageQuery()
    conversations.selectConversation(id: busyID)
    // The plugin evaluates inside a child task, so the stall flag is only
    // consumed once that task actually runs. Wait for the suspension to happen
    // before touching the latch — releasing early is a no-op and the query
    // would then hang forever.
    await messages.waitUntilQueryStalls()

    // In flight: busyID does have messages, so the real list must own the slot.
    #expect(!chat.isEmptyStateRendering, "判定在途时抢占槽位：有消息却显示空态")

    messages.releaseQuery()
    await settleRegistrationEvaluation()
    #expect(!chat.isEmptyStateRendering)

    try plugin.onShutdown(kernel: kernel)
}

/// The mirror image: once the query resolves, an empty conversation must take
/// over the slot. Without this, a plugin that never left `.evaluating` would
/// satisfy the case above while showing no empty state at all.
@Test @MainActor func emptyStateOnlyAppearsAfterEvaluationSettles() async throws {
    let kernel = KernelCoreContainer()
    let conversations = DefaultConversationManager()
    let messages = StallingMessageManager()
    let chat = DefaultChatSectionProviding()
    try kernel.registerProvider((any ChatSectionProviding).self, chat)
    try kernel.registerProvider((any ConversationManaging).self, conversations)
    try kernel.registerProvider((any MessageManaging).self, messages)

    let idleID = try conversations.createConversation(title: "Idle", projectPath: nil, providerID: nil, modelName: nil)

    let plugin = PluginMessageListEmptyPlugin()
    try plugin.onBoot(kernel: kernel)

    messages.stallUpcomingPageQuery()
    conversations.selectConversation(id: idleID)
    await messages.waitUntilQueryStalls()

    // In flight the verdict is genuinely unknown, so the empty state must not
    // claim the slot yet.
    #expect(!chat.isEmptyStateRendering, "判定在途时抢占了槽位")

    messages.releaseQuery()
    await settleRegistrationEvaluation()
    // Only now, with the query resolved, may the empty state take over.
    #expect(chat.isEmptyStateRendering)

    try plugin.onShutdown(kernel: kernel)
}

/// Lets the plugin's registration evaluation reach a settled conclusion.
///
/// The evaluation runs in a child task that performs an async SwiftData read and
/// only then calls `applyRegistration`. Draining the main actor with yields lets
/// those tasks run to completion without burning wall-clock time on sleeps.
@MainActor
private func settleRegistrationEvaluation() async {
    for _ in 0..<50 {
        await Task.yield()
    }
}

/// Empty-state item 常驻注册，可见性完全由 `isActive` 表达，
/// 因此断言「是否渲染空态」而非「是否注册 item」。
private extension DefaultChatSectionProviding {
    var isEmptyStateRendering: Bool {
        items.contains { $0.id == "com.coffic.lumi.plugin.message-list.empty" && $0.isActive() }
    }
}
