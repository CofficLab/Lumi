import Foundation
import Testing
@testable import PluginNetworkManager

/// 回归 #822：HTTP 日志批量导出的文件名必须按最终 UTF-8 字节预算截断
/// （含序号/方法/host/ID/扩展名），不切断字素簇；单条写入失败不得中止整批。
@Suite("HTTP export filename bytes & batch resilience")
struct HTTPExchangeExportFilenameBytesTests {

    @Test("CJK 长 URL 文件名 ≤ APFS 255 字节且保留 ID 后缀")
    func cjkFilenameWithinByteBudget() throws {
        let name = HTTPExchangeExportFormatter.exportFileName(
            for: snapshot(url: "https://example.com/" + String(repeating: "测", count: 80)),
            index: 0
        )
        #expect(name.utf8.count <= 255, "最终文件名 UTF-8 字节数必须 ≤ APFS 255 上限")
        #expect(name.hasSuffix("-\(Self.fixedID.uuidString).md"), "ID 后缀必须完整保留")
        #expect(name.contains("测"), "应保留部分描述性 CJK 前缀而非整体丢弃")
        #expect(String(data: Data(name.utf8), encoding: .utf8) == name, "不得切断字素簇")
    }

    @Test("ZWJ emoji 长 URL 文件名按字节截断且字素簇完整")
    func emojiGraphemeFilenameWithinByteBudget() throws {
        let family = "👨‍👩‍👧‍👦"
        let name = HTTPExchangeExportFormatter.exportFileName(
            for: snapshot(url: "https://example.com/" + String(repeating: family, count: 40)),
            index: 0
        )
        #expect(name.utf8.count <= 255)
        #expect(name.hasSuffix("-\(Self.fixedID.uuidString).md"))
        #expect(name.contains(family), "多标量字素簇必须整体保留，不能被劈开")
        #expect(String(data: Data(name.utf8), encoding: .utf8) == name)
    }

    @Test("短 multibyte URL 不被字节预算误截")
    func shortMultibyteFilenameUnchanged() throws {
        let name = HTTPExchangeExportFormatter.exportFileName(
            for: snapshot(url: "https://example.com/测测测测测"),
            index: 0
        )
        #expect(name == "00001-GET-example.com-测测测测测-\(Self.fixedID.uuidString).md")
    }

    @Test("单条写入失败不中止整批，其余记录仍导出")
    func batchContinuesPastFailure() async throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let snapshots = (0..<3).map { snapshot(url: "https://example.com/item\($0)", id: UUID()) }
        // 第 0 条目标路径预先建成目录 → 文件写入必然失败。
        let name0 = HTTPExchangeExportFormatter.exportFileName(for: snapshots[0], index: 0)
        try FileManager.default.createDirectory(
            at: dir.appendingPathComponent(name0), withIntermediateDirectories: true
        )

        let recorder = WrittenIndexRecorder()
        let failures = await HTTPExchangeExportFormatter.writeBatch(snapshots, to: dir) { index in
            await recorder.record(index)
        }

        #expect(failures.count == 1)
        #expect(failures.first?.index == 0)
        for i in 1..<3 {
            let url = dir.appendingPathComponent(
                HTTPExchangeExportFormatter.exportFileName(for: snapshots[i], index: i)
            )
            #expect(FileManager.default.fileExists(atPath: url.path), "第 \(i) 条应仍被写出")
            #expect(try String(contentsOf: url, encoding: .utf8).contains("https://example.com/item\(i)"))
        }
        #expect(await recorder.indices == [1, 2], "进度只对成功写入推进")
    }

    @Test("全部成功时写出所有记录并逐条推进进度")
    func batchWritesAllOnSuccess() async throws {
        let dir = try makeTempDir()
        defer { try? FileManager.default.removeItem(at: dir) }

        let snapshots = (0..<3).map { snapshot(url: "https://example.com/ok\($0)", id: UUID()) }
        let recorder = WrittenIndexRecorder()
        let failures = await HTTPExchangeExportFormatter.writeBatch(snapshots, to: dir) { index in
            await recorder.record(index)
        }

        #expect(failures.isEmpty)
        #expect(await recorder.indices == [0, 1, 2])
        for (i, snap) in snapshots.enumerated() {
            let url = dir.appendingPathComponent(
                HTTPExchangeExportFormatter.exportFileName(for: snap, index: i)
            )
            #expect(FileManager.default.fileExists(atPath: url.path))
        }
    }

    // MARK: - Helpers

    private static let fixedID = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!

    private func snapshot(url: String, id: UUID = fixedID) -> HTTPExchangeExportSnapshot {
        HTTPExchangeExportSnapshot(record: HTTPExchangeRecord(
            id: id,
            startedAt: Date(timeIntervalSince1970: 1),
            requestMethod: "GET",
            requestURL: url,
            requestHeadersJSON: Data("{}".utf8),
            requestBody: nil,
            requestDetailsJSON: Data("{}".utf8)
        ))
    }

    private func makeTempDir() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("http-export-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
}

private actor WrittenIndexRecorder {
    private(set) var indices: [Int] = []
    func record(_ index: Int) { indices.append(index) }
}