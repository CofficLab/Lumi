import Foundation
import Testing
@testable import PluginHTMLCanvas

/// 快照渲染的验证。
///
/// ## 为什么要有这组用例
///
/// 卡片默认展示的是**预渲染的 PNG 快照**，而不是活的 WKWebView。
/// 这条路径一旦失效，用户看到的卡片就是空白——而工具本身仍然「成功」，
/// 不会报错。因此必须有一条用例真正跑通渲染，确认产出的是有效 PNG。
///
/// ## 为什么这条用例与其它用例分开
///
/// 快照渲染要启动 WKWebView，耗时在秒级，且依赖 WebKit 进程状态。
/// 把它混进快速用例里会让整个套件变慢，也让失败难以定位：
/// 「是渲染逻辑坏了」还是「WebKit 这次没起来」需要分开看。
@MainActor
@Suite(.serialized)
struct HTMLCanvasSnapshotTests {

    @Test func snapshotRenderProducesValidPNG() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("html-canvas-snapshot-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let payload = try await HTMLCanvasStore.persist(
            html: Self.sampleHTML,
            title: "Snapshot",
            width: 400,
            height: 300,
            directory: directory
        )

        // HTML 一定落盘了。
        #expect(payload.hasHTMLFile)

        // 快照是渲染出来的 PNG：文件存在，且带 PNG 魔数。
        // 魔数比「文件非空」强：空文件或错误页文本都过不了这一关。
        let snapshotURL = URL(fileURLWithPath: payload.snapshotPath)
        let data = try Data(contentsOf: snapshotURL)
        #expect(data.count > 8)
        #expect(Array(data.prefix(4)) == [0x89, 0x50, 0x4E, 0x47])
    }

    @Test func persistRejectsEmptyHTML() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("html-canvas-empty-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        await #expect(throws: HTMLCanvasStore.StoreError.self) {
            try await HTMLCanvasStore.persist(
                html: "   ",
                title: "",
                width: 400,
                height: 300,
                directory: directory
            )
        }
    }

    private static let sampleHTML = """
    <!DOCTYPE html>
    <html>
    <head><meta charset="utf-8"><title>Snapshot</title></head>
    <body style="background:#ffffff;color:#111111;margin:0">
      <h1 style="font-family:sans-serif">Snapshot</h1>
    </body>
    </html>
    """
}
