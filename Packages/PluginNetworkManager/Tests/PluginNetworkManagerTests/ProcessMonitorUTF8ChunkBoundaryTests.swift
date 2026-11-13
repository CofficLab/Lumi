import Foundation
import Testing
@testable import PluginNetworkManager

/// 回归 #824：nettop 输出的 `availableData` chunk 边界可能落在多字节 UTF-8
/// 字符中间。旧实现对每个 chunk 单独 `String(data:encoding:.utf8)`，失败即
/// 整段丢弃——完整的进程行（含同一 chunk 里的其他 ASCII 行）随之消失。
///
/// 修复后：未完成的尾部字节保留到下一 chunk 合并解码；只有真正非法的序列
/// 才按解码错误处理（替换字符兜底），正常 Unicode 进程行绝不丢失。
@MainActor
@Suite("ProcessMonitorService UTF-8 chunk 边界")
struct ProcessMonitorUTF8ChunkBoundaryTests {

    private let header = ",bytes_in,bytes_out,\n"

    private func makeService() -> ProcessMonitorService {
        ProcessMonitorService.makeForTesting { nil }
    }

    private func sample(name: String, pid: Int, bytesIn: Int64, bytesOut: Int64) -> Data {
        Data((header + "\(name).\(pid),\(bytesIn),\(bytesOut),\n").utf8)
    }

    @Test("进程名跨 chunk 边界时整行不得丢失")
    func multibyteNameSplitAcrossChunksSurvives() async throws {
        let service = makeService()

        // 首帧建立基线（累计值会被丢弃）。
        service.processOutput(sample(name: "微信", pid: 123, bytesIn: 900_000_000, bytesOut: 100_000_000))
        service.flushBuffer()

        // 第二帧在「微」(E5 BE AE) 的第一个字节后切开，两个 chunk 各自都无法解码。
        let full = header + "微信.123,1024,2048,\n"
        let bytes = Array(full.utf8)
        let splitIndex = bytes.firstIndex(of: 0xE5)! + 1
        service.processOutput(Data(bytes[..<splitIndex]))
        service.processOutput(Data(bytes[splitIndex...]))
        service.flushBuffer()
        try await Task.sleep(nanoseconds: 100_000_000)

        let process = try #require(service.processes.first { $0.id == 123 })
        #expect(process.name == "微信")
        #expect(process.downloadSpeed == 1024)
        #expect(process.uploadSpeed == 2048)
    }

    @Test("解码失败的 chunk 中已完整的 ASCII 行不得被连带丢弃")
    func completeASCIIRowInFailedChunkIsNotLost() async throws {
        let service = makeService()

        service.processOutput(sample(name: "Lumi", pid: 4242, bytesIn: 900_000_000, bytesOut: 100_000_000))
        service.processOutput(sample(name: "中", pid: 77, bytesIn: 900_000_000, bytesOut: 100_000_000))
        service.flushBuffer()

        // chunk1：完整的 Lumi 行 + 「中」(E4 B8 AD) 的首字节 → 整段解码失败。
        var chunk1 = Data("Lumi.4242,1024,2048,\n".utf8)
        chunk1.append(0xE4)
        // chunk2：「中」的剩余字节 + 完整行。
        var chunk2 = Data([0xB8, 0xAD])
        chunk2.append(contentsOf: Data(".77,512,256,\n".utf8))

        service.processOutput(chunk1)
        service.processOutput(chunk2)
        service.flushBuffer()
        try await Task.sleep(nanoseconds: 100_000_000)

        let lumi = try #require(service.processes.first { $0.id == 4242 })
        #expect(lumi.downloadSpeed == 1024)
        #expect(lumi.uploadSpeed == 2048)

        let zhong = try #require(service.processes.first { $0.id == 77 })
        #expect(zhong.name == "中")
        #expect(zhong.downloadSpeed == 512)
        #expect(zhong.uploadSpeed == 256)
    }

    @Test("真正非法的字节不得吞掉同一 chunk 里的有效进程行")
    func invalidBytesDoNotDiscardValidRows() async throws {
        let service = makeService()

        service.processOutput(sample(name: "Lumi", pid: 4242, bytesIn: 900_000_000, bytesOut: 100_000_000))
        service.flushBuffer()

        // 0xFF 不是合法 UTF-8 字节；其后的完整行仍必须进入缓冲。
        var chunk = Data([0xFF])
        chunk.append(contentsOf: Data("Lumi.4242,1024,2048,\n".utf8))
        service.processOutput(chunk)
        service.flushBuffer()
        try await Task.sleep(nanoseconds: 100_000_000)

        let process = try #require(service.processes.first { $0.id == 4242 })
        #expect(process.downloadSpeed == 1024)
        #expect(process.uploadSpeed == 2048)
    }
}