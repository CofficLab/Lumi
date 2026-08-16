import FactoryLumi2
import KernelCore
import ProviderPluginControl
import ProviderWebServer
import ProviderWorkspace
import Testing

@Suite("FactoryLumi2 Infrastructure")
@MainActor
struct KernelFactoryInfrastructureTests {
    private final class AsyncProbePlugin: AsyncSuperPlugin {
        let id = "test.async-probe"
        var didBoot = false
        var didBecomeReady = false

        func onBootAsync(kernel: KernelCoreContainer) async throws {
            await Task.yield()
            didBoot = true
        }

        func onReadyAsync(kernel: KernelCoreContainer) async throws {
            await Task.yield()
            didBecomeReady = true
        }
    }

    @Test("异步 Factory 入口启动异步插件")
    func startsAsyncPlugins() async throws {
        let probe = AsyncProbePlugin()
        let kernel = try await KernelFactory.makeKernelAsync(additionalPlugins: [probe])

        #expect(probe.didBoot)
        #expect(probe.didBecomeReady)
        #expect(kernel.isPluginRegistered(id: probe.id))
        #expect(kernel.lifecycleState == .running)
    }

    @Test("Factory 注册可替换 WebServer 与真实 PluginControl")
    func registersInfrastructureProviders() throws {
        let kernel = try KernelFactory.makeKernel()

        #expect(kernel.resolveProvider((any WebServerProviding).self) != nil)
        #expect(kernel.resolveProvider((any PluginControlling).self) != nil)
        let workspace = kernel.resolveProvider((any WorkspaceProviding).self)
        #expect(workspace?.activeContainerID == "com.coffic.lumi.plugin.chat-panel")
        #expect(workspace?.currentContainer?.chatVisibility == .alwaysVisible)
        #expect(workspace?.currentContainer?.panelBodyVisibility == .unsupported)
    }
}
