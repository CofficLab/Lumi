import KitAgentTool
import XCTest
@testable import DownloadPlugin

/// 回归 #158：批量下载把不同来源的同名文件映射到同一路径，
/// 后一个任务把前一个任务的成品当续传起点或直接覆盖，拼出混合来源的
/// 损坏文件且双双报成功。同名条目必须分配互不冲突的目标名。
@MainActor
final class BatchDestinationCollisionTests: XCTestCase {

    private let directory = URL(fileURLWithPath: "/tmp/lumi-batch-158", isDirectory: true)

    private func plan(_ raws: [String]) -> [DownloadPluginSupport.BatchDestination] {
        let items = DownloadPluginSupport.classifyBatchURLs(raws)
        return DownloadPluginSupport.planBatchDestinations(for: items, directory: directory)
    }

    private func readyPath(_ plan: DownloadPluginSupport.BatchDestination) -> String? {
        guard case .ready(let url) = plan else { return nil }
        return url.path
    }

    // MARK: - 目标去重

    func testSameNameFromDifferentSourcesGetsDistinctPaths() {
        let plans = plan([
            "https://a.example/file.bin",
            "https://b.example/file.bin",
        ])
        XCTAssertEqual(readyPath(plans[0]), directory.appendingPathComponent("file.bin").path)
        XCTAssertEqual(readyPath(plans[1]), directory.appendingPathComponent("file-2.bin").path)
        XCTAssertNotEqual(readyPath(plans[0]), readyPath(plans[1]), "不同来源的同名文件不得落到同一路径")
    }

    func testThreeSameNamesGetSequentialSuffixes() {
        let plans = plan([
            "https://a.example/file.bin",
            "https://b.example/file.bin",
            "https://c.example/file.bin",
        ])
        let names = plans.compactMap { plan -> String? in
            guard case .ready(let url) = plan else { return nil }
            return url.lastPathComponent
        }
        XCTAssertEqual(names, ["file.bin", "file-2.bin", "file-3.bin"])
        XCTAssertEqual(Set(names).count, 3, "三个同名条目必须得到三个互不相同的目标名")
    }

    func testExplicitSuffixCollisionIsAvoided() {
        // 批次里已有显式的 file-2.bin 时，去重后缀必须避开它
        let plans = plan([
            "https://a.example/file.bin",
            "https://a.example/file-2.bin",
            "https://b.example/file.bin",
        ])
        let names = plans.compactMap { plan -> String? in
            guard case .ready(let url) = plan else { return nil }
            return url.lastPathComponent
        }
        XCTAssertEqual(names, ["file.bin", "file-2.bin", "file-3.bin"])
    }

    func testInvalidItemsAndDistinctNamesArePreserved() {
        let plans = plan([
            "https://a.example/a.zip",
            "not a url",
            "https://b.example/b.tar.gz",
            "ftp://c.example/c.zip",
            "https://d.example/a.zip",
        ])
        XCTAssertEqual(readyPath(plans[0]), directory.appendingPathComponent("a.zip").path)
        XCTAssertEqual(plans[1], .invalidURL, "无效项必须保留在结果里，不能静默丢弃")
        XCTAssertEqual(readyPath(plans[2]), directory.appendingPathComponent("b.tar.gz").path)
        XCTAssertEqual(plans[3], .invalidURL)
        XCTAssertEqual(readyPath(plans[4]), directory.appendingPathComponent("a-2.zip").path)
    }

    func testUniquedFilenamesHandlesExtensionlessAndMultiDotNames() {
        let names = DownloadPluginSupport.uniquedBatchFilenames([
            "README", "README", "archive.tar.gz", "archive.tar.gz", nil,
        ])
        // 后缀插在最后一个扩展名之前，保留最终扩展名
        XCTAssertEqual(names, ["README", "README-2", "archive.tar.gz", "archive.tar-2.gz", nil])
    }

    // MARK: - 文件名安全（与 download_file 的 #470 守卫一致）

    func testTraversalNameFromQueryIsRejectedInBatch() {
        let plans = plan(["https://cdn.example/?filename=../victim"])
        guard case .invalidFilename(let name) = plans[0] else {
            return XCTFail("来自查询参数的穿越文件名必须被拒绝，实际: \(plans[0])")
        }
        XCTAssertEqual(name, "../victim")
    }

    // MARK: - 工具接线

    func testBatchToolAssignsDistinctNamesToSameNamedURLs() async throws {
        // 127.0.0.1:1 无监听，连接立即被拒绝：不发真实外网请求，
        // 用失败行里的文件名验证工具确实走了去重后的目标名。
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let result = try await DownloadBatchV2Tool().executeResult(arguments: [
            "urls": ToolArgument([
                "https://127.0.0.1:1/a/file.bin",
                "https://127.0.0.1:1/b/file.bin",
            ]),
            "directory": ToolArgument(root.path),
        ])
        XCTAssertTrue(result.content.contains("file.bin"), "结果应包含第一个条目的文件名: \(result.content)")
        XCTAssertTrue(result.content.contains("file-2.bin"), "同名条目必须分配到去重后的文件名: \(result.content)")
        let contents = (try? FileManager.default.contentsOfDirectory(atPath: root.path)) ?? []
        XCTAssertTrue(contents.isEmpty, "下载失败时不得留下任何文件")
    }
}