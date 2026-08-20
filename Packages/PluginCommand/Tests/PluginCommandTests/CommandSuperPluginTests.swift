import KernelCore
import ProviderCommand
import Testing
@testable import PluginCommand

@MainActor
struct CommandSuperPluginTests {
    @Test("boot replaces the fallback provider and retains the Debug menu")
    func bootRegistersDebugMenu() throws {
        let kernel = KernelCoreContainer()
        try kernel.registerProvider(
            (any CommandProviding).self,
            DefaultCommandProviding()
        )

        let plugin = CommandSuperPlugin()
        try plugin.onBoot(kernel: kernel)

        let groups = try #require(
            kernel.resolveProvider((any CommandProviding).self)?.allCommandGroups
        )
        #expect(groups.map(\.id) == ["com.coffic.lumi.plugin.command.debug"])
        #expect(groups.first?.name == "DEBUG")
        #expect(groups.first?.items.count == 4)
        #expect(groups.first?.placement == .topLevelMenu)
    }
}
