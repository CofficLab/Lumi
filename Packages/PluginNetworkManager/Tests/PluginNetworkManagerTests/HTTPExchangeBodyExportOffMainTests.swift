import Foundation
import Testing
@testable import PluginNetworkManager

/// 回归 #1200：大体积 HTTP body 导出时，格式化（JSON 美化 / 逐字节 hex）
/// 与原子写入必须在后台线程完成，主线程只保留保存面板与错误提示。
@Suite("HTTP body export off-main")
struct HTTPExchangeBodyExportOffMainTests {

    @Test("JSON body 在后台线程格式化并写出（pretty + sortedKeys）")
    func jsonExportOffMain() async throws {
        let data = Data(#"{"b":2,"a":1}"#.utf8)
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url) }

        let flag = ThreadFlag()
        try await Task.detached(priority: .userInitiated) {
            try exportBodyOffMain(data, to: url, flag: flag)
        }.value

        #expect(flag.value == false, "格式化/写入不应发生在主线程")
        let written = try String(contentsOf: url, encoding: .utf8)
        let aRange = try #require(written.range(of: "\"a\""))
        let bRange = try #require(written.range(of: "\"b\""))
        #expect(aRange.lowerBound < bRange.lowerBound, "sortedKeys 应让 a 排在 b 之前")
    }

    @Test("非 UTF-8 二进制 body 在后台线程回退为 hex")
    func binaryExportOffMain() async throws {
        let data = Data([0x00, 0xFF, 0x10])
        let url = tempURL()
        defer { try? FileManager.default.removeItem(at: url) }

        let flag = ThreadFlag()
        try await Task.detached(priority: .userInitiated) {
            try exportBodyOffMain(data, to: url, flag: flag)
        }.value

        #expect(flag.value == false)
        #expect(try String(contentsOf: url, encoding: .utf8) == "00 ff 10")
    }

    @Test("目标目录不存在时导出抛出错误而非静默失败")
    func writeFailureThrows() async throws {
        let data = Data("hello".utf8)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("missing-\(UUID().uuidString)/body.txt")

        await #expect(throws: (any Error).self) {
            try await Task.detached(priority: .userInitiated) {
                try HTTPExchangeExportFormatter.text(data)
                    .write(to: url, atomically: true, encoding: .utf8)
            }.value
        }
    }
}

// MARK: - Helpers

/// 同步函数：在后台线程记录是否主线程并执行格式化 + 写入。
/// `Thread.isMainThread` 不能直接在 async 闭包里引用，故包进同步函数。
private func exportBodyOffMain(_ data: Data, to url: URL, flag: ThreadFlag) throws {
    flag.value = Thread.isMainThread
    try HTTPExchangeExportFormatter.text(data)
        .write(to: url, atomically: true, encoding: .utf8)
}

private func tempURL() -> URL {
    FileManager.default.temporaryDirectory
        .appendingPathComponent("body-export-\(UUID().uuidString).txt")
}

private final class ThreadFlag: @unchecked Sendable {
    var value = false
}