import XCTest
@testable import WorkspaceFileKit

final class WorkspaceFileKitTests: XCTestCase {
    private var temporaryDirectory: URL!

    override func setUpWithError() throws {
        temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("WorkspaceFileKitTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        if let temporaryDirectory {
            try? FileManager.default.removeItem(at: temporaryDirectory)
        }
        temporaryDirectory = nil
    }

    func testWriteAndReadTextFile() throws {
        let path = temporaryDirectory.appendingPathComponent("nested/file.txt").path

        try WorkspaceFileWriter().write(path: path, content: "hello")
        let result = try WorkspaceFileReader().read(path: path)

        XCTAssertEqual(result, .text(content: "hello", resolvedPath: path, truncated: false))
    }

    func testReadTruncatesLongText() throws {
        let path = temporaryDirectory.appendingPathComponent("long.txt").path
        try "abcdef".write(toFile: path, atomically: true, encoding: .utf8)

        let result = try WorkspaceFileReader(textCharacterLimit: 3).read(path: path)

        XCTAssertEqual(result, .text(content: "abc", resolvedPath: path, truncated: true))
    }

    func testEditRequiresUniqueMatchUnlessReplaceAll() throws {
        let path = temporaryDirectory.appendingPathComponent("file.txt").path
        try "one two one".write(toFile: path, atomically: true, encoding: .utf8)

        XCTAssertThrowsError(try WorkspaceFileEditor().edit(filePath: path, oldString: "one", newString: "1")) { error in
            XCTAssertTrue(error.localizedDescription.contains("Found 2 matches"))
        }

        let outcome = try WorkspaceFileEditor().edit(filePath: path, oldString: "one", newString: "1", replaceAll: true)
        XCTAssertEqual(try String(contentsOfFile: path, encoding: .utf8), "1 two 1")
        if case .updated(_, let matchCount, let replaceAll, _) = outcome {
            XCTAssertEqual(matchCount, 2)
            XCTAssertTrue(replaceAll)
        } else {
            XCTFail("Expected updated outcome")
        }
    }

    func testListDirectorySkipsHiddenFiles() throws {
        try "visible".write(to: temporaryDirectory.appendingPathComponent("visible.txt"), atomically: true, encoding: .utf8)
        try "hidden".write(to: temporaryDirectory.appendingPathComponent(".hidden"), atomically: true, encoding: .utf8)

        let listing = try WorkspaceDirectoryLister().list(path: temporaryDirectory.path)

        XCTAssertTrue(listing.output.contains("visible.txt"))
        XCTAssertFalse(listing.output.contains(".hidden"))
        XCTAssertEqual(listing.itemCount, 1)
    }
}
