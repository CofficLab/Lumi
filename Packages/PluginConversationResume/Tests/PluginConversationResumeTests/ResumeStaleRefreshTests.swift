import Foundation
import ProviderMessage
import Testing
@testable import PluginConversationResume

/// 回归覆盖 issue #462：`refreshState` 只在两个 `await` **之前**检查选中
/// 会话。读取中断记录与消息历史期间切换会话后，迟到的刷新仍会无条件
/// `apply`，把旧会话的「继续」横幅显示在新会话下面。
///
/// 修复后在两个 `await` 之后重新校验选中会话，迟到刷新直接丢弃。
@MainActor
struct ResumeStaleRefreshTests {

    // MARK: - 测试替身

    /// 能把指定会话的 `messages(for:)` 挂起的消息仓库替身。
    ///
    /// 用来确定性地制造「A 的刷新仍在读消息」的窗口，避免靠 sleep 猜时序。
    final class GatedMessages: ResumeMessageCapability {
        private(set) var stored: [UUID: [Message]] = [:]
        private var gatedConversationID: UUID?
        private var waiters: [UUID: CheckedContinuation<Void, Never>] = [:]

        func seed(_ messages: [Message], for conversationID: UUID) {
            stored[conversationID] = messages
        }

        func messages(for conversationID: UUID) async -> [Message] {
            if gatedConversationID == conversationID {
                await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                    waiters[conversationID] = continuation
                }
            }
            return stored[conversationID] ?? []
        }

        func insertMessage(_ message: Message, to conversationID: UUID) {
            stored[conversationID, default: []].append(message)
        }

        func updateToolCallResult(
            _ result: MessageToolResult,
            toolCallID: String,
            assistantMessageID: UUID,
            in conversationID: UUID
        ) {}

        @discardableResult
        func addObserver(_ callback: @escaping (UUID) -> Void) -> any ResumeMessageObserverHandle {
            class NoopHandle: ResumeMessageObserverHandle { func cancel() {} }
            return NoopHandle()
        }

        func gate(_ conversationID: UUID) {
            gatedConversationID = conversationID
        }

        func hasWaiter(for conversationID: UUID) -> Bool {
            waiters[conversationID] != nil
        }

        func releaseAll() {
            let pending = waiters
            waiters = [:]
            for continuation in pending.values {
                continuation.resume()
            }
        }
    }

    final class FakeConversations: ResumeConversationCapability {
        var selectedConversationID: UUID?

        @discardableResult
        func addObserver(_ callback: @escaping (UUID?) -> Void) -> any ResumeConversationObserverHandle {
            class NoopHandle: ResumeConversationObserverHandle { func cancel() {} }
            return NoopHandle()
        }
    }

    final class IdleAgentLoop: ResumeAgentLoopCapability {
        func turnState(for conversationID: UUID) -> ResumeEligibility.AgentLoopStateSnapshot {
            .idle
        }

        func startTurn(for conversationID: UUID) async {}
    }

    // MARK: - 辅助

    private func makeStore() -> (store: ResumableTurnStore, url: URL) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("resume-stale-refresh-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("turns.json")
        return (ResumableTurnStore(fileURL: url), url)
    }

    private func userMessage(_ conversationID: UUID) -> Message {
        Message(conversationID: conversationID, role: .user, content: "改一下代码")
    }

    // MARK: - 用例

    /// A 的刷新挂在读消息上时切到 B：A 的迟到刷新不得把 B 的状态改写为可继续。
    @Test("迟到的会话刷新不覆盖新选中会话的状态（回归 #462）")
    func staleRefreshDoesNotClobberSwitchedConversation() async throws {
        let (store, url) = makeStore()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        let conversationA = UUID()
        let conversationB = UUID()
        let messages = GatedMessages()
        let conversations = FakeConversations()
        let loop = IdleAgentLoop()

        // A 有中断记录，可继续；B 没有任何记录。
        messages.seed([userMessage(conversationA)], for: conversationA)
        await store.markRunning(conversationID: conversationA, turnID: UUID())
        conversations.selectedConversationID = conversationA

        let coordinator = ResumeCoordinator(
            loop: loop,
            messages: messages,
            conversations: conversations,
            store: store
        ) { _ in }

        // A 的刷新挂起的读消息上。
        messages.gate(conversationA)
        let staleTask = Task { @MainActor in
            await coordinator.refreshState(for: conversationA)
        }
        while !messages.hasWaiter(for: conversationA) {
            await Task.yield()
        }

        // 切到 B 并刷新：B 无中断记录，不可继续。
        conversations.selectedConversationID = conversationB
        await coordinator.refreshState(for: conversationB)
        #expect(!coordinator.state.isResumable, "B 无中断记录，不应显示 Continue")

        // 放行 A 的迟到刷新。
        messages.releaseAll()
        await staleTask.value

        #expect(
            !coordinator.state.isResumable,
            "A 的迟到刷新不得把新选中会话的状态改写为可继续"
        )
    }

    /// 刷新仍属于当前会话时正常生效，guard 不能把合法刷新也挡掉。
    @Test("当前会话的刷新正常生效（回归 #462）")
    func currentRefreshStillApplies() async throws {
        let (store, url) = makeStore()
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        let conversationA = UUID()
        let messages = GatedMessages()
        let conversations = FakeConversations()
        let loop = IdleAgentLoop()

        messages.seed([userMessage(conversationA)], for: conversationA)
        await store.markRunning(conversationID: conversationA, turnID: UUID())
        conversations.selectedConversationID = conversationA

        let coordinator = ResumeCoordinator(
            loop: loop,
            messages: messages,
            conversations: conversations,
            store: store
        ) { _ in }

        await coordinator.refreshState(for: conversationA)

        #expect(coordinator.state.isResumable, "选中会话未变，刷新应正常写入状态")
        #expect(coordinator.state.reason != "")
    }
}
