import Foundation
import Testing
@testable import EditorContracts

@Test func documentEditsDetectOverlappingRangesAndInteriorInsertions() {
    let replacement = EditorTextEdit(
        range: EditorRange(EditorPosition(line: 0, character: 2), EditorPosition(line: 0, character: 6)),
        newText: "value"
    )
    let overlapping = EditorTextEdit(
        range: EditorRange(EditorPosition(line: 0, character: 4), EditorPosition(line: 0, character: 8)),
        newText: "other"
    )
    let insertAtBoundary = EditorTextEdit(
        range: EditorRange(at: EditorPosition(line: 0, character: 6)),
        newText: "!"
    )
    let insertInside = EditorTextEdit(
        range: EditorRange(at: EditorPosition(line: 0, character: 4)),
        newText: "!"
    )

    #expect(EditorDocumentEdit(documentID: .makeUnique(), edits: [replacement, overlapping]).hasOverlappingEdits)
    #expect(!EditorDocumentEdit(documentID: .makeUnique(), edits: [replacement, insertAtBoundary]).hasOverlappingEdits)
    #expect(EditorDocumentEdit(documentID: .makeUnique(), edits: [replacement, insertInside]).hasOverlappingEdits)
    #expect(EditorDocumentEdit(documentID: .makeUnique(), edits: [insertInside, insertInside]).hasOverlappingEdits)
}

@Test func workspaceEditsSortAndSummarizeDeterministically() {
    let documentID = EditorDocumentID.makeUnique()
    let later = EditorTextEdit(
        range: EditorRange(EditorPosition(line: 3, character: 0), EditorPosition(line: 3, character: 1)),
        newText: "later"
    )
    let earlier = EditorTextEdit(
        range: EditorRange(EditorPosition(line: 1, character: 0), EditorPosition(line: 1, character: 1)),
        newText: "earlier"
    )
    let workspaceEdit = EditorWorkspaceEdit(
        documentEdits: [
            EditorDocumentEdit(documentID: documentID, edits: [later, earlier]),
            EditorDocumentEdit(documentID: .makeUnique(), edits: [earlier]),
        ],
        fileOperations: [EditorFileOperation(uri: URL(fileURLWithPath: "/tmp/old.swift"), kind: .rename(to: URL(fileURLWithPath: "/tmp/new.swift")))]
    )

    #expect(!workspaceEdit.isEmpty)
    #expect(workspaceEdit.documentEdits[0].sortedEdits == [earlier, later])
    #expect(workspaceEdit.summaryDescription == "3 edits in 2 files, 1 file operation")
    #expect(EditorWorkspaceEdit().isEmpty)
    #expect(EditorWorkspaceEdit().summaryDescription.isEmpty)
}

@Test func workspaceEditResultsReportFullAndPartialSuccess() {
    let successful = EditorWorkspaceEditResult(appliedDocumentIDs: [.makeUnique()])
    let failedID = EditorDocumentID.makeUnique()
    let partial = EditorWorkspaceEditResult(
        appliedDocumentIDs: [],
        failures: [failedID: .documentNotFound(failedID)]
    )

    #expect(successful.isCompleteSuccess)
    #expect(!partial.isCompleteSuccess)
}

@Test func diffHunksExposeChangedLinesRangesAndStableIdentity() {
    let hunk = EditorDiffHunk(
        oldStart: 2,
        newStart: 2,
        lines: [
            EditorDiffLine(kind: .unchanged, oldLineNumber: 2, newLineNumber: 2, content: "context"),
            EditorDiffLine(kind: .removed, oldLineNumber: 3, newLineNumber: nil, content: "old"),
            EditorDiffLine(kind: .added, oldLineNumber: nil, newLineNumber: 3, content: "new"),
            EditorDiffLine(kind: .added, oldLineNumber: nil, newLineNumber: 4, content: "next"),
        ]
    )
    let document = EditorDiffDocument(uri: URL(fileURLWithPath: "/tmp/file.swift"), hunks: [hunk])

    #expect(hunk.hasChanges)
    #expect(hunk.addedContents == ["new", "next"])
    #expect(hunk.removedContents == ["old"])
    #expect(hunk.oldChangeRange == 3...3)
    #expect(hunk.newChangeRange == 3...4)
    #expect(!hunk.id.isEmpty)
    #expect(document.addedLineCount == 2)
    #expect(document.removedLineCount == 1)
    #expect(!document.isEmpty)
    #expect(EditorDiffDocument.empty(for: document.uri).isEmpty)
}

@Test func pureAddedAndUnchangedHunksHaveOptionalChangeRanges() {
    let added = EditorDiffHunk(
        oldStart: 0,
        newStart: 1,
        lines: [EditorDiffLine(kind: .added, oldLineNumber: nil, newLineNumber: 1, content: "new")]
    )
    let unchanged = EditorDiffHunk(
        oldStart: 1,
        newStart: 1,
        lines: [EditorDiffLine(kind: .unchanged, oldLineNumber: 1, newLineNumber: 1, content: "same")]
    )

    #expect(added.oldChangeRange == nil)
    #expect(added.newChangeRange == 1...1)
    #expect(!unchanged.hasChanges)
    #expect(unchanged.oldChangeRange == nil)
    #expect(unchanged.newChangeRange == nil)
}
