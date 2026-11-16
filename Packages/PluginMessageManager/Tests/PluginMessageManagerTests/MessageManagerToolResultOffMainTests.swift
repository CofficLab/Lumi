import Foundation
import ProviderMessage
import Testing
@testable import PluginMessageManager

/// 工具结果写回不得让 MainActor 同步等待 SwiftData（issue #1229）。
///
/// 助手消息落盘后会离开 pending，此时写回工具结果走「非 pending」分支：
/// 旧实现在主线程 fetch 整条消息、编码整个 toolCalls 数组再 save，
/// 大工具输出会把 UI 卡住。新实现把 fetch / 编码 / save 交给串行落盘队列，
/// 主线程只登记一个内存补丁。
///
/// 本组用例锁住两件事：
/// 1. 主线程不再触碰存储锁；
/// 2. 补丁在落盘窗口内对**所有**读路径可见——AgentLoop 下一轮以
///    `messages(for:)` 为事实来源，读不到工具结果就会重复执行同一个工具。
@MainActor
@Suite("工具结果写回不阻塞主线程", .serialized)
struct MessageManagerToolResultOffMainTests {
    private func makeStore() throws -> (MessageStore, URL) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MessageManagerToolResult-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return (try MessageStore(databaseRootURL: directory), directory)
    }

    private func makeManager(store: MessageStore) -> MessageManager {
        MessageManager(
            store: store,
            dataDirectory: URL(fileURLWithPath: NSTemporaryDirectory())
        )
    }

    private func assistantMessage(
        conversationID: UUID,
        toolCallIDs: [String],
        authorizationState: String? = nil
    ) -> Message {
        Message(
            conversationID: conversationID,
            role: .assistant,
            content: "",
            createdAt: Date(),
            toolCalls: toolCallIDs.map {
                MessageToolCall(
                    id: $0,
                    name: "write_file",
                    arguments: "{}",
                    authorizationState: authorizationState
                )
            }
        )
    }

    /// 等消息落盘**且**离开 pending —— 这是「非 pending 分支」的前提。
    private func waitForPersistedAndDrained(
        _ manager: MessageManager,
        store: MessageStore,
        messageID: UUID,
        conversationID: UUID
    ) async throws -> Bool {
        for _ in 0..<400 {
            if store.fetchMessage(id: messageID) != nil,
               manager.pending.snapshot(for: conversationID).isEmpty {
                return true
            }
            try await Task.sleep(nanoseconds: 5_000_000)
        }
        return false
    }

    /// 等**目标字段**落盘，而不是等固定时长：写回是异步的，
    /// 过早读到的仍是 insert 时的快照，会把时序误判成缺陷。
    private func waitForDiskCall(
        _ store: MessageStore,
        messageID: UUID,
        toolCallID: String,
        matching predicate: (MessageToolCall) -> Bool
    ) async throws -> MessageToolCall? {
        var last: MessageToolCall?
        for _ in 0..<400 {
            if let call = store.fetchMessage(id: messageID)?.toolCalls?.first(where: { $0.id == toolCallID }) {
                last = call
                if predicate(call) { return call }
            }
            try await Task.sleep(nanoseconds: 5_000_000)
        }
        return last
    }

    private static func call(
        _ messages: [Message],
        messageID: UUID,
        toolCallID: String
    ) -> MessageToolCall? {
        messages.first { $0.id == messageID }?.toolCalls?.first { $0.id == toolCallID }
    }

    /// `DispatchSemaphore.wait` 在 async 上下文不可用，门闩等待放进同步辅助。
    private nonisolated func wait(
        _ semaphore: DispatchSemaphore,
        timeout: DispatchTime
    ) -> DispatchTimeoutResult {
        semaphore.wait(timeout: timeout)
    }

    // MARK: - 主线程不再等待存储

    @Test("助手消息已落盘时，写回工具结果不等待存储锁")
    func toolResultWriteDoesNotBlockOnStoreLock() async throws {
        let (store, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let manager = makeManager(store: store)
        let conversationID = UUID()
        let assistant = assistantMessage(conversationID: conversationID, toolCallIDs: ["call-1"])
        manager.insertMessage(assistant, to: conversationID)
        #expect(try await waitForPersistedAndDrained(
            manager, store: store, messageID: assistant.id, conversationID: conversationID
        ))

        // 占住存储锁：主线程若仍同步 fetch / save，这次调用会被挂住。
        let acquired = DispatchSemaphore(value: 0)
        let release = DispatchSemaphore(value: 0)
        Thread.detachNewThread {
            store.lock.lock()
            acquired.signal()
            // 安全网：断言失败也不能把存储锁永久占住。
            _ = release.wait(timeout: .now() + 10)
            store.lock.unlock()
        }
        #expect(wait(acquired, timeout: .now() + 5) == .success)
        defer { release.signal() }

        let start = Date()
        manager.updateToolCallResult(
            MessageToolResult(content: "done"),
            toolCallID: "call-1",
            assistantMessageID: assistant.id,
            in: conversationID
        )
        let elapsed = Date().timeIntervalSince(start)
        #expect(elapsed < 1.0, "MainActor 同步等待了存储锁 / SwiftData：\(elapsed)s")

        // 补丁已登记，落盘窗口内的 read-your-writes 靠它。
        #expect(
            manager.pending.toolResultPatches(for: conversationID)[assistant.id]?["call-1"]?.result.content == "done"
        )

        release.signal()
        let persisted = try await waitForDiskCall(
            store, messageID: assistant.id, toolCallID: "call-1",
            matching: { $0.result?.content == "done" }
        )
        #expect(persisted?.result?.content == "done")
    }

    // MARK: - 落盘窗口内的 read-your-writes

    @Test("落盘窗口内，所有读路径都能看到工具结果补丁")
    func patchIsVisibleOnEveryReadPath() async throws {
        let (store, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let manager = makeManager(store: store)
        let conversationID = UUID()
        let assistant = assistantMessage(conversationID: conversationID, toolCallIDs: ["call-1"])
        manager.insertMessage(assistant, to: conversationID)
        #expect(try await waitForPersistedAndDrained(
            manager, store: store, messageID: assistant.id, conversationID: conversationID
        ))

        // 直接构造「已通知 UI、尚未落盘」的窗口：后台落盘时序无法稳定复现，
        // 而这里要验证的正是窗口内的读语义。
        manager.pending.enqueueToolResult(
            PendingMessageBuffer.ToolResultPatch(
                result: MessageToolResult(content: "patched"),
                authorizationState: "userApproved"
            ),
            messageID: assistant.id,
            toolCallID: "call-1",
            conversationID: conversationID
        )
        // 磁盘仍是旧版本，证明下面读到的确实来自补丁而非落盘结果。
        #expect(store.fetchMessage(id: assistant.id)?.toolCalls?.first?.result == nil)

        #expect(Self.call(
            manager.messages(for: conversationID), messageID: assistant.id, toolCallID: "call-1"
        )?.result?.content == "patched")

        #expect(
            manager.message(id: assistant.id, in: conversationID)?.toolCalls?.first?.result?.content == "patched"
        )

        #expect(Self.call(
            manager.messagePage(for: conversationID, limit: 10, beforeMessageID: nil),
            messageID: assistant.id, toolCallID: "call-1"
        )?.result?.content == "patched")

        #expect(Self.call(
            await manager.messagesSnapshot(in: conversationID), messageID: assistant.id, toolCallID: "call-1"
        )?.result?.content == "patched")

        #expect(Self.call(
            await manager.messagesForLLM(in: conversationID), messageID: assistant.id, toolCallID: "call-1"
        )?.result?.content == "patched")

        #expect(Self.call(
            await manager.messagePageAsync(for: conversationID, limit: 10, beforeMessageID: nil),
            messageID: assistant.id, toolCallID: "call-1"
        )?.result?.content == "patched")

        #expect(Self.call(
            manager.messages(for: conversationID), messageID: assistant.id, toolCallID: "call-1"
        )?.authorizationState == "userApproved")

        // 补丁撤掉后读路径回到磁盘版本，不会留下幽灵结果。
        manager.pending.dequeueToolResult(
            messageID: assistant.id, toolCallID: "call-1", conversationID: conversationID
        )
        #expect(
            manager.messages(for: conversationID).first?.toolCalls?.first?.result == nil
        )
    }

    @Test("写回后立刻读到结果，不等后台落盘")
    func readYourWritesAfterToolResult() async throws {
        let (store, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let manager = makeManager(store: store)
        let conversationID = UUID()
        let assistant = assistantMessage(conversationID: conversationID, toolCallIDs: ["call-1"])
        manager.insertMessage(assistant, to: conversationID)
        #expect(try await waitForPersistedAndDrained(
            manager, store: store, messageID: assistant.id, conversationID: conversationID
        ))

        manager.updateToolCallResult(
            MessageToolResult(content: "file written"),
            toolCallID: "call-1",
            assistantMessageID: assistant.id,
            in: conversationID,
            authorizationState: "userApproved"
        )

        // 同步断言：中间不 await，落盘可能还没发生。
        #expect(Self.call(
            manager.messages(for: conversationID), messageID: assistant.id, toolCallID: "call-1"
        )?.result?.content == "file written")
        #expect(
            manager.message(id: assistant.id, in: conversationID)?.toolCalls?.first?.result?.content == "file written"
        )
        #expect(Self.call(
            manager.messagePage(for: conversationID, limit: 10, beforeMessageID: nil),
            messageID: assistant.id, toolCallID: "call-1"
        )?.result?.content == "file written")

        let persisted = try await waitForDiskCall(
            store, messageID: assistant.id, toolCallID: "call-1",
            matching: { $0.authorizationState == "userApproved" }
        )
        #expect(persisted?.result?.content == "file written")
        #expect(persisted?.authorizationState == "userApproved")
    }

    @Test("补丁只作用于所属会话")
    func patchesAreScopedToConversation() async throws {
        let (store, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let manager = makeManager(store: store)
        let conversationA = UUID()
        let conversationB = UUID()
        let assistantA = assistantMessage(conversationID: conversationA, toolCallIDs: ["call-1"])
        let assistantB = assistantMessage(conversationID: conversationB, toolCallIDs: ["call-1"])
        manager.insertMessage(assistantA, to: conversationA)
        manager.insertMessage(assistantB, to: conversationB)
        #expect(try await waitForPersistedAndDrained(
            manager, store: store, messageID: assistantA.id, conversationID: conversationA
        ))
        #expect(try await waitForPersistedAndDrained(
            manager, store: store, messageID: assistantB.id, conversationID: conversationB
        ))

        manager.updateToolCallResult(
            MessageToolResult(content: "A only"),
            toolCallID: "call-1",
            assistantMessageID: assistantA.id,
            in: conversationA
        )

        #expect(Self.call(
            manager.messages(for: conversationA), messageID: assistantA.id, toolCallID: "call-1"
        )?.result?.content == "A only")
        #expect(
            manager.messages(for: conversationB).first?.toolCalls?.first?.result == nil
        )
        #expect(manager.pending.toolResultPatches(for: conversationB).isEmpty)
    }

    // MARK: - 写回顺序与清理

    @Test("同一消息的多次写回按顺序落盘，互不覆盖")
    func sequentialWritesDoNotClobberEachOther() async throws {
        let (store, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let manager = makeManager(store: store)
        let conversationID = UUID()
        let assistant = assistantMessage(
            conversationID: conversationID, toolCallIDs: ["call-1", "call-2"]
        )
        manager.insertMessage(assistant, to: conversationID)
        #expect(try await waitForPersistedAndDrained(
            manager, store: store, messageID: assistant.id, conversationID: conversationID
        ))

        // 三次写回都在后台队列里做「读-改-写」：若快照在入队前就取好，
        // 后一次会把前一次的结果整份覆盖掉。
        manager.updateToolCallResult(
            MessageToolResult(content: "one"),
            toolCallID: "call-1", assistantMessageID: assistant.id, in: conversationID
        )
        manager.updateToolCallResult(
            MessageToolResult(content: "two"),
            toolCallID: "call-2", assistantMessageID: assistant.id, in: conversationID
        )
        manager.updateToolCallResult(
            MessageToolResult(content: "one-newer"),
            toolCallID: "call-1", assistantMessageID: assistant.id, in: conversationID
        )

        let first = try await waitForDiskCall(
            store, messageID: assistant.id, toolCallID: "call-1",
            matching: { $0.result?.content == "one-newer" }
        )
        let second = try await waitForDiskCall(
            store, messageID: assistant.id, toolCallID: "call-2",
            matching: { $0.result?.content == "two" }
        )
        #expect(first?.result?.content == "one-newer")
        #expect(second?.result?.content == "two")

        // 落盘完成后补丁必须全部撤掉，不能常驻内存。
        #expect(manager.pending.toolResultPatches(for: conversationID).isEmpty)
        #expect(Self.call(
            manager.messages(for: conversationID), messageID: assistant.id, toolCallID: "call-2"
        )?.result?.content == "two")
    }

    @Test("补丁不带授权状态时，保留磁盘上已决定的授权状态")
    func patchWithoutAuthorizationStateKeepsResolvedState() async throws {
        let (store, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let manager = makeManager(store: store)
        let conversationID = UUID()
        let assistant = assistantMessage(
            conversationID: conversationID,
            toolCallIDs: ["call-1"],
            authorizationState: "userApproved"
        )
        manager.insertMessage(assistant, to: conversationID)
        #expect(try await waitForPersistedAndDrained(
            manager, store: store, messageID: assistant.id, conversationID: conversationID
        ))

        manager.updateToolCallResult(
            MessageToolResult(content: "refreshed"),
            toolCallID: "call-1",
            assistantMessageID: assistant.id,
            in: conversationID,
            authorizationState: nil
        )

        let immediate = Self.call(
            manager.messages(for: conversationID), messageID: assistant.id, toolCallID: "call-1"
        )
        #expect(immediate?.result?.content == "refreshed")
        #expect(immediate?.authorizationState == "userApproved")

        let persisted = try await waitForDiskCall(
            store, messageID: assistant.id, toolCallID: "call-1",
            matching: { $0.result?.content == "refreshed" }
        )
        #expect(persisted?.authorizationState == "userApproved")
    }

    @Test("删除消息会清掉尚未落盘的工具结果补丁")
    func deleteClearsPendingPatches() async throws {
        let (store, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let manager = makeManager(store: store)
        let conversationID = UUID()
        let assistant = assistantMessage(conversationID: conversationID, toolCallIDs: ["call-1"])
        manager.insertMessage(assistant, to: conversationID)
        #expect(try await waitForPersistedAndDrained(
            manager, store: store, messageID: assistant.id, conversationID: conversationID
        ))

        manager.pending.enqueueToolResult(
            PendingMessageBuffer.ToolResultPatch(
                result: MessageToolResult(content: "patched"), authorizationState: nil
            ),
            messageID: assistant.id, toolCallID: "call-1", conversationID: conversationID
        )

        manager.deleteMessage(id: assistant.id, in: conversationID)

        #expect(manager.pending.toolResultPatches(for: conversationID).isEmpty)
        #expect(store.fetchMessage(id: assistant.id) == nil)
        #expect(manager.messages(for: conversationID).isEmpty)
    }

    @Test("清空会话会清掉尚未落盘的工具结果补丁")
    func clearMessagesClearsPendingPatches() async throws {
        let (store, directory) = try makeStore()
        defer { try? FileManager.default.removeItem(at: directory) }
        let manager = makeManager(store: store)
        let conversationID = UUID()
        let assistant = assistantMessage(conversationID: conversationID, toolCallIDs: ["call-1"])
        manager.insertMessage(assistant, to: conversationID)
        #expect(try await waitForPersistedAndDrained(
            manager, store: store, messageID: assistant.id, conversationID: conversationID
        ))

        manager.pending.enqueueToolResult(
            PendingMessageBuffer.ToolResultPatch(
                result: MessageToolResult(content: "patched"), authorizationState: nil
            ),
            messageID: assistant.id, toolCallID: "call-1", conversationID: conversationID
        )

        manager.clearMessages(in: conversationID)

        #expect(manager.pending.toolResultPatches(for: conversationID).isEmpty)
        #expect(manager.messages(for: conversationID).isEmpty)
    }
}