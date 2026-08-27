import KernelCore
import ProviderCommand
import Foundation
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

        let plugin = CommandPlugin()
        try plugin.onBoot(kernel: kernel)

        let groups = try #require(
            kernel.resolveProvider((any CommandProviding).self)?.allCommandGroups
        )
        #expect(groups.map(\.id) == ["com.coffic.lumi.plugin.command.debug"])
        #expect(groups.first?.name == DebugCommands.localizedMenuName())
        #expect(groups.first?.items.count == 4)
        #expect(groups.first?.placement == .topLevelMenu)
    }

    @Test("Debug 菜单标题支持中文本地化")
    func debugMenuTitleIsLocalizedInChinese() {
        #expect(DebugCommands.localizedMenuName(locale: Locale(identifier: "zh-Hans")) == "调试")
    }
}
