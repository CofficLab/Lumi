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
        let dir = DownloadPlugin.defaultDownloadDirectory()
        XCTAssertTrue(dir.lastPathComponent == "LumiDownloads")
        XCTAssertTrue(FileManager.default.fileExists(atPath: dir.path))
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
