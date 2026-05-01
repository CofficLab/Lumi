#if canImport(XCTest)
import XCTest
import LanguageServerProtocol
@testable import Lumi

final class EditorDocumentControllerTests: XCTestCase {
    func testLoadCreatesBufferAndTextStorage() {
        let controller = EditorDocumentController()

        let result = controller.load(text: "hello")

        XCTAssertEqual(result.snapshot.text, "hello")
        XCTAssertEqual(result.snapshot.version, 0)
        XCTAssertEqual(controller.buffer?.text, "hello")
        XCTAssertEqual(controller.textStorage?.string, "hello")
    }

    func testApplyTransactionUpdatesBufferAndTextStorage() {
        let controller = EditorDocumentController()
        _ = controller.load(text: "alpha beta")
        let transaction = EditorTransaction(
            replacements: [
                .init(range: .init(location: 6, length: 4), text: "swift"),
            ]
        )

        let result = controller.apply(transaction: transaction)

        XCTAssertEqual(result?.snapshot.text, "alpha swift")
        XCTAssertEqual(controller.buffer?.text, "alpha swift")
        XCTAssertEqual(controller.textStorage?.string, "alpha swift")
    }

    func testApplyTextEditsUsesCurrentTextAndSyncsStorage() {
        let controller = EditorDocumentController()
        _ = controller.load(text: "alpha beta")
        let edits: [TextEdit] = [
            .init(
                range: .init(
                    start: .init(line: 0, character: 6),
                    end: .init(line: 0, character: 10)
                ),
                newText: "swift"
            ),
        ]

        let result = controller.applyTextEdits(edits)

        XCTAssertEqual(result?.snapshot.text, "alpha swift")
        XCTAssertEqual(controller.currentText, "alpha swift")
        XCTAssertEqual(controller.textStorage?.string, "alpha swift")
    }

    func testSyncBufferFromTextStorageIfNeededPullsUserEditsBackIntoBuffer() {
        let controller = EditorDocumentController()
        _ = controller.load(text: "before")
        controller.textStorage?.mutableString.setString("after")

        let result = controller.syncBufferFromTextStorageIfNeeded()

        XCTAssertEqual(result?.snapshot.text, "after")
        XCTAssertEqual(controller.buffer?.text, "after")
        XCTAssertEqual(controller.textStorage?.string, "after")
        XCTAssertEqual(controller.buffer?.version, 1)
    }

    func testApplyTextStorageEditUpdatesBufferWithoutFullResync() {
        let controller = EditorDocumentController()
        _ = controller.load(text: "hello world")
        controller.textStorage?.mutableString.setString("hello swift")

        let result = controller.applyTextStorageEdit(
            range: NSRange(location: 6, length: 5),
            text: "swift"
        )

        XCTAssertEqual(result?.snapshot.text, "hello swift")
        XCTAssertEqual(controller.buffer?.text, "hello swift")
        XCTAssertEqual(controller.textStorage?.string, "hello swift")
        XCTAssertEqual(controller.buffer?.version, 1)
    }

    func testClearResetsBufferAndTextStorage() {
        let controller = EditorDocumentController()
        _ = controller.load(text: "hello")

        controller.clear()

        XCTAssertNil(controller.buffer)
        XCTAssertNil(controller.textStorage)
    }

    func testPersistedSnapshotTracksDirtyState() {
        let controller = EditorDocumentController()
        _ = controller.load(text: "hello")
        controller.markPersistedText("hello")

        XCTAssertFalse(controller.hasChangesComparedToPersistedSnapshot("hello"))
        XCTAssertTrue(controller.hasChangesComparedToPersistedSnapshot("hello world"))
    }

    func testLoadDocumentDistinguishesTextAndBinaryFiles() throws {
        let controller = EditorDocumentController()
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directoryURL) }

        let textURL = directoryURL.appendingPathComponent("sample.swift")
        try "print(\"hello\")".write(to: textURL, atomically: true, encoding: .utf8)

        let binaryURL = directoryURL.appendingPathComponent("sample.bin")
        try Data([0x00, 0x01, 0x02, 0x03]).write(to: binaryURL)

        let textDocument = try controller.loadDocument(from: textURL, truncationReadBytes: 1024)
        let binaryDocument = try controller.loadDocument(from: binaryURL, truncationReadBytes: 1024)

        switch textDocument {
        case .text(let document):
            XCTAssertEqual(document.content, "print(\"hello\")")
            XCTAssertEqual(document.fileExtension, "swift")
            XCTAssertFalse(document.isTruncated)
        case .binary:
            XCTFail("Expected text document")
        }

        switch binaryDocument {
        case .binary(let document):
            XCTAssertEqual(document.fileExtension, "bin")
        case .text:
            XCTFail("Expected binary document")
        }
    }
}
#endif
