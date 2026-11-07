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

    @Test("首个有效 delta 发布后才标记快照就绪")
    func snapshotFlagTurnsReadyAfterFirstDelta() async throws {
        let service = makeService()

        service.processOutput(sample(name: "Lumi", pid: 4242, bytesIn: 900_000_000, bytesOut: 100_000_000))
        service.flushBuffer()
        try await Task.sleep(nanoseconds: 100_000_000)
        #expect(!service.hasPublishedSample)

        service.processOutput(sample(name: "Lumi", pid: 4242, bytesIn: 1024, bytesOut: 2048))
        service.flushBuffer()
        try await Task.sleep(nanoseconds: 100_000_000)
        #expect(service.hasPublishedSample)
    }

    @Test("同名进程聚合为一条并标注份数，本应用组单独标记")
    func sameNameProcessesAggregateWithCountAndSelfFlag() async throws {
        let selfPID = Int(getpid())
        let service = ProcessMonitorService.makeForTesting(nettopLauncher: { nil }) { pid in
            switch pid {
            case 100, 101: return "Same Name Helper"
            case selfPID: return "Lumi"
            default: return nil
            }
        }

        service.processOutput(sample(rows: [
            ("Trunc.Helper", 100, 100, 100),
            ("Trunc.Helper", 101, 100, 100),
            ("Lumi", selfPID, 50, 50),
        ]))
        service.flushBuffer()
        service.processOutput(sample(rows: [
            ("Trunc.Helper", 100, 1024, 0),
            ("Trunc.Helper", 101, 1024, 0),
            ("Lumi", selfPID, 512, 0),
        ]))
        service.flushBuffer()
        try await Task.sleep(nanoseconds: 100_000_000)

        #expect(service.processes.count == 2)

        let helper = try #require(service.processes.first { $0.name == "Same Name Helper" })
        #expect(helper.instanceCount == 2)
        #expect(helper.downloadSpeed == 2048)
        #expect(!helper.isCurrentApp)

        let lumi = try #require(service.processes.first { $0.name == "Lumi" })
        #expect(lumi.isCurrentApp)
        #expect(lumi.instanceCount == 1)
    }

    @Test("单次 flush 合并多帧时按采样跨度归一化速率")
    func coalescedFramesNormalizeBySampleSpan() async throws {
        let service = makeService()

        // 首帧只用于建立该 PID 的基线，会被丢弃。
        service.processOutput(sample(rows: [("Lumi", 4242, 900_000_000, 0)]))
        service.flushBuffer()

        // 一次输出里包含两帧，每帧各 1024 字节：合计 2048 字节覆盖 2 秒。
        var text = header + "Lumi.4242,1024,0,\n"
        text += header + "Lumi.4242,1024,0,\n"
        service.processOutput(Data(text.utf8))
        service.flushBuffer()
        try await Task.sleep(nanoseconds: 100_000_000)

        #expect(service.processes.first?.downloadSpeed == 1024)
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
