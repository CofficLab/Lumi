#if canImport(XCTest)
import XCTest
@testable import Lumi

final class AutomationControllerTests: XCTestCase {
    @MainActor
    func testExistingRegularFileURLRejectsMissingPath() {
        let missingPath = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .path

        XCTAssertNil(AutomationController.existingRegularFileURL(path: missingPath))
    }

    @MainActor
    func testExistingRegularFileURLRejectsDirectory() throws {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directoryURL) }

        XCTAssertNil(AutomationController.existingRegularFileURL(path: directoryURL.path))
    }

    @MainActor
    func testExistingRegularFileURLReturnsExistingFile() throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try "content".write(to: fileURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: fileURL) }

        XCTAssertEqual(
            AutomationController.existingRegularFileURL(path: fileURL.path),
            fileURL.standardizedFileURL
        )
    }
}
#endif
