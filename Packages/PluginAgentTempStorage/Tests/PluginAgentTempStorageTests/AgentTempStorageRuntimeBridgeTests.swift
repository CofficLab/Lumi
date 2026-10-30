import Foundation
import KitTestIsolation
import KitTestSupport
import Testing
@testable import PluginAgentTempStorage

// MARK: - 运行时目录

/// `AgentTempStoragePluginRuntimeBridge.resolvedPluginDirectory` 由 `onBoot`
/// 从 `StorageProviding` 注入。测试进程里没有注入时守卫会直接拒绝（而不是回退到
/// 本机真实数据目录），这里锁定这条契约的正反两面。
///
/// - Note: `.serialized`：本组用例会改写同一个全局注入位，必须串行执行。
@Suite("临时存储运行时目录", .serialized)
struct AgentTempStorageRuntimeBridgeTests {

    @Test("注入目录后 resolvedPluginDirectory 返回该目录")
    func injectedDirectoryResolvesToInjectedDirectory() throws {
        let temporary = try TemporaryDirectory.make("agent-temp-storage-bridge-injected")
        defer { temporary.remove() }
        AgentTempStoragePluginRuntimeBridge.pluginDirectory = temporary.url
        defer { AgentTempStoragePluginRuntimeBridge.pluginDirectory = nil }

        #expect(AgentTempStoragePluginRuntimeBridge.resolvedPluginDirectory == temporary.url)
    }

    @Test("注入目录后共享存储与本地存储都落在该目录下")
    func sharedStorageUsesInjectedDirectory() async throws {
        let temporary = try TemporaryDirectory.make("agent-temp-storage-bridge-shared")
        defer { temporary.remove() }
        AgentTempStoragePluginRuntimeBridge.pluginDirectory = temporary.url
        defer { AgentTempStoragePluginRuntimeBridge.pluginDirectory = nil }

        // `TempFileStorageService.shared` 与 `AgentTempStoragePluginLocalStore.shared`
        // 都是进程级懒加载单例：首次初始化会读 `resolvedPluginDirectory`。
        // 注入到位之后再访问，它们才不会落到本机真实数据目录。
        let store = AgentTempStoragePluginLocalStore.shared
        #expect(store.retentionDays == 7)

        let service = TempFileStorageService.shared
        let expected = temporary.url.appendingPathComponent("files", isDirectory: true).path
        #expect(await service.storageDirectoryPath == expected)
    }

    @Test("未注入目录时守卫拒绝回退到真实数据目录")
    func refusesFallbackWithoutInjection() throws {
        let temporary = try TemporaryDirectory.make("agent-temp-storage-bridge-refused")
        defer { temporary.remove() }
        AgentTempStoragePluginRuntimeBridge.pluginDirectory = nil
        defer { AgentTempStoragePluginRuntimeBridge.pluginDirectory = nil }

        #expect(AgentTempStoragePluginRuntimeBridge.pluginDirectory == nil)

        switch IsolatedDirectoryGuard.resolve(
            injected: AgentTempStoragePluginRuntimeBridge.pluginDirectory,
            owner: "AgentTempStoragePluginRuntimeBridge",
            accessor: "resolvedPluginDirectory",
            fallback: { URL(fileURLWithPath: "/tmp/agent-temp-storage-fallback", isDirectory: true) }
        ) {
        case .resolved:
            Issue.record("测试进程下未注入目录时不应回退到真实数据目录")
        case let .refused(reason):
            #expect(reason.contains("AgentTempStoragePluginRuntimeBridge"))
            #expect(reason.contains("resolvedPluginDirectory"))
        }
    }
}
