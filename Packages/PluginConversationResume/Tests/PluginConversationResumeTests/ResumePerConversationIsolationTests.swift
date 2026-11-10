import Foundation
import ProviderLifecycleHooks
import ProviderMessage
import Testing
@testable import PluginConversationResume

/// 恢复动作必须**按会话隔离**。
///
/// #888：`ResumeCoordinator` 用单个全局 `resumingConversationID`，
/// `ResumeViewModel` 用单个全局 `isResuming` 布尔。结果是会话 A 的恢复
/// 回合尚未返回时，会话 B 即使有自己独立的中断记录和 Continue 横幅，
/// 也无法开始恢复 —— B 的 Continue 按钮被禁用，编程入口也被全局 guard
/// 直接拒绝。
///
/// ## 为什么这在架构上是错的
///
/// AgentLoop 侧的 `runtimes` 与 `completionWaiters` 都**按 conversationID
/// 隔离**，正常发送路径也按会话维护任务。也就是说底层早就支持并行回合，
/// 只有 Resume 这一层退化成了全局单值。
///
/// 而恢复的语义本就要求「一个会话的恢复只抑制这个会话自己的重复恢复
/// 动作」——B 有独立的中断记录、消息历史和 AgentLoop 运行时，凭什么要等
/// A 完成？
@MainActor
struct ResumePerConversationIsolationTests {

    // MARK: - 测试替身

    /// 能把 `startTurn` 挂起的 AgentLoop 替身。
    ///
    /// 用来确定性地制造「A 的恢复回合仍在运行」的窗口：真实链路里
    /// `runTurn` 会一直等到回合完成，靠 sleep 猜时序不可靠。
    ///
    /// - Important: 回合状态**按会话**维护，与真实 AgentLoop 一致
    ///   （`AgentLoopManager.runtimes` 是 `[UUID: TurnRuntime]`）。
    ///   若用一个全局状态，A 的 startTurn 会把 B 的状态也改成 running，
    ///   B 就再也判定不出「可继续」。
    final class GatedAgentLoop: ResumeAgentLoopCapability {
        /// 每个会话的回合状态。
        private(set) var states: [UUID: ResumeEligibility.AgentLoopStateSnapshot] = [:]
        private(set) var startTurnCount = 0
        private(set) var startedConversationIDs: [UUID] = []

        /// 已进入挂起 `startTurn` 的会话。
        private(set) var gatedConversationID: UUID?
        /// 挂起中的 continuation。
        private var waiters: [UUID: CheckedContinuation<Void, Never>] = [:]

        func turnState(for conversationID: UUID) -> ResumeEligibility.AgentLoopStateSnapshot {
            states[conversationID] ?? .idle
        }

        func startTurn(for conversationID: UUID) async {
            startTurnCount += 1
            startedConversationIDs.append(conversationID)
            states[conversationID] = .running
            if gatedConversationID == conversationID {
                await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                    waiters[conversationID] = continuation
                }
            }
        }

        /// 让指定会话的 `startTurn` 挂起。
        func gate(_ conversationID: UUID) {
            gatedConversationID = conversationID
        }

        /// 放行全部挂起的 `startTurn`。
        func releaseAll() {
            let pending = waiters
            waiters = [:]
            for continuation in pending.values {
                continuation.resume()
            }
        }
    }

    /// 内存消息仓库替身。
    final class FakeMessages: ResumeMessageCapability {
        private(set) var stored: [UUID: [Message]] = [:]
        private var observers: [UUID: (UUID) -> Void] = [:]

        func seed(_ messages: [Message], for conversationID: UUID) {
            stored[conversationID] = messages
        }

        func messages(for conversationID: UUID) async -> [Message] {
            stored[conversationID] ?? []
        }

        func insertMessage(_ message: Message, to conversationID: UUID) {
            stored[conversationID, default: []].append(message)
            for observer in observers.values {
                observer(conversationID)
            }
        }

        @discardableResult
        func addObserver(_ callback: @escaping (UUID) -> Void) -> any ResumeMessageObserverHandle {
            let id = UUID()
            observers[id] = callback
            return Handle { [weak self] in
                self?.observers.removeValue(forKey: id)
            }
        }

        final class Handle: ResumeMessageObserverHandle {
            private let cancelAction: () -> Void
            init(cancelAction: @escaping () -> Void) {
                self.cancelAction = cancelAction
            }
            func cancel() { cancelAction() }
        }
    }

    /// 会话选择替身。
    final class FakeConversations: ResumeConversationCapability {
        var selectedConversationID: UUID?
        private var observers: [UUID: (UUID?) -> Void] = [:]

        @discardableResult
        func addObserver(_ callback: @escaping (UUID?) -> Void) -> any ResumeConversationObserverHandle {
            let id = UUID()
            observers[id] = callback
            return Handle { [weak self] in
                self?.observers.removeValue(forKey: id)
            }
        }

        final class Handle: ResumeConversationObserverHandle {
            private let cancelAction: () -> Void
            init(cancelAction: @escaping () -> Void) {
                self.cancelAction = cancelAction
            }
            func cancel() { cancelAction() }
        }
    }

    // MARK: - 辅助

    private func makeStore() -> (store: ResumableTurnStore, url: URL) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("resume-isolation-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("turns.json")
        return (ResumableTurnStore(fileURL: url), url)
    }

    private func userMessage(_ conversationID: UUID) -> Message {
        Message(conversationID: conversationID, role: .user, content: "改一下代码")
    }

    private func makeHooks() -> DefaultLifecycleHooksProvider {
        DefaultLifecycleHooksProvider()
    }

    private func makeHooksCapability(
        _ hooks: DefaultLifecycleHooksProvider
    ) -> any ResumeLifecycleHooksCapability {
        ResumeLifecycleHooksCapabilityAdapter(hooks: hooks)
    }

    private func makeCoordinator(
        loop: any ResumeAgentLoopCapability,
        messages: any ResumeMessageCapability,
        conversations: any ResumeConversationCapability,
        store: ResumableTurnStore
    ) -> ResumeCoordinator {
        ResumeCoordinator(
            loop: loop,
            messages: messages,
            conversations: conversations,
            store: store
        ) { _ in }
    }

    // MARK: - 用例

    /// A 的恢复回合仍在运行时，B 必须能独立开始恢复。
    @Test("A 恢复中时 B 仍可独立恢复")
    func otherConversationCanResumeWhileFirstIsRunning() async throws {
        let (store, url) = makeStore()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        let conversationA = UUID()
        let conversationB = UUID()
        let loop = GatedAgentLoop()
        let messages = FakeMessages()
        let conversations = FakeConversations()

        // 两个会话各有独立的中断记录与消息历史。
        messages.seed([userMessage(conversationA)], for: conversationA)
        messages.seed([userMessage(conversationB)], for: conversationB)

        let coordinator = makeCoordinator(
            loop: loop,
            messages: messages,
            conversations: conversations,
            store: store
        )
        coordinator.start(hooks: makeHooksCapability(makeHooks()))

        await store.markRunning(conversationID: conversationA, turnID: UUID())
        await store.markRunning(conversationID: conversationB, turnID: UUID())

        // A 的恢复回合挂起，模拟「长时间未结束」。
        loop.gate(conversationA)

        // 会话 A 在恢复中。
        conversations.selectedConversationID = conversationA
        await coordinator.refreshState(for: conversationA)
        #expect(coordinator.state.isResumable)

        let resumeA = Task { @MainActor in
            await coordinator.resume()
        }
        // 等 A 真正进入挂起的 startTurn。
        while !loop.startedConversationIDs.contains(conversationA) {
            await Task.yield()
        }

        // 会话 B 有自己的中断记录，可继续。
        conversations.selectedConversationID = conversationB
        await coordinator.refreshState(for: conversationB)
        #expect(coordinator.state.isResumable, "B 有独立的中断记录，应显示 Continue")

        // B 的恢复必须能独立启动，不能被 A 的全局锁挡住。
        await coordinator.resume()

        #expect(
            loop.startedConversationIDs.contains(conversationB),
            "B 的恢复被 A 的全局 isResuming 挡住了"
        )

        loop.releaseAll()
        await resumeA.value
        coordinator.cancel()
    }

    /// 同一个会话的重复恢复必须仍然被抑制。
    ///
    /// 这是 #888 修复的另一半：把全局锁改成按会话隔离之后，不能变成
    /// 「同一个会话可以并发恢复」——那会造成同一会话重复启动回合。
    @Test("同一会话的重复恢复仍被抑制")
    func repeatedResumeOfSameConversationIsStillBlocked() async throws {
        let (store, url) = makeStore()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        let conversationID = UUID()
        let loop = GatedAgentLoop()
        let messages = FakeMessages()
        let conversations = FakeConversations()
        messages.seed([userMessage(conversationID)], for: conversationID)
        conversations.selectedConversationID = conversationID

        let coordinator = makeCoordinator(
            loop: loop,
            messages: messages,
            conversations: conversations,
            store: store
        )
        coordinator.start(hooks: makeHooksCapability(makeHooks()))

        await store.markRunning(conversationID: conversationID, turnID: UUID())
        await coordinator.refreshState(for: conversationID)
        #expect(coordinator.state.isResumable)

        // 该会话的恢复挂起。
        loop.gate(conversationID)
        let first = Task { @MainActor in
            await coordinator.resume()
        }
        while !loop.startedConversationIDs.contains(conversationID) {
            await Task.yield()
        }

        // 第二次点击同一会话必须被抑制。
        await coordinator.resume()
        #expect(
            loop.startedConversationIDs.filter { $0 == conversationID }.count == 1,
            "同一会话不应并发启动两个恢复回合"
        )

        loop.releaseAll()
        await first.value
        coordinator.cancel()
    }

    /// 恢复状态必须按会话反映到 UI 状态上。
    ///
    /// A 恢复期间切到 B，B 的 `isResuming` 必须是 false —— 否则 B 的
    /// 「继续」按钮会被禁用，这正是 #888 描述的界面症状。
    @Test("恢复状态按会话反映，别的会话不被标记为恢复中")
    func resumingStateIsReportedPerConversation() async throws {
        let (store, url) = makeStore()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        let conversationA = UUID()
        let conversationB = UUID()
        let loop = GatedAgentLoop()
        let messages = FakeMessages()
        let conversations = FakeConversations()
        messages.seed([userMessage(conversationA)], for: conversationA)
        messages.seed([userMessage(conversationB)], for: conversationB)

        let coordinator = makeCoordinator(
            loop: loop,
            messages: messages,
            conversations: conversations,
            store: store
        )
        coordinator.start(hooks: makeHooksCapability(makeHooks()))

        await store.markRunning(conversationID: conversationA, turnID: UUID())
        await store.markRunning(conversationID: conversationB, turnID: UUID())

        loop.gate(conversationA)
        conversations.selectedConversationID = conversationA
        await coordinator.refreshState(for: conversationA)

        let resumeA = Task { @MainActor in
            await coordinator.resume()
        }
        while !loop.startedConversationIDs.contains(conversationA) {
            await Task.yield()
        }

        #expect(coordinator.isResuming(conversationA))
        #expect(
            coordinator.isResuming(conversationB) == false,
            "A 恢复中不应把 B 也标记为恢复中"
        )

        // 切到 B：B 的横幅不该处于禁用状态。
        conversations.selectedConversationID = conversationB
        await coordinator.refreshState(for: conversationB)
        #expect(
            coordinator.state.isResuming == false,
            "B 的「继续」按钮被 A 的恢复禁用了"
        )

        loop.releaseAll()
        await resumeA.value
        coordinator.cancel()
    }
}
