import Foundation
import KernelCore
import KitMCP
import ProviderStorage
import Testing
@testable import PluginMCP

/// 回归 #141：`onShutdown` 调度异步清理后立刻把 `manager` 置 nil。
///
/// 旧实现用 `Task { [weak manager] in ... }` 弱捕获，随后同步 `manager = nil`
/// 释放了唯一强引用，Task 真正运行时弱引用已为 nil，`disconnectAllSessions()`
/// 被静默跳过，会话（子进程 / HTTP 连接）从未断开。修复改为先持有强引用再调度。
@Suite("MCP 插件关闭", .serialized)
@MainActor
struct MCPPluginShutdownTests {

    @Test("关闭时异步清理确实断开会话（强引用 manager，不被置 nil 竞态吞掉）")
    func shutdownDisconnectsSessions() async throws {
        let root = MCPTestDoubles.makeTemporaryDirectory("shutdown")
        let storage = MCPTestDoubles.StubStorageProvider(root: root)
        let kernel = KernelCoreContainer()
        try kernel.registerProvider((any StorageProviding).self, storage)

        let plugin = MCPPlugin()
        try plugin.onBoot(kernel: kernel)

        let session = ObservableSession(config: MCPServerConfig(name: "obs", command: "noop"))
        // 经独立函数注入：函数返回后测试侧不再强引用 manager，使 plugin.manager
        // 成为唯一强引用，忠实复现「弱捕获 + 随后置 nil」的竞态。
        try attachObservableSession(session, to: plugin)

        try plugin.onShutdown(kernel: kernel)

        // 等待 fire-and-forget 清理 Task 完成（最多 ~2s）。修复前弱引用为 nil，
        // disconnect 永远不会发生，计数停在 0 → 断言失败（RED）。
        let deadline = Date().addingTimeInterval(2)
        while await session.disconnectCount == 0, Date() < deadline {
            try await Task.sleep(nanoseconds: 5_000_000)
        }
        #expect(await session.disconnectCount == 1)
    }

    private func attachObservableSession(_ session: ObservableSession, to plugin: MCPPlugin) throws {
        let manager = try #require(plugin.manager)
        manager.attachSessionForTesting(session, serverID: "obs")
    }
}

/// 可观察的会话替身：记录 `disconnect()` 调用次数，其余协议方法为空实现。
private actor ObservableSession: MCPServerServing {
    private(set) var disconnectCount = 0
    let config: MCPServerConfig
    var isConnected: Bool = false

    init(config: MCPServerConfig) {
        self.config = config
    }

    func connect() async throws {}

    func disconnect() async {
        disconnectCount += 1
    }

    func listTools() async throws -> [MCPToolDescriptor] { [] }

    func callTool(name: String, arguments: [String: MCPJSONValue]) async throws -> MCPCallResult {
        throw MCPClientError.notConnected
    }
}