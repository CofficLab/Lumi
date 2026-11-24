import Foundation
import MCP
import Testing
@testable import KitMCP

/// stdio 子进程意外退出观测回归（#473）。
///
/// 此前会话只在下一次操作进入 `connectedClient()` 时被动查询退出状态，
/// 子进程外部被杀后 `isConnected` 一直是 true，上层也拿不到任何退出通知，
/// Manager 的 Running 状态与已注册工具永远过期。
@Suite("MCPServerSession 意外退出观测")
struct MCPServerSessionTerminationTests {

    /// 构造带进程退出流的会话：配对 InMemoryTransport 上必须跑一个 mock
    /// Server，`Client.connect` 的 initialize 握手才有应答（对端缺席会挂起）。
    /// 测试持有 `processExit` 续体模拟子进程退出。
    private static func makeSession(
        processExit: AsyncStream<Int32>?
    ) async throws -> (session: MCPServerSession, exitContinuation: AsyncStream<Int32>.Continuation) {
        let config = MCPServerConfig(name: "Mock", command: "/bin/echo", arguments: [])
        let clientTransport = try await Self.makePairedClientTransport()
        let (stream, continuation) = AsyncStream.makeStream(of: Int32.self)
        let session = MCPServerSession(config: config, prepare: { _ in
            MCPPreparedTransport(transport: clientTransport, processExit: processExit ?? stream)
        })
        return (session, continuation)
    }

    private static func makePairedClientTransport() async throws -> any Transport {
        let (clientTransport, serverTransport) = await InMemoryTransport.createConnectedPair()
        let server = Server(name: "MockServer", version: "1.0.0")
        try await server.start(transport: serverTransport)
        return clientTransport
    }

    @Test("子进程意外退出：事件流发出退出码且 isConnected 清零")
    func unexpectedExitYieldsEventAndClearsConnectedState() async throws {
        let (session, exitContinuation) = try await Self.makeSession(processExit: nil)
        try await session.connect()
        #expect(await session.isConnected)
        defer { Task { await session.disconnect() } }

        let events = try #require(
            await session.unexpectedTerminationEvents(),
            "stdio 会话必须提供意外退出事件流"
        )
        exitContinuation.yield(9)
        exitContinuation.finish()

        var received: [Int32] = []
        for await code in events {
            received.append(code)
        }
        #expect(received == [9], "意外退出必须以退出码上报（#473）")
        #expect(await session.isConnected == false)
        #expect(await session.lastTerminationStatus == 9)
    }

    @Test("主动 disconnect 后的退出不算意外：事件流结束且无事件")
    func intentionalDisconnectDoesNotEmitUnexpectedExit() async throws {
        let (session, exitContinuation) = try await Self.makeSession(processExit: nil)
        try await session.connect()
        let events = try #require(await session.unexpectedTerminationEvents())

        await session.disconnect()

        // disconnect 先置主动停止标记再终止子进程；terminate 引发的退出
        // 必须被吞掉，不得上报为意外退出（#473）。
        exitContinuation.yield(15)
        exitContinuation.finish()

        var received: [Int32] = []
        for await code in events {
            received.append(code)
        }
        #expect(received.isEmpty)
        #expect(await session.isConnected == false)
    }

    @Test("无退出流时 unexpectedTerminationEvents 返回 nil（默认实现不变）")
    func sessionWithoutExitStreamExposesNoEvents() async throws {
        let config = MCPServerConfig(name: "Mock", command: "/bin/echo", arguments: [])
        let clientTransport = try await Self.makePairedClientTransport()
        let session = MCPServerSession(config: config, prepare: { _ in
            MCPPreparedTransport(transport: clientTransport)
        })
        try await session.connect()
        defer { Task { await session.disconnect() } }

        let events = await session.unexpectedTerminationEvents()
        #expect(events == nil)
    }
}
