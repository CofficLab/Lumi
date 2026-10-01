import KernelCore
import ProviderActivityBar
import ProviderContentView
import ProviderSettingView
import SwiftUI
import Testing
@testable import PluginSystemBenchmark

@Suite("PluginSystemBenchmark")
@MainActor
struct BenchmarkTests {
    @Test("plugin registers an Activity Bar entry and shared dashboard content")
    func pluginRegistersActivityBarEntry() throws {
        @MainActor final class TrackingContentView: ContentViewProviding {
            private(set) var setCount = 0

            func setContentView(_ view: AnyView?) {
                if view != nil {
                    setCount += 1
                }
            }

            func makeContentView() -> AnyView {
                AnyView(EmptyView())
            }
        }

        let kernel = KernelCoreContainer()
        let settings = DefaultSettingViewProviding()
        let activityBar = DefaultActivityBarProviding()
        let contentView = TrackingContentView()
        activityBar.registerItems([
            ActivityBarItem(id: "other", title: "Other", systemImage: "circle"),
        ])
        try kernel.registerProvider((any SettingViewProviding).self, settings)
        try kernel.registerProvider((any ActivityBarProviding).self, activityBar)
        try kernel.registerProvider((any ContentViewProviding).self, contentView)

        let plugin = SystemBenchmarkPlugin()
        try plugin.onBoot(kernel: kernel)

        #expect(settings.entries.count == 1)
        let entry = activityBar.items.first { $0.id == "\(plugin.id).entry" }
        #expect(entry != nil)
        #expect(entry?.ownerPluginID == plugin.id)

        activityBar.activateItem(id: "\(plugin.id).entry")
        #expect(contentView.setCount == 1)
    }

    @Test("progress advances in benchmark order")
    func progressFractions() {
        #expect(BenchmarkProgress.preparing.fraction == 0)
        #expect(BenchmarkProgress.cpu.fraction < BenchmarkProgress.memory.fraction)
        #expect(BenchmarkProgress.memory.fraction < BenchmarkProgress.disk.fraction)
        #expect(BenchmarkProgress.disk.fraction < BenchmarkProgress.finished.fraction)
    }

    @Test("small configuration runs all local benchmark types")
    func smallBenchmarkRuns() async throws {
        let runner = SystemBenchmarkRunner(
            configuration: .init(
                cpuIterations: 20_000,
                memoryBufferBytes: 64 * 1024,
                memoryPasses: 1,
                diskBytes: 128 * 1024,
                diskChunkBytes: 16 * 1024
            )
        )

        let report = try await runner.run()
        #expect(report.measurements.contains { $0.kind == .cpu })
        #expect(report.measurements.contains { $0.kind == .memory })
        #expect(report.measurements.contains { $0.kind == .disk })
        #expect(report.measurements.allSatisfy { $0.value > 0 })
    }

    @Test("invalid configuration is rejected")
    func invalidConfiguration() async {
        let runner = SystemBenchmarkRunner(configuration: .init(cpuIterations: 0))

        await #expect(throws: BenchmarkError.self) {
            try await runner.run()
        }
    }
}
