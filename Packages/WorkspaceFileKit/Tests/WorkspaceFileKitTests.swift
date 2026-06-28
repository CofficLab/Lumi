import XCTest
import Darwin
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

    func testWriteDirectoryReportsDirectoryInsteadOfSystemError() {
        XCTAssertThrowsError(try WorkspaceFileWriter().write(
            path: temporaryDirectory.path,
            content: "hello"
        )) { error in
            XCTAssertTrue(error.localizedDescription.contains("Path is a directory"))
            XCTAssertTrue(error.localizedDescription.contains(temporaryDirectory.path))
        }
    }

    func testWriteWhenParentIsFileReportsParentPathClearly() throws {
        let parentFile = temporaryDirectory.appendingPathComponent("parent.txt")
        try "not a directory".write(to: parentFile, atomically: true, encoding: .utf8)
        let childPath = parentFile.appendingPathComponent("child.txt").path

        XCTAssertThrowsError(try WorkspaceFileWriter().write(
            path: childPath,
            content: "hello"
        )) { error in
            XCTAssertTrue(error.localizedDescription.contains("Parent path is not a directory"))
            XCTAssertTrue(error.localizedDescription.contains(parentFile.path))
        }
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

    func testReadMissingTextFileReportsMissingFile() {
        let path = temporaryDirectory.appendingPathComponent("missing.txt").path

        XCTAssertThrowsError(try WorkspaceFileReader().read(path: path)) { error in
            XCTAssertTrue(error.localizedDescription.contains("File does not exist"))
            XCTAssertTrue(error.localizedDescription.contains(path))
        }
    }

    func testReadDirectoryReportsDirectoryInsteadOfNonUTF8() {
        XCTAssertThrowsError(try WorkspaceFileReader().read(path: temporaryDirectory.path)) { error in
            XCTAssertTrue(error.localizedDescription.contains("Path is a directory"))
            XCTAssertTrue(error.localizedDescription.contains(temporaryDirectory.path))
        }
    }

    func testReadDetectsUTF16TextFiles() throws {
        let url = temporaryDirectory.appendingPathComponent("utf16.txt")
        try "hello 中文".write(to: url, atomically: true, encoding: .utf16)

        let result = try WorkspaceFileReader().read(path: url.path)

        XCTAssertEqual(result, .text(content: "hello 中文", resolvedPath: url.path, truncated: false))
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

    func testEditCreateWhenParentIsFileReportsParentPathClearly() throws {
        let parentFile = temporaryDirectory.appendingPathComponent("parent.txt")
        try "not a directory".write(to: parentFile, atomically: true, encoding: .utf8)
        let childPath = parentFile.appendingPathComponent("child.txt").path

        XCTAssertThrowsError(try WorkspaceFileEditor().edit(
            filePath: childPath,
            oldString: "",
            newString: "created"
        )) { error in
            XCTAssertTrue(error.localizedDescription.contains("Parent path is not a directory"))
            XCTAssertTrue(error.localizedDescription.contains(parentFile.path))
        }
    }

    func testEditWritesExistingEmptyFile() throws {
        let path = temporaryDirectory.appendingPathComponent("empty.txt").path
        FileManager.default.createFile(atPath: path, contents: Data())

        let outcome = try WorkspaceFileEditor().edit(filePath: path, oldString: "", newString: "filled")

        XCTAssertEqual(outcome, .wroteEmptyFile(path: path))
        XCTAssertEqual(try String(contentsOfFile: path, encoding: .utf8), "filled")
    }

    func testEditDirectoryReportsDirectoryInsteadOfInvalidText() {
        XCTAssertThrowsError(try WorkspaceFileEditor().edit(
            filePath: temporaryDirectory.path,
            oldString: "before",
            newString: "after"
        )) { error in
            XCTAssertTrue(error.localizedDescription.contains("Path is a directory"))
            XCTAssertTrue(error.localizedDescription.contains(temporaryDirectory.path))
        }
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

    func testEditPreservesDetectedTextEncoding() throws {
        let url = temporaryDirectory.appendingPathComponent("utf16-edit.txt")
        try "hello 中文".write(to: url, atomically: true, encoding: .utf16)

        _ = try WorkspaceFileEditor().edit(
            filePath: url.path,
            oldString: "中文",
            newString: "Lumi"
        )

        var detectedEncoding = String.Encoding.utf8
        let content = try String(contentsOf: url, usedEncoding: &detectedEncoding)
        XCTAssertEqual(content, "hello Lumi")
        XCTAssertEqual(detectedEncoding, .utf16)
    }

    func testEditMatchesLFInputAgainstCRLFFileAndPreservesLineEndings() throws {
        let path = temporaryDirectory.appendingPathComponent("crlf.txt").path
        try "alpha\r\nbeta\r\ngamma\r\n".write(toFile: path, atomically: true, encoding: .utf8)

        let outcome = try WorkspaceFileEditor().edit(
            filePath: path,
            oldString: "beta\ngamma",
            newString: "delta\nepsilon"
        )

        XCTAssertEqual(try String(contentsOfFile: path, encoding: .utf8), "alpha\r\ndelta\r\nepsilon\r\n")
        if case .updated(_, let matchCount, let replaceAll, let diff) = outcome {
            XCTAssertEqual(matchCount, 1)
            XCTAssertFalse(replaceAll)
            XCTAssertTrue(diff.contains("delta"))
            XCTAssertFalse(diff.contains("\r"))
        } else {
            XCTFail("Expected updated outcome")
        }
    }

    // MARK: - 1GB 大小保护

    func testEditRejectsOversizedFile() throws {
        let path = temporaryDirectory.appendingPathComponent("huge.txt").path
        // 用 ftruncate 创建一个「逻辑大小」超过上限的稀疏文件——不实际占用磁盘空间，
        // 但 FileManager 报告的 size 会超过 maxFileSizeBytes，从而触发编辑前的 size 守卫。
        let fd = open(path, O_CREAT | O_RDWR, 0o644)
        XCTAssertGreaterThan(fd, 0)
        defer { close(fd) }
        let targetSize = off_t(WorkspaceFileEditor.maxFileSizeBytes + 1)
        XCTAssertEqual(ftruncate(fd, targetSize), 0)

        XCTAssertThrowsError(try WorkspaceFileEditor().edit(filePath: path, oldString: "", newString: "x")) { error in
            XCTAssertTrue(error.localizedDescription.contains("too large"), "got: \(error.localizedDescription)")
        }
    }

    // MARK: - 乐观并发控制（读取后被外部修改则拒绝）

    func testEditRejectedWhenFileModifiedAfterRead() throws {
        let path = temporaryDirectory.appendingPathComponent("concurrent.txt").path
        try "before".write(toFile: path, atomically: true, encoding: .utf8)

        let conversationID = UUID()
        let state = WorkspaceReadFileState()

        // 模拟「已读取」：记录读取时刻的修改时间
        let readMtime = (try FileManager.default.attributesOfItem(atPath: path))[.modificationDate] as! Date
        state.recordRead(conversationID: conversationID, path: path, snapshot: WorkspaceReadFileSnapshot(modificationDate: readMtime))

        // 模拟外部修改：改写内容并把修改时间推后
        try "before-externally-changed".write(toFile: path, atomically: true, encoding: .utf8)
        let future = Date(timeIntervalSinceNow: 5)
        try FileManager.default.setAttributes([.modificationDate: future], ofItemAtPath: path)

        XCTAssertThrowsError(
            try WorkspaceFileEditor().edit(
                filePath: path,
                oldString: "before-externally-changed",
                newString: "after",
                conversationID: conversationID,
                readState: state
            )
        ) { error in
            XCTAssertTrue(error.localizedDescription.contains("modified externally"), "got: \(error.localizedDescription)")
        }
    }

    func testEditAllowedWhenFileUnchangedAfterRead() throws {
        let path = temporaryDirectory.appendingPathComponent("stable.txt").path
        try "hello".write(toFile: path, atomically: true, encoding: .utf8)

        let conversationID = UUID()
        let state = WorkspaceReadFileState()
        let readMtime = (try FileManager.default.attributesOfItem(atPath: path))[.modificationDate] as! Date
        state.recordRead(conversationID: conversationID, path: path, snapshot: WorkspaceReadFileSnapshot(modificationDate: readMtime))

        // 未被外部改动 → 编辑应成功
        let outcome = try WorkspaceFileEditor().edit(
            filePath: path,
            oldString: "hello",
            newString: "world",
            conversationID: conversationID,
            readState: state
        )
        XCTAssertEqual(try String(contentsOfFile: path, encoding: .utf8), "world")
        if case .updated = outcome { /* ok */ } else { XCTFail("Expected updated outcome") }
    }

    // MARK: - 引号风格保留

    func testEditPreservesCurlyQuoteStyleInReplacement() throws {
        let path = temporaryDirectory.appendingPathComponent("quotes.txt").path
        // 文件使用弯引号
        try "\u{201C}hello world\u{201D}".write(toFile: path, atomically: true, encoding: .utf8)

        let outcome = try WorkspaceFileEditor().edit(
            filePath: path,
            oldString: "\"hello world\"",
            newString: "\"goodbye world\""
        )
        // 写回的内容应保持弯引号风格
        XCTAssertEqual(try String(contentsOfFile: path, encoding: .utf8), "\u{201C}goodbye world\u{201D}")
        if case .updated = outcome { /* ok */ } else { XCTFail("Expected updated outcome") }
    }

    func testEditDoesNotAlterStraightQuoteFiles() throws {
        let path = temporaryDirectory.appendingPathComponent("straight.txt").path
        try "\"hello world\"".write(toFile: path, atomically: true, encoding: .utf8)

        _ = try WorkspaceFileEditor().edit(
            filePath: path,
            oldString: "\"hello world\"",
            newString: "\"goodbye world\""
        )
        // 直引号文件保持直引号，不被转换
        XCTAssertEqual(try String(contentsOfFile: path, encoding: .utf8), "\"goodbye world\"")
    }

    // MARK: - diff 质量

    func testEditDiffShowsRemovedAndAddedLines() throws {
        let path = temporaryDirectory.appendingPathComponent("diff.txt").path
        try "alpha\nbeta\ngamma\n".write(toFile: path, atomically: true, encoding: .utf8)

        let outcome = try WorkspaceFileEditor().edit(
            filePath: path,
            oldString: "beta",
            newString: "BETA"
        )
        guard case .updated(_, _, _, let diff) = outcome else {
            XCTFail("Expected updated outcome")
            return
        }
        // 旧行应标记为 -，新行应标记为 +
        XCTAssertTrue(diff.contains("- beta"), "diff should contain removed line: \(diff)")
        XCTAssertTrue(diff.contains("+ BETA"), "diff should contain added line: \(diff)")
        // 上下文行（未变的 alpha/gamma）不应带 - 或 +
        XCTAssertTrue(diff.contains("alpha"), "diff should contain context line alpha")
    }

    // MARK: - 「Did you mean?」相似文件名提示

    func testEditMissingFileSuggestsSimilarFilename() throws {
        // 目录里有一个相近文件 FooTests.swift，编辑不存在的 Foo.swift 时应给出建议
        try "tests".write(toFile: temporaryDirectory.appendingPathComponent("FooTests.swift").path, atomically: true, encoding: .utf8)
        let missingPath = temporaryDirectory.appendingPathComponent("Foo.swift").path

        XCTAssertThrowsError(try WorkspaceFileEditor().edit(filePath: missingPath, oldString: "x", newString: "y")) { error in
            let msg = error.localizedDescription
            XCTAssertTrue(msg.contains("Did you mean"), "should suggest: \(msg)")
            XCTAssertTrue(msg.contains("FooTests.swift"), "should name the similar file: \(msg)")
        }
    }

    func testEditMissingFileNoSuggestionWhenNoSimilarFile() throws {
        // 目录里只有完全无关的文件，不应给出无意义建议
        try "x".write(toFile: temporaryDirectory.appendingPathComponent("README.md").path, atomically: true, encoding: .utf8)
        let missingPath = temporaryDirectory.appendingPathComponent("TotallyDifferent.swift").path

        XCTAssertThrowsError(try WorkspaceFileEditor().edit(filePath: missingPath, oldString: "x", newString: "y")) { error in
            let msg = error.localizedDescription
            XCTAssertFalse(msg.contains("Did you mean"), "should not suggest unrelated file: \(msg)")
        }
    }

    func testEditDistanceBasic() {
        XCTAssertEqual(WorkspaceFileEditor.editDistance("", ""), 0)
        XCTAssertEqual(WorkspaceFileEditor.editDistance("abc", "abc"), 0)
        XCTAssertEqual(WorkspaceFileEditor.editDistance("Foo.swift", "FooTests.swift"), 5) // 插入 "Tests"
    }

    func testListDirectorySkipsHiddenFiles() throws {
        try "visible".write(to: temporaryDirectory.appendingPathComponent("visible.txt"), atomically: true, encoding: .utf8)
        try "hidden".write(to: temporaryDirectory.appendingPathComponent(".hidden"), atomically: true, encoding: .utf8)

        let listing = try WorkspaceDirectoryLister().list(path: temporaryDirectory.path)

        XCTAssertTrue(listing.output.contains("visible.txt"))
        XCTAssertFalse(listing.output.contains(".hidden"))
        XCTAssertEqual(listing.itemCount, 1)
    }

    func testListMissingDirectoryReportsPath() {
        let path = temporaryDirectory.appendingPathComponent("missing").path

        XCTAssertThrowsError(try WorkspaceDirectoryLister().list(path: path)) { error in
            XCTAssertTrue(error.localizedDescription.contains("Path does not exist"))
            XCTAssertTrue(error.localizedDescription.contains(path))
        }
    }

    func testListFilePathReportsNotDirectory() throws {
        let path = temporaryDirectory.appendingPathComponent("file.txt").path
        try "content".write(toFile: path, atomically: true, encoding: .utf8)

        XCTAssertThrowsError(try WorkspaceDirectoryLister().list(path: path)) { error in
            XCTAssertTrue(error.localizedDescription.contains("Path is not a directory"))
            XCTAssertTrue(error.localizedDescription.contains(path))
        }
    }

    func testRecursiveListFilePathReportsNotDirectory() throws {
        let path = temporaryDirectory.appendingPathComponent("file.txt").path
        try "content".write(toFile: path, atomically: true, encoding: .utf8)

        XCTAssertThrowsError(try WorkspaceDirectoryLister().list(path: path, recursive: true)) { error in
            XCTAssertTrue(error.localizedDescription.contains("Path is not a directory"))
            XCTAssertTrue(error.localizedDescription.contains(path))
        }
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
