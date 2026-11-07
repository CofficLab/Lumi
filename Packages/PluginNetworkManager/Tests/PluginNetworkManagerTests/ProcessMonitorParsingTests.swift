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

    @Test("截断到同名的不同进程按完整名称区分，不会错误合并")
    func truncatedNamesAreResolvedAndNotMerged() async throws {
        let service = ProcessMonitorService.makeForTesting(nettopLauncher: { nil }) { pid in
            switch pid {
            case 100: return "com.apple.WebKit.WebContent"
            case 101: return "com.apple.WebKit.Networking"
            default: return nil
            }
        }

        // 两行 nettop 名称都被截断成相同的 `com.apple.WebKi`。
        let first = sample(rows: [("com.apple.WebKi", 100, 100, 100), ("com.apple.WebKi", 101, 200, 200)])
        let second = sample(rows: [("com.apple.WebKi", 100, 1024, 1024), ("com.apple.WebKi", 101, 2048, 2048)])

        service.processOutput(first)
        service.flushBuffer()
        service.processOutput(second)
        service.flushBuffer()
        try await Task.sleep(nanoseconds: 100_000_000)

        #expect(service.processes.count == 2)
        #expect(Set(service.processes.map(\.name)) == ["com.apple.WebKit.WebContent", "com.apple.WebKit.Networking"])
    }

    @Test("无法解析完整名称时回退 nettop 原名")
    func fallsBackToNettopNameWhenResolutionFails() async throws {
        // 假 PID 无法通过 proc_pidpath 解析，应保留 nettop 原名。
        let service = makeService()

        service.processOutput(sample(name: "Lumi", pid: 4242, bytesIn: 900_000_000, bytesOut: 100_000_000))
        service.flushBuffer()
        service.processOutput(sample(name: "Lumi", pid: 4242, bytesIn: 1024, bytesOut: 2048))
        service.flushBuffer()
        try await Task.sleep(nanoseconds: 100_000_000)

        #expect(service.processes.first?.name == "Lumi")
    }

    private func sample(name: String, pid: Int, bytesIn: Double, bytesOut: Double) -> Data {
        sample(rows: [(name, pid, bytesIn, bytesOut)])
    }

    private func sample(rows: [(String, Int, Double, Double)]) -> Data {
        var text = header
        for row in rows {
            text += "\(row.0).\(row.1),\(Int64(row.2)),\(Int64(row.3)),\n"
        }
        return Data(text.utf8)
    }
}
