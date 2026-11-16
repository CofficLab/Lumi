import Foundation
import Testing
@testable import PluginSystemBenchmark

/// CPU 基准负载的协作式取消（#257）。
///
/// 曾经的实现：`cpuWork` 是一个没有任何取消检查的紧凑循环，单核直接跑完整段迭代，
/// 多核用**非抛出**的 `withTaskGroup` 等所有 worker 跑完。Cancel 只取消外层 Task，
/// 但 CPU 循环不检查取消，于是剩余单核/多核负载继续执行，UI 停在 Running、
/// 关闭插件后 CPU 仍被占用，直到整段迭代自然结束。
///
/// 既有的 `cancellingReportsNeutralState` 用的是会 `Task.sleep` 的替身 runner，
/// 天然可取消，**没有**覆盖真实 CPU 循环这条路径。这组用例改用真实
/// `SystemBenchmarkRunner` + 大到完整跑需数秒的 `cpuIterations`，锁定：
/// 取消后负载在毫秒级停下（而不是跑完数秒），并以 `CancellationError` 告终、
/// `isRunning` 尽快复位。完整负载远大于断言上限，因此禁用取消检查的变异会变红。
@MainActor
@Suite("CPU 基准负载取消后尽快停下")
struct SystemBenchmarkCancellationTests {

    /// 大到完整单核+多核跑完需数秒的迭代数；取消后应在毫秒级停下。
    private let heavyIterations = 4_000_000_000

    private func makeHeavyRunner() -> SystemBenchmarkRunner {
        SystemBenchmarkRunner(
            configuration: .init(
                cpuIterations: heavyIterations,
                memoryBufferBytes: 64 * 1024,
                memoryPasses: 1,
                diskBytes: 128 * 1024,
                diskChunkBytes: 16 * 1024
            )
        )
    }

    private static func waitUntil(_ condition: @MainActor () -> Bool) async throws {
        for _ in 0..<400 {
            if condition() { return }
            try await Task.sleep(for: .milliseconds(5))
        }
        #expect(condition(), "condition not met before timeout")
    }

    // MARK: - 真实 runner：取消后 CPU 迭代尽快停止

    @Test("取消后真实 CPU 负载在毫秒级停下，不跑完整段迭代")
    func cancelledCPURunStopsPromptly() async throws {
        let runner = makeHeavyRunner()
        let runTask = Task { try await runner.run() }

        // 确保已进入单核 CPU 循环后再取消，命中循环内部的周期性取消检查。
        try await Task.sleep(for: .milliseconds(50))
        let cancelStart = DispatchTime.now().uptimeNanoseconds
        runTask.cancel()
        let result = await runTask.result
        let elapsedMilliseconds = Double(DispatchTime.now().uptimeNanoseconds - cancelStart) / 1_000_000

        #expect(throws: CancellationError.self) { try result.get() }
        #expect(
            elapsedMilliseconds < 2_000,
            "取消后应在毫秒级停下，实际 \(elapsedMilliseconds)ms（完整负载需数秒）"
        )
    }

    // MARK: - 真实 runner + ViewModel：isRunning 尽快复位

    @Test("真实 CPU 负载下取消后 isRunning 尽快复位且为中性已取消状态")
    func cancelResetsIsRunningPromptlyWithRealCPU() async throws {
        let viewModel = SystemBenchmarkViewModel(runner: makeHeavyRunner())
        viewModel.start()
        try await Self.waitUntil { viewModel.progress == .cpu }

        viewModel.cancel()
        // 若 CPU 循环忽略取消，真实负载需数秒才返回，2s 轮询窗口内 isRunning 不会复位。
        try await Self.waitUntil { !viewModel.isRunning }

        #expect(viewModel.cancellationMessage != nil)
        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.report == nil)
    }

    // MARK: - 对照：未取消的小配置仍正常产出 CPU 报告

    @Test("未取消时小配置仍正常产出单核与多核 CPU 测量")
    func uncancelledSmallRunStillProducesCPUReport() async throws {
        let runner = SystemBenchmarkRunner(
            configuration: .init(
                cpuIterations: 200_000,
                memoryBufferBytes: 64 * 1024,
                memoryPasses: 1,
                diskBytes: 128 * 1024,
                diskChunkBytes: 16 * 1024
            )
        )
        let report = try await runner.run()
        let cpu = report.measurements.filter { $0.kind == .cpu }
        #expect(cpu.contains { $0.label == "single-core" })
        #expect(cpu.contains { $0.label == "multi-core" })
        #expect(cpu.allSatisfy { $0.value > 0 })
    }
}