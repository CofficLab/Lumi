#if canImport(XCTest)
import XCTest
@testable import EditorService

final class EditorJumpToDefinitionDelegateTests: XCTestCase {
    func testSubstringIfValidReturnsTextForValidRange() {
        let text = "let cafe = 1"
        let range = (text as NSString).range(of: "cafe")

        XCTAssertEqual(
            EditorJumpToDefinitionDelegate.substringIfValid(in: text, range: range),
            "cafe"
        )
    }

    func testSubstringIfValidRejectsStaleRanges() {
        let text = "let value = 1"

        XCTAssertNil(EditorJumpToDefinitionDelegate.substringIfValid(
            in: text,
            range: NSRange(location: -1, length: 3)
        ))
        XCTAssertNil(EditorJumpToDefinitionDelegate.substringIfValid(
            in: text,
            range: NSRange(location: (text as NSString).length + 1, length: 1)
        ))
        XCTAssertNil(EditorJumpToDefinitionDelegate.substringIfValid(
            in: text,
            range: NSRange(location: 4, length: (text as NSString).length)
        ))
    }

    func testLSPFileURLAcceptsUnescapedFileURL() {
        let url = EditorJumpToDefinitionDelegate.fileURL(fromLSPURI: "file:///tmp/project/My File.swift")

        XCTAssertEqual(url?.path, "/tmp/project/My File.swift")
    }

    func testSameFileComparisonNormalizesUnescapedLSPFileURL() {
        let currentURL = URL(fileURLWithPath: "/tmp/project/My File.swift")
        let targetURL = EditorJumpToDefinitionDelegate.fileURL(fromLSPURI: "file:///tmp/project/My File.swift")

        XCTAssertTrue(EditorJumpToDefinitionDelegate.isSameFile(
            currentFileURL: currentURL,
            targetURL: targetURL
        ))
    }

    @MainActor
    func testReferencePreviewLineReadsUTF16File() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("EditorJumpToDefinitionDelegateTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let url = directory.appendingPathComponent("Reference.swift")
        try """
        struct Reference {
            let localized = true
        }
        """.write(to: url, atomically: true, encoding: .utf16)

        let controller = EditorLSPActionController()

        XCTAssertEqual(controller.previewLine(from: url, at: 2), "let localized = true")
    }
}
#endif
