import Foundation
import Testing
@testable import EditorContracts

@Test func positionsCompareByLineThenUTF16Character() {
    #expect(EditorPosition.zero == EditorPosition(line: 0, character: 0))
    #expect(EditorPosition(line: 0, character: 4) < EditorPosition(line: 1, character: 0))
    #expect(EditorPosition(line: 2, character: 1) < EditorPosition(line: 2, character: 2))
}

@Test func rangesNormalizeAndUseHalfOpenOverlapSemantics() {
    let first = EditorRange(EditorPosition(line: 1, character: 4), EditorPosition(line: 0, character: 2))
    let adjacent = EditorRange(EditorPosition(line: 1, character: 4), EditorPosition(line: 2, character: 0))

    #expect(!first.isValid)
    #expect(first.normalized == EditorRange(EditorPosition(line: 0, character: 2), EditorPosition(line: 1, character: 4)))
    #expect(!first.isEmpty)
    #expect(first.overlaps(EditorRange(EditorPosition(line: 1, character: 3), EditorPosition(line: 1, character: 5))))
    #expect(!first.overlaps(adjacent))
    #expect(first.contains(EditorPosition(line: 1, character: 3)))
    #expect(!first.contains(EditorPosition(line: 1, character: 4)))
    #expect(!EditorRange(at: EditorPosition(line: 2, character: 1)).contains(EditorPosition(line: 2, character: 1)))
}

@Test func documentOffsetsRoundTripUsingUTF16ForLFAndCRLF() {
    let lf = makeSnapshot(text: "A🦀\nβ", lineEnding: .lf)
    #expect(lf.lineStartOffsets == [0, 4])
    #expect(lf.offset(of: EditorPosition(line: 0, character: 3)) == 3)
    #expect(lf.position(atOffset: 3) == EditorPosition(line: 0, character: 3))
    #expect(lf.position(atOffset: 4) == EditorPosition(line: 1, character: 0))
    #expect(lf.offset(of: EditorPosition(line: 1, character: 1)) == 5)
    #expect(lf.position(atOffset: -1) == nil)
    #expect(lf.position(atOffset: 6) == nil)
    #expect(lf.offset(of: EditorPosition(line: 2, character: 0)) == nil)

    let crlf = makeSnapshot(text: "A🦀\r\nβ", lineEnding: .crlf)
    #expect(crlf.lineStartOffsets == [0, 5])
    #expect(crlf.offset(of: EditorPosition(line: 0, character: 3)) == 3)
    #expect(crlf.position(atOffset: 3) == EditorPosition(line: 0, character: 3))
    #expect(crlf.position(atOffset: 4) == nil)
    #expect(crlf.position(atOffset: 5) == EditorPosition(line: 1, character: 0))
    #expect(crlf.offset(of: EditorPosition(line: 1, character: 1)) == 6)
}

@Test func emptyDocumentHasOneValidPositionAndSummaryOmitsText() {
    let snapshot = makeSnapshot(text: "", lineEnding: .lf, isDirty: true)

    #expect(snapshot.lineStartOffsets == [0])
    #expect(snapshot.position(atOffset: 0) == .zero)
    #expect(snapshot.offset(of: .zero) == 0)
    #expect(snapshot.position(atOffset: 1) == nil)
    #expect(snapshot.summary.id == snapshot.id)
    #expect(snapshot.summary.revision == snapshot.revision)
    #expect(snapshot.summary.isDirty)
}

private func makeSnapshot(
    text: String,
    lineEnding: EditorLineEnding,
    isDirty: Bool = false
) -> EditorDocumentSnapshot {
    EditorDocumentSnapshot(
        id: .makeUnique(),
        uri: URL(fileURLWithPath: "/tmp/EditorContracts.swift"),
        languageID: "swift",
        revision: 1,
        text: text,
        lineEnding: lineEnding,
        isDirty: isDirty
    )
}
