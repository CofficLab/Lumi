#if canImport(XCTest)
import XCTest
import LanguageServerProtocol
@testable import Lumi

@MainActor
final class EditorSelectionStabilityTests: XCTestCase {

    func testWorkspaceEditChangesRemapCurrentSelectionAfterFormattingLikeEdit() async throws {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directoryURL) }

        let fileURL = directoryURL.appendingPathComponent("format.swift")
        try "foo( )\n".write(to: fileURL, atomically: true, encoding: .utf8)

        let state = EditorState()
        state.loadFile(from: fileURL)
        try await waitFor { state.content?.string == "foo( )\n" }

        state.setSelections([.init(location: 5, length: 0)])

        let edit = WorkspaceEdit(
            changes: [
                fileURL.absoluteString: [
                    TextEdit(
                        range: LSPRange(
                            start: Position(line: 0, character: 4),
                            end: Position(line: 0, character: 5)
                        ),
                        newText: ""
                    )
                ]
            ],
            documentChanges: nil
        )

        state.applyCodeActionWorkspaceEdit(edit)

        XCTAssertEqual(state.content?.string, "foo()\n")
        XCTAssertEqual(state.currentSelectionsAsNSRanges(), [NSRange(location: 4, length: 0)])
        XCTAssertEqual(state.canonicalSelectionSet.primary?.range, EditorRange(location: 4, length: 0))
    }

    func testWorkspaceEditDocumentChangesRemapCurrentSelectionAfterRenameLikeEdit() async throws {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directoryURL) }

        let fileURL = directoryURL.appendingPathComponent("rename.swift")
        try "foo bar\n".write(to: fileURL, atomically: true, encoding: .utf8)

        let state = EditorState()
        state.loadFile(from: fileURL)
        try await waitFor { state.content?.string == "foo bar\n" }

        state.setSelections([.init(location: 5, length: 0)])

        let edit = WorkspaceEdit(
            changes: nil,
            documentChanges: [
                .textDocumentEdit(
                    TextDocumentEdit(
                        textDocument: VersionedTextDocumentIdentifier(
                            uri: fileURL.absoluteString,
                            version: nil
                        ),
                        edits: [
                            TextEdit(
                                range: LSPRange(
                                    start: Position(line: 0, character: 0),
                                    end: Position(line: 0, character: 3)
                                ),
                                newText: "foobar"
                            )
                        ]
                    )
                )
            ]
        )

        state.applyCodeActionWorkspaceEdit(edit)

        XCTAssertEqual(state.content?.string, "foobar bar\n")
        XCTAssertEqual(state.currentSelectionsAsNSRanges(), [NSRange(location: 8, length: 0)])
        XCTAssertEqual(state.canonicalSelectionSet.primary?.range, EditorRange(location: 8, length: 0))
    }

    func testCompletionEditRestoresSelectionAfterPrimaryReplacement() async throws {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directoryURL) }

        let fileURL = directoryURL.appendingPathComponent("completion.swift")
        try "pri\n".write(to: fileURL, atomically: true, encoding: .utf8)

        let state = EditorState()
        state.loadFile(from: fileURL)
        try await waitFor { state.content?.string == "pri\n" }

        state.setSelections([.init(location: 3, length: 0)])

        let ok = state.applyCompletionEdit(
            replacementRange: NSRange(location: 0, length: 3),
            replacementText: "print",
            additionalTextEdits: nil
        )

        XCTAssertTrue(ok)
        XCTAssertEqual(state.content?.string, "print\n")
        XCTAssertEqual(state.currentSelectionsAsNSRanges(), [NSRange(location: 5, length: 0)])
        XCTAssertEqual(state.canonicalSelectionSet.primary?.range, EditorRange(location: 5, length: 0))
    }

    func testCompletionEditRestoresSelectionWithAdditionalTextEdits() async throws {
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directoryURL) }

        let fileURL = directoryURL.appendingPathComponent("completion-additional.swift")
        try "Foo.b\n".write(to: fileURL, atomically: true, encoding: .utf8)

        let state = EditorState()
        state.loadFile(from: fileURL)
        try await waitFor { state.content?.string == "Foo.b\n" }

        state.setSelections([.init(location: 5, length: 0)])

        let ok = state.applyCompletionEdit(
            replacementRange: NSRange(location: 4, length: 1),
            replacementText: "bar",
            additionalTextEdits: [
                TextEdit(
                    range: LSPRange(
                        start: Position(line: 0, character: 0),
                        end: Position(line: 0, character: 0)
                    ),
                    newText: "self."
                )
            ]
        )

        XCTAssertTrue(ok)
        XCTAssertEqual(state.content?.string, "self.Foo.bar\n")
        XCTAssertEqual(state.currentSelectionsAsNSRanges(), [NSRange(location: 12, length: 0)])
        XCTAssertEqual(state.canonicalSelectionSet.primary?.range, EditorRange(location: 12, length: 0))
    }

    private func waitFor(
        timeout: TimeInterval = 3.0,
        poll: UInt64 = 100_000_000,
        condition: @escaping @MainActor () -> Bool
    ) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return }
            try await Task.sleep(nanoseconds: poll)
        }
        XCTFail("Condition not met within timeout")
    }
}

#endif
