import Foundation
import Testing
@testable import PluginSystemBenchmark

/// 回归 #521：内存读取循环按 64 字节跨步、每次只 load 8 字节，
/// read 吞吐必须按实际采样字节数计算，不能用整个缓冲区大小（否则虚高 8 倍）。
@Suite("Memory read throughput")
struct MemoryReadThroughputTests {
    // 64 KiB 缓冲区、2 趟：跨步 64 → 每趟 1024 次 load，每次 8 字节，
    // 实际采样 = 1024 * 8 * 2 = 16384 字节；整缓冲区 = 65536 * 2 = 131072 字节。
    private let bufferBytes = 64 * 1024
    private let passes = 2

    private func runMemoryReport() async throws -> BenchmarkReport {
        let runner = SystemBenchmarkRunner(
            configuration: .init(
                cpuIterations: 20_000,
                memoryBufferBytes: bufferBytes,
                memoryPasses: passes,
                diskBytes: 128 * 1024,
                diskChunkBytes: 16 * 1024
            )
        )
        return try await runner.run()
    }

    /// value(MiB/s) 与 duration(ms) 反推生成该测量所用的字节数：bytes = value * 1 MiB * seconds。
    /// 与计时噪声无关，因为 value 正是由 bytes 和 seconds 算出的。
    private func reportedBytes(_ measurement: BenchmarkMeasurement) -> Double {
        let seconds = max(measurement.durationMilliseconds / 1_000, 0.000_001)
        return measurement.value * 1024 * 1024 * seconds
    }

    @Test("read throughput reflects the actually sampled bytes, not the whole buffer")
    func readThroughputReflectsSampledBytes() async throws {
        let report = try await runMemoryReport()
        let read = try #require(report.measurements.first { $0.kind == .memory && $0.label == "read" })
        #expect(abs(reportedBytes(read) - 16_384) < 1.0)
    }

    @Test("write and copy still report the full buffer size")
    func writeAndCopyReportFullBuffer() async throws {
        let report = try await runMemoryReport()
        let fullBuffer = Double(bufferBytes * passes)
        let write = try #require(report.measurements.first { $0.kind == .memory && $0.label == "write" })
        let copy = try #require(report.measurements.first { $0.kind == .memory && $0.label == "copy" })
        #expect(abs(reportedBytes(write) - fullBuffer) < 1.0)
        #expect(abs(reportedBytes(copy) - fullBuffer) < 1.0)
    }
}