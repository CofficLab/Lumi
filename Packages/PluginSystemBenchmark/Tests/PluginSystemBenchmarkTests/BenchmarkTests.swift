import KernelCore
import ProviderActivityBar
import ProviderContentView
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
        let activityBar = DefaultActivityBarProviding()
        let contentView = TrackingContentView()
        activityBar.registerItems([
            ActivityBarItem(id: "other", title: "Other", systemImage: "circle"),
        ])
        try kernel.registerProvider((any ActivityBarProviding).self, activityBar)
        try kernel.registerProvider((any ContentViewProviding).self, contentView)

        let plugin = SystemBenchmarkPlugin()
        try plugin.onBoot(kernel: kernel)

        // 测速功能只通过 Activity Bar 暴露入口，不再注册设置项。
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

    @Test("用户主动取消显示中性的已取消状态，而不是失败")
    func cancellingReportsNeutralState() async throws {
        let viewModel = SystemBenchmarkViewModel(runner: EndlessBenchmarkRunner())
        viewModel.start()
        try await Self.waitUntil { viewModel.progress == .cpu }

        viewModel.cancel()
        try await Self.waitUntil { !viewModel.isRunning }

        #expect(viewModel.cancellationMessage != nil)
        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.report == nil)
    }

    @Test("真实测试错误仍显示为失败")
    func failureStillReportsError() async throws {
        let viewModel = SystemBenchmarkViewModel(runner: FailingBenchmarkRunner())
        viewModel.start()
        try await Self.waitUntil { !viewModel.isRunning }

        #expect(viewModel.errorMessage == "benchmark exploded")
        #expect(viewModel.cancellationMessage == nil)
        #expect(viewModel.report == nil)
    }

    private static func waitUntil(_ condition: @MainActor () -> Bool) async throws {
        for _ in 0..<400 {
            if condition() { return }
            try await Task.sleep(for: .milliseconds(5))
        }
        #expect(condition(), "condition not met before timeout")
    }
}

/// 跑到 `.cpu` 后一直挂起，直到任务被取消。
private actor EndlessBenchmarkRunner: SystemBenchmarkRunning {
    func run(
        progress: @escaping @Sendable (BenchmarkProgress) async -> Void
    ) async throws -> BenchmarkReport {
        await progress(.cpu)
        while true {
            try await Task.sleep(for: .milliseconds(10))
        }
    }
}

private struct FailingBenchmarkRunner: SystemBenchmarkRunning {
    struct Failure: LocalizedError {
        var errorDescription: String? { "benchmark exploded" }
    }

    func run(
        progress: @escaping @Sendable (BenchmarkProgress) async -> Void
    ) async throws -> BenchmarkReport {
        throw Failure()
    }
}
