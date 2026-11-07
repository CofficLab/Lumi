import Foundation
import Testing
@testable import PluginNetworkManager

/// `ProcessMonitorService` nettop 输出解析的回归测试。
///
/// nettop 使用 `-d`（delta）模式时，每个进程的首帧输出仍是自进程启动以来的
/// 累计值；后续帧才是周期 delta。首帧若被当作 1 秒速度，会让历史累计字节
/// 长期占据进程榜单。
@MainActor
@Suite("ProcessMonitorService 采样解析")
struct ProcessMonitorParsingTests {

    private let header = ",bytes_in,bytes_out,\n"

    private func makeService() -> ProcessMonitorService {
        ProcessMonitorService.makeForTesting { nil }
    }

    @Test("首帧累计字节不会作为瞬时速度发布")
    func firstSampleIsIgnored() async throws {
        let service = makeService()

        service.processOutput(sample(name: "Lumi", pid: 4242, bytesIn: 900_000_000, bytesOut: 100_000_000))
        service.flushBuffer()
        try await Task.sleep(nanoseconds: 100_000_000)

        #expect(service.processes.isEmpty)
    }

    @Test("第二帧才按周期 delta 发布速度")
    func secondSamplePublishesDeltaSpeed() async throws {
        let service = makeService()

        service.processOutput(sample(name: "Lumi", pid: 4242, bytesIn: 900_000_000, bytesOut: 100_000_000))
        service.flushBuffer()
        service.processOutput(sample(name: "Lumi", pid: 4242, bytesIn: 1024, bytesOut: 2048))
        service.flushBuffer()
        try await Task.sleep(nanoseconds: 100_000_000)

        #expect(service.processes.count == 1)
        #expect(service.processes.first?.downloadSpeed == 1024)
        #expect(service.processes.first?.uploadSpeed == 2048)
    }

    private func sample(name: String, pid: Int, bytesIn: Double, bytesOut: Double) -> Data {
        Data("\(header)\(name).\(pid),\(Int64(bytesIn)),\(Int64(bytesOut)),\n".utf8)
    }
}
