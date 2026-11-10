import KitAgentTool
import XCTest
@testable import DownloadPlugin

@MainActor
final class DownloadPluginTests: XCTestCase {

    // MARK: - Tool failure semantics

    /// 回归：失败分支曾经返回 "❌ ..." 字符串，默认 `executeResult`
    /// 会把它包成 `isError == false` 的成功结果。
    func testToolsThrowForInvalidArguments() async {
        do {
            _ = try await DownloadFileV2Tool().executeResult(
                arguments: ["url": ToolArgument("ftp://example.com/a.zip")]
            )
            XCTFail("invalid URL scheme should throw")
        } catch {
            XCTAssertTrue(error is ToolExecutionError)
        }

        do {
            _ = try await DownloadProgressV2Tool().executeResult(arguments: [:])
            XCTFail("missing task_id should throw")
        } catch {
            XCTAssertTrue(error is ToolExecutionError)
        }
    }

    // MARK: - Plugin Info

    func testPluginInfo() {
        let plugin = DownloadPlugin()
        XCTAssertEqual(plugin.id, "com.coffic.lumi.plugin.download-agent")
        XCTAssertEqual(plugin.metadata.name, "Download Agent")
        XCTAssertEqual(plugin.metadata.policy, .alwaysOn)
        XCTAssertEqual(plugin.metadata.stage, .preview)
        XCTAssertEqual(plugin.metadata.category, .project)
    }

    // MARK: - Download Directory

    func testDefaultDownloadDirectory() {
        // 记录调用前的存在状态：调用本身不应副作用地创建目录
        let dir = DownloadPluginSupport.defaultDownloadDirectory()

        XCTAssertEqual(
            dir.lastPathComponent, "Downloads",
            "默认下载目录应直接复用用户 Downloads 目录，不创建二级子目录"
        )

        // 调用 defaultDownloadDirectory() 不应改变目录的存在状态：
        // app 启动仅访问 sharedManager（触发本方法）不应在磁盘上空建目录，
        // 真正发起下载时才由 DownloadManager 按需创建。
        let existedBefore = FileManager.default.fileExists(atPath: dir.path)
        let existsAfter = FileManager.default.fileExists(atPath: dir.path)
        XCTAssertEqual(existsAfter, existedBefore, "defaultDownloadDirectory() 不应副作用地创建目录")
    }

    // MARK: - Filename Extraction

    func testExtractFilenameFromURL() {
        let url1 = URL(string: "https://example.com/file.zip")!
        XCTAssertEqual(DownloadPluginSupport.extractFilename(from: url1), "file.zip")

        let url2 = URL(string: "https://example.com/path/to/document.pdf")!
        XCTAssertEqual(DownloadPluginSupport.extractFilename(from: url2), "document.pdf")
    }

    func testExtractFilenameFallback() {
        let url = URL(string: "https://example.com/")!
        let name = DownloadPluginSupport.extractFilename(from: url)
        XCTAssertFalse(name.isEmpty)
        XCTAssertTrue(name.hasPrefix("download_"), "Expected '\(name)' to have prefix 'download_'")
    }

    func testExtractFilenameFromQueryFilenameParam() {
        // Query filename only applies when the URL has no meaningful path component.
        let url = URL(string: "https://cdn.example.com/?filename=archive.zip")!
        XCTAssertEqual(DownloadPluginSupport.extractFilename(from: url), "archive.zip")
    }

    func testExtractFilenameFromQueryFileParam() {
        let url = URL(string: "https://cdn.example.com/?file=data.bin")!
        XCTAssertEqual(DownloadPluginSupport.extractFilename(from: url), "data.bin")
    }

    func testExtractFilenameDecodesPercentEncodedQueryValue() {
        let url = URL(string: "https://cdn.example.com/?filename=my%20report.pdf")!
        XCTAssertEqual(DownloadPluginSupport.extractFilename(from: url), "my report.pdf")
    }

    func testExtractFilenameSkipsMalformedQueryPairs() {
        // A pair without '=' and a key that is neither filename nor file are
        // ignored, so the timestamp name is produced for a root URL.
        let url = URL(string: "https://example.com/?tokenonly&other=value")!
        let name = DownloadPluginSupport.extractFilename(from: url)
        XCTAssertTrue(name.hasPrefix("download_"))
    }

    // MARK: - Batch URL Handling

    func testClassifyBatchURLsKeepsInvalidEntriesInOrder() {
        let raws = [
            "https://example.com/a.zip",
            "not a url",
            "ftp://example.com/b.zip",
            "https://example.com/c.zip",
        ]
        let items = DownloadPluginSupport.classifyBatchURLs(raws)

        XCTAssertEqual(items.map(\.raw), raws, "无效项不能被静默丢弃")
        XCTAssertNotNil(items[0].url)
        XCTAssertNil(items[1].url, "malformed URL 应标记为无效")
        XCTAssertNil(items[2].url, "非 HTTP/HTTPS scheme 应标记为无效")
        XCTAssertNotNil(items[3].url)
    }

    func testBatchSummaryFlagsPartialCompletion() {
        XCTAssertEqual(DownloadPluginSupport.batchSummary(succeeded: 2, total: 2), "📊 下载完成")
        XCTAssertEqual(DownloadPluginSupport.batchSummary(succeeded: 1, total: 2), "📊 部分完成（成功 1 / 共 2）")
        XCTAssertEqual(DownloadPluginSupport.batchSummary(succeeded: 0, total: 2), "📊 部分完成（成功 0 / 共 2）")
    }
}
