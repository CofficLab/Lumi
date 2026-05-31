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

    func testReadImageReturnsDataAndMimeType() throws {
        let path = temporaryDirectory.appendingPathComponent("image.PNG").path
        let data = Data([0x89, 0x50, 0x4E, 0x47])
        FileManager.default.createFile(atPath: path, contents: data)

        let result = try WorkspaceFileReader().read(path: path)

        XCTAssertEqual(result, .image(data: data, mimeType: "image/png", resolvedPath: path))
    }

    func testReadNonUTF8ReturnsSupportedImageExtensions() throws {
        let path = temporaryDirectory.appendingPathComponent("binary.dat").path
        FileManager.default.createFile(atPath: path, contents: Data([0xff, 0xfe, 0xfd]))

        let result = try WorkspaceFileReader().read(path: path)

        if case .nonUTF8(let resolvedPath, let extensions) = result {
            XCTAssertEqual(resolvedPath, path)
            XCTAssertTrue(extensions.contains("png"))
            XCTAssertTrue(extensions.contains("webp"))
        } else {
            XCTFail("Expected nonUTF8 result")
        }
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

    func testEditCreatesNewFileWhenOldStringIsEmpty() throws {
        let path = temporaryDirectory.appendingPathComponent("new/file.txt").path

        let outcome = try WorkspaceFileEditor().edit(filePath: path, oldString: "", newString: "created")

        XCTAssertEqual(outcome, .createdNewFile(path: path))
        XCTAssertEqual(try String(contentsOfFile: path, encoding: .utf8), "created")
    }

    func testEditWritesExistingEmptyFile() throws {
        let path = temporaryDirectory.appendingPathComponent("empty.txt").path
        FileManager.default.createFile(atPath: path, contents: Data())

        let outcome = try WorkspaceFileEditor().edit(filePath: path, oldString: "", newString: "filled")

        XCTAssertEqual(outcome, .wroteEmptyFile(path: path))
        XCTAssertEqual(try String(contentsOfFile: path, encoding: .utf8), "filled")
    }

    func testEditAcceptsFileURLString() throws {
        let url = temporaryDirectory.appendingPathComponent("file-url.txt")
        try "before".write(to: url, atomically: true, encoding: .utf8)

        let outcome = try WorkspaceFileEditor().edit(
            filePath: url.absoluteString,
            oldString: "before",
            newString: "after"
        )

        if case .updated(let path, let matchCount, let replaceAll, _) = outcome {
            XCTAssertEqual(path, url.absoluteString)
            XCTAssertEqual(matchCount, 1)
            XCTAssertFalse(replaceAll)
        } else {
            XCTFail("Expected updated outcome")
        }
        XCTAssertEqual(try String(contentsOf: url, encoding: .utf8), "after")
    }

    func testListDirectorySkipsHiddenFiles() throws {
        try "visible".write(to: temporaryDirectory.appendingPathComponent("visible.txt"), atomically: true, encoding: .utf8)
        try "hidden".write(to: temporaryDirectory.appendingPathComponent(".hidden"), atomically: true, encoding: .utf8)

        let listing = try WorkspaceDirectoryLister().list(path: temporaryDirectory.path)

        XCTAssertTrue(listing.output.contains("visible.txt"))
        XCTAssertFalse(listing.output.contains(".hidden"))
        XCTAssertEqual(listing.itemCount, 1)
    }

    func testRecursiveListCanTruncate() throws {
        try "one".write(to: temporaryDirectory.appendingPathComponent("one.txt"), atomically: true, encoding: .utf8)
        try "two".write(to: temporaryDirectory.appendingPathComponent("two.txt"), atomically: true, encoding: .utf8)
        try "three".write(to: temporaryDirectory.appendingPathComponent("three.txt"), atomically: true, encoding: .utf8)

        let listing = try WorkspaceDirectoryLister(maxRecursiveItems: 1).list(path: temporaryDirectory.path, recursive: true)

        XCTAssertTrue(listing.truncated)
        XCTAssertTrue(listing.output.contains("Too many files"))
    }

    func testRecursiveListOnlyDropsRootPrefix() throws {
        let nestedDirectory = temporaryDirectory
            .appendingPathComponent("nested", isDirectory: true)
            .appendingPathComponent(temporaryDirectory.path, isDirectory: true)
        try FileManager.default.createDirectory(at: nestedDirectory, withIntermediateDirectories: true)
        try "content".write(to: nestedDirectory.appendingPathComponent("file.txt"), atomically: true, encoding: .utf8)

        let listing = try WorkspaceDirectoryLister().list(path: temporaryDirectory.path, recursive: true)

        XCTAssertTrue(listing.output.contains("nested/\(String(temporaryDirectory.path.dropFirst()))/file.txt"))
    }

    func testRelativePathRejectsSiblingWithSharedPrefix() {
        let rootPath = temporaryDirectory.path
        let sibling = URL(fileURLWithPath: rootPath + "-copy/file.txt")

        XCTAssertEqual(WorkspaceDirectoryLister.relativePath(for: sibling, rootPath: rootPath), "file.txt")
    }

    func testPathResolverAcceptsFileURLString() {
        let path = temporaryDirectory.appendingPathComponent("file.txt").path
        let fileURLString = URL(fileURLWithPath: path).absoluteString

        XCTAssertEqual(WorkspacePathResolver.fileURL(from: fileURLString).path, path)
    }

    func testPathResolverTrimsCopiedPathWhitespace() {
        let path = temporaryDirectory.appendingPathComponent("copied.txt").path

        XCTAssertEqual(WorkspacePathResolver.fileURL(from: " \n\(path)\t").path, path)
    }

    func testPathResolverTrimsCopiedFileURLWhitespace() {
        let path = temporaryDirectory.appendingPathComponent("copied-url.txt").path
        let fileURLString = URL(fileURLWithPath: path).absoluteString

        XCTAssertEqual(WorkspacePathResolver.fileURL(from: " \n\(fileURLString)\t").path, path)
    }

    func testPathResolverAcceptsUnescapedFileURLString() {
        let path = temporaryDirectory.appendingPathComponent("copied url.txt").path

        XCTAssertEqual(WorkspacePathResolver.fileURL(from: "file://\(path)").path, path)
        XCTAssertEqual(WorkspacePathResolver.fileURL(from: "file://localhost\(path)").path, path)
    }
}
