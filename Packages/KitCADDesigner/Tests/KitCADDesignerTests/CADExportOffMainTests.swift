import AppKit
import Foundation
import Testing
@testable import KitCADDesigner

/// 回归 #1195：CAD 视口导出 PNG 时，TIFF/PNG 转换与原子写入必须在后台线程，
/// 主线程只保留 SCNView 捕获。
@Suite("CAD PNG export off-main")
struct CADExportOffMainTests {

    @Test("encodePNG 在后台线程编码并写出可解码的 PNG")
    func encodeOffMain() async throws {
        let rep = try makeBitmapRep()
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("cad-export-\(UUID().uuidString).png")
        defer { try? FileManager.default.removeItem(at: url) }

        let box = BitmapBox(rep)
        let flag = ThreadFlag()
        try await Task.detached(priority: .userInitiated) {
            try runEncodeOffMain(box.rep, to: url, flag: flag)
        }.value

        #expect(flag.value == false, "PNG 转换/写入不应发生在主线程")
        let data = try Data(contentsOf: url)
        #expect(data.count > 0)
        #expect(NSBitmapImageRep(data: data) != nil, "写出的文件必须是可解码的 PNG")
    }

    @Test("目标目录不存在时 encodePNG 抛出错误而非静默失败")
    func writeFailureThrows() async throws {
        let rep = try makeBitmapRep()
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("missing-\(UUID().uuidString)/out.png")
        let box = BitmapBox(rep)

        await #expect(throws: (any Error).self) {
            try await Task.detached(priority: .userInitiated) {
                try ScreenshotExporter.encodePNG(box.rep, to: url)
            }.value
        }
    }
}

// MARK: - Helpers

/// 同步函数：在后台线程记录是否主线程并执行编码。
/// `Thread.isMainThread` 不能直接在 async 闭包里引用，故包进同步函数。
private func runEncodeOffMain(_ rep: NSBitmapImageRep, to url: URL, flag: ThreadFlag) throws {
    flag.value = Thread.isMainThread
    try ScreenshotExporter.encodePNG(rep, to: url)
}

private func makeBitmapRep() throws -> NSBitmapImageRep {
    guard let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: 8, pixelsHigh: 8, bitsPerSample: 8,
        samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
    ) else {
        throw TestImageError.repCreationFailed
    }
    return rep
}

private enum TestImageError: Error { case repCreationFailed }

/// 捕获后的位图视为不可变快照；包一层越过 Sendable 检查。
private struct BitmapBox: @unchecked Sendable {
    let rep: NSBitmapImageRep
    init(_ rep: NSBitmapImageRep) { self.rep = rep }
}

private final class ThreadFlag: @unchecked Sendable {
    var value = false
}