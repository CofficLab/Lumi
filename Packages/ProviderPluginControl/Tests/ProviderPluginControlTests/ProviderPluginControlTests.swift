import KernelCore
import ProviderPluginControl
import Testing

@Suite("ProviderPluginControl")
@MainActor
struct ProviderPluginControlTests {
    private final class RuntimePlugin: SuperPlugin {
        let id = "runtime"
        var events: [String] = []

        func onEnable(kernel: KernelCoreContainer) async throws {
            events.append("enable")
        }

        func onDisable(kernel: KernelCoreContainer) async throws {
            events.append("disable")
        }
    }

    @Test("控制 Provider 驱动真实 Kernel 插件状态")
    func controlsKernelState() async throws {
        let kernel = KernelCoreContainer()
        let plugin = RuntimePlugin()
        try kernel.start(plugins: [plugin])
        let controller = DefaultPluginControlling(kernel: kernel)

        #expect(controller.isEnabled(id: plugin.id))
        #expect(await controller.disablePlugin(id: plugin.id))
        #expect(!controller.isEnabled(id: plugin.id))
        #expect(plugin.events == ["disable"])

        #expect(await controller.enablePlugin(id: plugin.id))
        #expect(controller.isEnabled(id: plugin.id))
        #expect(plugin.events == ["disable", "enable"])
        #expect(controller.lastErrorDescription == nil)
    }

    @Test("未知插件失败并暴露错误")
    func reportsKernelErrors() async throws {
        let kernel = KernelCoreContainer()
        try kernel.start(plugins: [])
        let controller = DefaultPluginControlling(kernel: kernel)

        #expect(!(await controller.disablePlugin(id: "missing")))
        #expect(controller.lastErrorDescription?.contains("missing") == true)
    }
}
