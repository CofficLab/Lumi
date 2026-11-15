import Foundation
import MCP
import Testing
@testable import KitMCP

/// 取消 MCP 工具调用的回归测试（#178）。
///
/// 核心场景：服务器收到 CallTool 后永不响应，客户端取消任务时调用必须
/// 立即以 CancellationError 结束，而不是永远挂起等待服务器回包。
@Suite("MCPServerSession 取消")
struct MCPCancellationTests {

    // MARK: - 测试基础设施

    /// CallTool 处理器的门闩：先报告「请求已到达」，再挂起等待放行。
    private actor HangGate {
        private var arrived = false
        private var released = false
        private var arrivalWaiters: [CheckedContinuation<Void, Never>] = []
        private var releaseWaiters: [CheckedContinuation<Void, Never>] = []

        var hasArrived: Bool { arrived }

        func arrive() {
            arrived = true
            let waiters = arrivalWaiters
            arrivalWaiters = []
            for waiter in waiters { waiter.resume() }
        }

        func waitArrival() async {
            if arrived { return }
            await withCheckedContinuation { arrivalWaiters.append($0) }
        }

        func waitRelease() async {
            if released { return }
            await withCheckedContinuation { releaseWaiters.append($0) }
        }

        func release() {
            released = true
            let waiters = releaseWaiters
            releaseWaiters = []
            for waiter in waiters { waiter.resume() }
        }
    }

    /// 记录服务器收到的取消通知。
    private actor CancelNotificationBox {
        private(set) var requestIDs: [ID?] = []
        private var waiters: [CheckedContinuation<Void, Never>] = []

        func record(_ requestID: ID?) {
            requestIDs.append(requestID)
            let pending = waiters
            waiters = []
            for waiter in pending { waiter.resume() }
        }

        func waitForNotification() async {
            if !requestIDs.isEmpty { return }
            await withCheckedContinuation { waiters.append($0) }
        }
    }

    /// 构造 CallTool 永不主动响应的 mock 服务器（挂起在门闩上）。
    private func makeHangingServer(
        gate: HangGate,
        notifications: CancelNotificationBox
    ) async throws -> MCPPreparedTransport {
        let (clientTransport, serverTransport) = await InMemoryTransport.createConnectedPair()
        let server = Server(name: "HangingMock", version: "1.0.0")
        await server.withMethodHandler(CallTool.self) { _ in
            await gate.arrive()
            await gate.waitRelease()
            return CallTool.Result(
                content: [.text(text: "late", annotations: nil, _meta: nil)],
                isError: false
            )
        }
        await server.onNotification(CancelledNotification.self) { message in
            await notifications.record(message.params.requestId)
        }
        try await server.start(transport: serverTransport)
        return MCPPreparedTransport(transport: clientTransport)
    }

    private func makeSession(prepared: MCPPreparedTransport) -> MCPServerSession {
        let config = MCPServerConfig(name: "HangingMock", command: "/bin/echo", arguments: [])
        return MCPServerSession(config: config, prepare: { _ in prepared })
    }

    /// 带看门狗地等待调用结果；超时返回 nil。
    /// 无论谁先到都放行门闩，保证服务器处理器能收尾、任务组不残留挂起。
    private func awaitWithWatchdog(
        _ task: Task<MCPCallResult, Error>,
        gate: HangGate,
        timeoutNanoseconds: UInt64 = 5_000_000_000
    ) async -> Result<MCPCallResult, Error>? {
        await withTaskGroup(of: Result<MCPCallResult, Error>?.self) { group in
            group.addTask { await task.result }
            group.addTask {
                try? await Task.sleep(nanoseconds: timeoutNanoseconds)
                return nil
            }
            let first = await group.next() ?? nil
            await gate.release()
            group.cancelAll()
            return first
        }
    }

    // MARK: - 用例

    @Test("服务器永不响应时取消仍必须立即结束调用（**#178**）")
    func cancellationCompletesWhenServerNeverResponds() async throws {
        let gate = HangGate()
        let notifications = CancelNotificationBox()
        let prepared = try await makeHangingServer(gate: gate, notifications: notifications)
        let session = makeSession(prepared: prepared)
        try await session.connect()

        let callTask = Task {
            try await session.callTool(name: "hang", arguments: [:])
        }
        await gate.waitArrival()
        callTask.cancel()

        let outcome = await awaitWithWatchdog(callTask, gate: gate)
        let result = try #require(outcome, "取消后调用仍在等待服务器响应，Job 会永远停在 cancelling（#178）")
        #expect(throws: CancellationError.self) { try result.get() }

        // 本地立即结束之外，还应尽力向服务器发送协议取消通知。
        await notifications.waitForNotification()
        #expect(await notifications.requestIDs.count == 1)
        #expect(await notifications.requestIDs.first != nil)

        await session.disconnect()
    }

    @Test("已取消的任务进入 callTool 时不得发出请求（**#178**）")
    func preCancelledCallDoesNotSendRequest() async throws {
        let gate = HangGate()
        let notifications = CancelNotificationBox()
        let prepared = try await makeHangingServer(gate: gate, notifications: notifications)
        let session = makeSession(prepared: prepared)
        try await session.connect()

        let callTask = Task {
            // 先确保取消已生效，再进入 callTool，模拟调度层取消后才轮到执行。
            while !Task.isCancelled { await Task.yield() }
            return try await session.callTool(name: "hang", arguments: [:])
        }
        callTask.cancel()

        let outcome = await awaitWithWatchdog(callTask, gate: gate)
        let result = try #require(outcome, "预取消的调用未立即结束（#178）")
        #expect(throws: CancellationError.self) { try result.get() }
        #expect(await gate.hasArrived == false)

        await session.disconnect()
    }
}