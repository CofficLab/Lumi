import Testing
@testable import KernelCore

@Suite("KernelCore Plugin Contributions")
@MainActor
struct KernelCoreContributionTests {
    private final class ContributionPlugin: SuperPlugin {
        let id = "contributor"
        var cleanupEvents: [String] = []

        func onBoot(kernel: KernelCoreContainer) throws {
            try kernel.trackContribution {
                self.cleanupEvents.append("boot-cleanup")
            }
        }

        func onEnable(kernel: KernelCoreContainer) async throws {
            try kernel.trackContribution {
                self.cleanupEvents.append("enable-cleanup")
            }
        }

        func onDisable(kernel: KernelCoreContainer) async throws {
            cleanupEvents.append("disable")
        }
    }

    @Test("停止插件时自动逆序撤回共享贡献")
    func stopCancelsContributions() throws {
        let plugin = ContributionPlugin()
        let kernel = KernelCoreContainer()
        try kernel.start(plugins: [plugin])

        #expect(kernel.activeContributionCount(ownedBy: plugin.id) == 1)
        try kernel.stop()

        #expect(plugin.cleanupEvents == ["boot-cleanup"])
        #expect(kernel.activeContributionCount(ownedBy: plugin.id) == 0)
    }

    @Test("运行时禁用撤回贡献，重新启用可登记新贡献")
    func runtimeDisableAndEnable() async throws {
        let plugin = ContributionPlugin()
        let kernel = KernelCoreContainer()
        try kernel.start(plugins: [plugin])

        try await kernel.disablePlugin(id: plugin.id)
        #expect(!kernel.isPluginEnabled(id: plugin.id))
        #expect(plugin.cleanupEvents == ["disable", "boot-cleanup"])

        try await kernel.enablePlugin(id: plugin.id)
        #expect(kernel.isPluginEnabled(id: plugin.id))
        #expect(kernel.activeContributionCount(ownedBy: plugin.id) == 1)
    }

    @Test("未提交事务会逆序回滚")
    func transactionRollback() {
        var values: [Int] = []
        let transaction = PluginContributionTransaction()
        transaction.addCleanup { values.append(1) }
        transaction.addCleanup { values.append(2) }

        transaction.rollback()
        #expect(values == [2, 1])
    }

    @Test("生命周期外登记贡献必须显式指定 owner")
    func ownerIsRequiredOutsideLifecycle() throws {
        let kernel = KernelCoreContainer()
        #expect(throws: KernelCoreError.self) {
            try kernel.trackContribution {}
        }
    }
}
