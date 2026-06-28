import XCTest
@testable import DownloadPlugin

final class DownloadPluginTests: XCTestCase {

    // MARK: - Plugin Info

    func testPluginInfo() {
        XCTAssertEqual(DownloadPlugin.info.id, "com.coffic.lumi.plugin.download-agent")
        XCTAssertEqual(DownloadPlugin.info.displayName, "Download Agent")
        XCTAssertEqual(DownloadPlugin.policy, .alwaysOn)
        XCTAssertEqual(DownloadPlugin.stage, .beta)
        XCTAssertEqual(DownloadPlugin.category, .agent)
        XCTAssertEqual(DownloadPlugin.iconName, "arrow.down.circle")
    }

    // MARK: - Download Directory

    func testDefaultDownloadDirectory() {
        // 记录调用前的存在状态：调用本身不应副作用地创建目录
        let dir = DownloadPlugin.defaultDownloadDirectory()

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
        XCTAssertEqual(DownloadPlugin.extractFilename(from: url1), "file.zip")

        let url2 = URL(string: "https://example.com/path/to/document.pdf")!
        XCTAssertEqual(DownloadPlugin.extractFilename(from: url2), "document.pdf")
    }

    func testExtractFilenameFallback() {
        let url = URL(string: "https://example.com/")!
        let name = DownloadPlugin.extractFilename(from: url)
        XCTAssertFalse(name.isEmpty)
        XCTAssertTrue(name.hasPrefix("download_"), "Expected '\(name)' to have prefix 'download_'")
    }
}
