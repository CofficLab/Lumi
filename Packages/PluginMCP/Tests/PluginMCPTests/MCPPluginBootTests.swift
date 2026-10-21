import Foundation
import KernelCore
import KitTestIsolation
import ProviderMCP
import ProviderStorage
import Testing
@testable import PluginMCP

/// 插件启动与运行时目录守卫的测试。
///
/// `MCPPlugin.onBoot(kernel:)` 通过守卫解析插件数据目录：解析不到
/// `StorageProviding` 时直接失败，而不是回退到本机真实数据目录。因此启动
/// 用例必须注册一个根落在临时目录的存储 Provider。
@Suite("MCP 插件启动", .serialized)
@MainActor
struct MCPPluginBootTests {

    @Test("启动时从 StorageProviding 解析插件数据目录")
    func bootResolvesPluginDataDirectory() throws {
        let root = MCPTestDoubles.makeTemporaryDirectory("boot")
        let storage = MCPTestDoubles.StubStorageProvider(root: root)
        let kernel = KernelCoreContainer()
        try kernel.registerProvider((any StorageProviding).self, storage)

        let plugin = MCPPlugin()
        try plugin.onBoot(kernel: kernel)

        // 守卫要求数据目录来自注入的 StorageProviding：插件必须向它要自己的目录。
        #expect(
            storage.requestedPluginDirectories[plugin.id]
                == root.appendingPathComponent(plugin.id, isDirectory: true)
        )
        // 启动后贡献收集器已注册，其它插件可以贡献内置服务器模板。
        #expect(kernel.resolveProvider((any MCPServerContributionProviding).self) != nil)
    }

    @Test("未注册 StorageProviding 时守卫拒绝回退到真实数据目录")
    func refusesWithoutStorageProvider() {
        // 守卫契约：解析不到存储目录时必须拒绝，而不是回退到本机真实数据目录。
        switch IsolatedDirectoryGuard.resolve(
            injected: nil,
            owner: "MCPPlugin",
            accessor: "onBoot(kernel:)",
            fallback: { URL(fileURLWithPath: "/tmp/mcp-plugin-fallback", isDirectory: true) }
        ) {
        case .resolved:
            Issue.record("测试进程下未解析到存储目录时不应回退到真实数据目录")
        case let .refused(reason):
            #expect(reason.contains("MCPPlugin"))
            #expect(reason.contains("onBoot(kernel:)"))
        }
    }
}
