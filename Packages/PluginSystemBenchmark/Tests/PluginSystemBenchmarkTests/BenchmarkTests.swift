import Testing
@testable import PluginSystemBenchmark

struct BenchmarkTests {
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
