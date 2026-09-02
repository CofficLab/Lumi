import KernelCore
import ProviderPerformanceMetrics
import ProviderSettingView
import Testing
@testable import PluginPerformanceMetrics

@MainActor
struct PerformanceMetricsPluginTests {
    @Test("registers the provider and settings entry")
    func registersProviderAndSettings() throws {
        let kernel = KernelCoreContainer()
        let settings = DefaultSettingViewProviding()
        try kernel.registerProvider((any SettingViewProviding).self, settings)

        let plugin = PerformanceMetricsPlugin()
        try plugin.onBoot(kernel: kernel)

        #expect(kernel.resolveProvider((any PerformanceMetricsProviding).self) != nil)
        #expect(settings.entries.contains(where: { $0.id == plugin.id }))
    }
}
