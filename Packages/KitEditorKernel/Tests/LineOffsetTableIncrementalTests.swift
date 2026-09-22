import Foundation
import Testing
@testable import EditorKernel

/// Tests for the incremental update API added to ``LineOffsetTable``
/// as part of the Editor performance optimization work.
struct LineOffsetTableIncrementalTests {

    // MARK: - Initialization correctness (regression checks)

    @Test
    func initProducesCorrectLineStarts() {
        let table = LineOffsetTable(content: "alpha\nbeta\ngamma\n")
        #expect(table.lineCount == 4)
        #expect(table.lineStart(line: 0) == 0)   // "alpha\n"
        #expect(table.lineStart(line: 1) == 6)   // "beta\n"
        #expect(table.lineStart(line: 2) == 11)  // "gamma\n"
        #expect(table.lineStart(line: 3) == 17)  // "" (empty line after last \n)
        // 5+1+4+1+5+1 = 17
        #expect(table.totalUTF16Length == 17)
    }

    @Test
    func initProducesCorrectLineStartsWithEmptyString() {
        let table = LineOffsetTable(content: "")
        #expect(table.lineCount == 1)
        #expect(table.lineStart(line: 0) == 0)
        #expect(table.totalUTF16Length == 0)
    }

    @Test
    func initSingleLineNoTrailingNewline() {
        let table = LineOffsetTable(content: "hello world")
        #expect(table.lineCount == 1)
        #expect(table.totalUTF16Length == 11)
    }

    @Test
    func initUnicodeContent() {
        let table = LineOffsetTable(content: "a\n😀b\n")
        #expect(table.lineCount == 3)
        #expect(table.utf16Offset(line: 1, character: 2) == 4)
        #expect(table.lineContaining(utf16Offset: 3) == 1)
        #expect(table.totalUTF16Length == 6)
    }

    @Test
    func updateRejectsInvalidEditRangesWithoutChangingTable() {
        let table = LineOffsetTable(content: "abc\ndef\n")

        let negativeLength = table.update(
            editRange: NSRange(location: 1, length: -1),
            changeInLength: 0
        )
        #expect(negativeLength.lineCount == table.lineCount)
        #expect(negativeLength.totalUTF16Length == table.totalUTF16Length)

        let overflowingRange = table.update(
            editRange: NSRange(location: Int.max, length: 1),
            changeInLength: 1
        )
        #expect(overflowingRange.lineCount == table.lineCount)
        #expect(overflowingRange.totalUTF16Length == table.totalUTF16Length)

        let negativeTotal = table.update(
            editRange: NSRange(location: 0, length: 1),
            changeInLength: -100
        )
        #expect(negativeTotal.lineCount == table.lineCount)
        #expect(negativeTotal.totalUTF16Length == table.totalUTF16Length)
    }

    // MARK: - Incremental update: single character insertion (no newline)

    @Test
    func updateInsertCharacterOnFirstLine() {
        let original = LineOffsetTable(content: "abc\ndef\n")
        // Insert "x" at offset 1, no newlines -> "axbc\ndef\n"
        let updated = original.update(editRange: NSRange(location: 1, length: 0), changeInLength: 1, newContent: "x")

        #expect(updated.lineCount == 3)
        #expect(updated.lineStart(line: 0) == 0)
        #expect(updated.lineStart(line: 1) == 5)  // was 4, +1
        #expect(updated.lineStart(line: 2) == 9)  // was 8, +1
        #expect(updated.totalUTF16Length == 9)
    }

    @Test
    func updateInsertCharacterOnSecondLine() {
        let original = LineOffsetTable(content: "abc\ndef\nghi\n")
        // Insert "x" at offset 5 (in "def") -> "abc\ndexf\nghi\n"
        let updated = original.update(editRange: NSRange(location: 5, length: 0), changeInLength: 1, newContent: "x")

        #expect(updated.lineCount == 4)
        #expect(updated.lineStart(line: 0) == 0)
        #expect(updated.lineStart(line: 1) == 4)
        #expect(updated.lineStart(line: 2) == 9)  // was 8, +1
        #expect(updated.lineStart(line: 3) == 13) // was 12, +1
        #expect(updated.totalUTF16Length == 13)
    }

    // MARK: - Incremental update: single character deletion

    @Test
    func updateDeleteCharacter() {
        let original = LineOffsetTable(content: "abc\ndef\n")
        // Delete 'b' at offset 1 -> "ac\ndef\n"
        let updated = original.update(editRange: NSRange(location: 1, length: 1), changeInLength: -1, newContent: "")

        #expect(updated.lineCount == 3)
        #expect(updated.lineStart(line: 0) == 0)
        #expect(updated.lineStart(line: 1) == 3)  // was 4, -1
        #expect(updated.lineStart(line: 2) == 7)  // was 8, -1
        #expect(updated.totalUTF16Length == 7)
    }

    // MARK: - Incremental update: newline insertion (adds new line)

    @Test
    func updateInsertNewlineAddsLine() {
        let original = LineOffsetTable(content: "abc\ndef\n")
        // Insert "\n" at offset 2 -> "ab\nc\ndef\n"
        let updated = original.update(editRange: NSRange(location: 2, length: 0), changeInLength: 1, newContent: "\n")

        // After inserting \n at offset 2:
        // "ab\n" -> lineStart[0]=0, lineStart[1]=3
        // "c\n"  -> lineStart[2]=5  (offset 2 + newline at 3 = 4, +1 = 5)
        // "def\n" -> lineStart[3]=9
        #expect(updated.lineCount == 4)  // was 3, now 4
        #expect(updated.lineStart(line: 0) == 0)
        #expect(updated.lineStart(line: 1) == 3)  // the new \n creates a new line starting after offset 2+1
        #expect(updated.lineStart(line: 2) == 5)   // was 4, now 5 (because the insert at offset 2 shifted it by +1)
        #expect(updated.lineStart(line: 3) == 9)   // was 8, now 9 (shifted by +1)
        #expect(updated.totalUTF16Length == 9)
    }

    @Test
    func updateInsertNewlineAtBeginning() {
        let original = LineOffsetTable(content: "abc\ndef\n")
        // Insert "\n" at offset 0 -> "\nabc\ndef\n"
        let updated = original.update(editRange: NSRange(location: 0, length: 0), changeInLength: 1, newContent: "\n")

        #expect(updated.lineCount == 4)
        #expect(updated.lineStart(line: 0) == 0)
        #expect(updated.lineStart(line: 1) == 1)
        #expect(updated.lineStart(line: 2) == 5)  // was 4, +1
        #expect(updated.lineStart(line: 3) == 9)  // was 8, +1
    }

    @Test
    func updateInsertMultipleNewlines() {
        let original = LineOffsetTable(content: "abc\n")
        // Insert "\n\n" at offset 0 -> "\n\nabc\n"
        let updated = original.update(editRange: NSRange(location: 0, length: 0), changeInLength: 2, newContent: "\n\n")

        #expect(updated.lineCount == 4)  // was 2, now 4 (added 2 newlines)
        #expect(updated.lineStart(line: 0) == 0)
        #expect(updated.lineStart(line: 1) == 1)  // first \n
        #expect(updated.lineStart(line: 2) == 2)  // second \n
        #expect(updated.lineStart(line: 3) == 6)  // was 4, +2
        #expect(updated.totalUTF16Length == 6)
    }

    // MARK: - Incremental update: newline deletion (removes line)

    @Test
    func updateDeleteNewlineRemovesLine() {
        let original = LineOffsetTable(content: "abc\ndef\nghi\n")
        // Delete the first \n at offset 3 -> "abcdef\nghi\n"
        let updated = original.update(editRange: NSRange(location: 3, length: 1), changeInLength: -1, newContent: "")

        #expect(updated.lineCount == 3)  // was 4, now 3
        #expect(updated.lineStart(line: 0) == 0)
        #expect(updated.lineStart(line: 1) == 7)   // was 8, -1
        #expect(updated.lineStart(line: 2) == 11)  // was 12, -1
        #expect(updated.totalUTF16Length == 11)
    }

    // MARK: - Incremental update: edge cases

    @Test
    func updateEmptyContentInsert() {
        let original = LineOffsetTable(content: "")
        let updated = original.update(editRange: NSRange(location: 0, length: 0), changeInLength: 5, newContent: "hello")

        #expect(updated.lineCount == 1)
        #expect(updated.lineStart(line: 0) == 0)
        #expect(updated.totalUTF16Length == 5)
    }

    @Test
    func updateEmptyContentInsertWithNewline() {
        let original = LineOffsetTable(content: "")
        let updated = original.update(editRange: NSRange(location: 0, length: 0), changeInLength: 1, newContent: "\n")

        #expect(updated.lineCount == 2)
        #expect(updated.lineStart(line: 0) == 0)
        #expect(updated.lineStart(line: 1) == 1)
        #expect(updated.totalUTF16Length == 1)
    }

    @Test
    func updateInsertAtEndOfDocument() {
        let original = LineOffsetTable(content: "abc\n")
        let updated = original.update(editRange: NSRange(location: 4, length: 0), changeInLength: 3, newContent: "xyz")

        #expect(updated.lineCount == 2)
        #expect(updated.lineStart(line: 0) == 0)
        #expect(updated.lineStart(line: 1) == 4)
        #expect(updated.totalUTF16Length == 7)
    }

    // MARK: - Query correctness after update

    @Test
    func lineContainingAfterInsert() {
        let original = LineOffsetTable(content: "abc\ndef\n")
        // Insert "xx" at offset 1 -> "axxbc\ndef\n"
        let updated = original.update(editRange: NSRange(location: 1, length: 0), changeInLength: 2, newContent: "xx")

        #expect(updated.lineContaining(utf16Offset: 0) == 0)
        #expect(updated.lineContaining(utf16Offset: 2) == 0)
        #expect(updated.lineContaining(utf16Offset: 5) == 0)  // 'c'
        #expect(updated.lineContaining(utf16Offset: 6) == 1)  // \n
        #expect(updated.lineContaining(utf16Offset: 7) == 1)  // 'd'
        #expect(updated.lineContaining(utf16Offset: 10) == 2) // \n
    }

    @Test
    func lineContainingAfterDelete() {
        let original = LineOffsetTable(content: "abc\ndef\n")
        // Delete 'b' at offset 1 -> "ac\ndef\n"
        let updated = original.update(editRange: NSRange(location: 1, length: 1), changeInLength: -1, newContent: "")

        #expect(updated.lineContaining(utf16Offset: 0) == 0)
        #expect(updated.lineContaining(utf16Offset: 1) == 0)  // 'c'
        #expect(updated.lineContaining(utf16Offset: 2) == 0)  // 'c' or \n... wait
        #expect(updated.lineContaining(utf16Offset: 3) == 1)  // \n
        #expect(updated.lineContaining(utf16Offset: 4) == 1)  // 'd'
    }

    @Test
    func utf16OffsetAfterInsert() {
        let original = LineOffsetTable(content: "abc\ndef\n")
        // Insert "xx" at offset 1 -> "axxbc\ndef\n"
        let updated = original.update(editRange: NSRange(location: 1, length: 0), changeInLength: 2, newContent: "xx")

        #expect(updated.utf16Offset(line: 0, character: 0) == 0)
        #expect(updated.utf16Offset(line: 0, character: 5) == 5)
        #expect(updated.utf16Offset(line: 1, character: 0) == 6)
        #expect(updated.utf16Offset(line: 1, character: 1) == 7)
    }

    // MARK: - Consistency with full rebuild

    @Test
    func updateMatchesFullRebuildForSimpleInsertion() {
        let original = LineOffsetTable(content: "line1\nline2\nline3\n")
        // Insert 'x' at offset 6 (start of line2)
        let updated = original.update(editRange: NSRange(location: 6, length: 0), changeInLength: 1, newContent: "x")

        // Rebuild from the expected text after insertion: "line1\nxline2\nline3\n"
        let expected = LineOffsetTable(content: "line1\nxline2\nline3\n")

        #expect(updated.lineCount == expected.lineCount)
        for i in 0..<expected.lineCount {
            #expect(updated.lineStart(line: i) == expected.lineStart(line: i))
        }
        #expect(updated.totalUTF16Length == expected.totalUTF16Length)
    }

    @Test
    func updateMatchesFullRebuildForNewlineInsertion() {
        let original = LineOffsetTable(content: "abc\ndef\nghi\n")
        // Insert '\n' at offset 4 (start of line "def")
        let updated = original.update(editRange: NSRange(location: 4, length: 0), changeInLength: 1, newContent: "\n")

        // Expected: "abc\n\ndef\nghi\n"
        let expected = LineOffsetTable(content: "abc\n\ndef\nghi\n")

        #expect(updated.lineCount == expected.lineCount)
        for i in 0..<expected.lineCount {
            #expect(updated.lineStart(line: i) == expected.lineStart(line: i))
        }
        #expect(updated.totalUTF16Length == expected.totalUTF16Length)
    }
}
