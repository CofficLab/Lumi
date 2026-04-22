#if canImport(XCTest)
import XCTest
@testable import Lumi

final class WorkspaceEditFileOperationsTests: XCTestCase {
    private var tempRootURL: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        tempRootURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("lumi-workspace-edit-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempRootURL, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let tempRootURL {
            try? FileManager.default.removeItem(at: tempRootURL)
        }
        tempRootURL = nil
        try super.tearDownWithError()
    }

    func testCreateFileCreatesParentDirectories() throws {
        let target = tempRootURL
            .appendingPathComponent("nested/path/new.txt")

        let ok = WorkspaceEditFileOperations.applyCreateFile(
            uri: target.absoluteString,
            overwrite: false,
            ignoreIfExists: false
        )

        XCTAssertTrue(ok)
        XCTAssertTrue(FileManager.default.fileExists(atPath: target.path))
    }

    func testCreateFileOverwriteReplacesExistingFile() throws {
        let target = tempRootURL.appendingPathComponent("overwrite.txt")
        try "old".write(to: target, atomically: true, encoding: .utf8)

        let ok = WorkspaceEditFileOperations.applyCreateFile(
            uri: target.absoluteString,
            overwrite: true,
            ignoreIfExists: false
        )

        XCTAssertTrue(ok)
        let content = try String(contentsOf: target, encoding: .utf8)
        XCTAssertEqual(content, "")
    }

    func testCreateFileFailsWhenExistsAndNoFlags() throws {
        let target = tempRootURL.appendingPathComponent("exists.txt")
        try "keep".write(to: target, atomically: true, encoding: .utf8)

        let ok = WorkspaceEditFileOperations.applyCreateFile(
            uri: target.absoluteString,
            overwrite: false,
            ignoreIfExists: false
        )

        XCTAssertFalse(ok)
        let content = try String(contentsOf: target, encoding: .utf8)
        XCTAssertEqual(content, "keep")
    }

    func testRenameFileMovesFile() throws {
        let oldURL = tempRootURL.appendingPathComponent("old.swift")
        let newURL = tempRootURL.appendingPathComponent("sub/new.swift")
        try "print(1)".write(to: oldURL, atomically: true, encoding: .utf8)

        let ok = WorkspaceEditFileOperations.applyRenameFile(
            oldURI: oldURL.absoluteString,
            newURI: newURL.absoluteString,
            overwrite: false,
            ignoreIfExists: false
        )

        XCTAssertTrue(ok)
        XCTAssertFalse(FileManager.default.fileExists(atPath: oldURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: newURL.path))
    }

    func testRenameFileRespectsOverwriteFlag() throws {
        let oldURL = tempRootURL.appendingPathComponent("old.swift")
        let newURL = tempRootURL.appendingPathComponent("target.swift")
        try "old".write(to: oldURL, atomically: true, encoding: .utf8)
        try "new".write(to: newURL, atomically: true, encoding: .utf8)

        let fail = WorkspaceEditFileOperations.applyRenameFile(
            oldURI: oldURL.absoluteString,
            newURI: newURL.absoluteString,
            overwrite: false,
            ignoreIfExists: false
        )
        XCTAssertFalse(fail)

        let ok = WorkspaceEditFileOperations.applyRenameFile(
            oldURI: oldURL.absoluteString,
            newURI: newURL.absoluteString,
            overwrite: true,
            ignoreIfExists: false
        )
        XCTAssertTrue(ok)

        let content = try String(contentsOf: newURL, encoding: .utf8)
        XCTAssertEqual(content, "old")
    }

    func testDeleteFileRespectsRecursiveFlagForDirectories() throws {
        let dir = tempRootURL.appendingPathComponent("folder", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let child = dir.appendingPathComponent("a.txt")
        try "a".write(to: child, atomically: true, encoding: .utf8)

        let fail = WorkspaceEditFileOperations.applyDeleteFile(
            uri: dir.absoluteString,
            recursive: false,
            ignoreIfNotExists: false
        )
        XCTAssertFalse(fail)
        XCTAssertTrue(FileManager.default.fileExists(atPath: dir.path))

        let ok = WorkspaceEditFileOperations.applyDeleteFile(
            uri: dir.absoluteString,
            recursive: true,
            ignoreIfNotExists: false
        )
        XCTAssertTrue(ok)
        XCTAssertFalse(FileManager.default.fileExists(atPath: dir.path))
    }

    func testDeleteFileRespectsIgnoreIfNotExists() {
        let missing = tempRootURL.appendingPathComponent("missing.txt")

        let fail = WorkspaceEditFileOperations.applyDeleteFile(
            uri: missing.absoluteString,
            recursive: false,
            ignoreIfNotExists: false
        )
        XCTAssertFalse(fail)

        let ok = WorkspaceEditFileOperations.applyDeleteFile(
            uri: missing.absoluteString,
            recursive: false,
            ignoreIfNotExists: true
        )
        XCTAssertTrue(ok)
    }
}
#endif
