import Testing
import SwiftUI
@testable import GitPlugin

/// Unit tests for `GitChangeType.fromString`, display labels, and the
/// extracted `GitDiffStats.countInsertionsDeletions` helper.
@Suite struct GitChangeTypeFromStringTests {

    @Test func mapsSingleLetterCodes() {
        #expect(GitChangeType.fromString("M") == .modified)
        #expect(GitChangeType.fromString("A") == .added)
        #expect(GitChangeType.fromString("D") == .deleted)
        #expect(GitChangeType.fromString("R") == .renamed)
        #expect(GitChangeType.fromString("?") == .untracked)
    }

    @Test func mapsFullWords() {
        #expect(GitChangeType.fromString("MODIFIED") == .modified)
        #expect(GitChangeType.fromString("ADDED") == .added)
        #expect(GitChangeType.fromString("DELETED") == .deleted)
        #expect(GitChangeType.fromString("RENAMED") == .renamed)
        #expect(GitChangeType.fromString("UNTRACKED") == .untracked)
    }

    @Test func isCaseInsensitive() {
        #expect(GitChangeType.fromString("m") == .modified)
        #expect(GitChangeType.fromString("Added") == .added)
    }

    @Test func copiedMapsToRenamed() {
        // Documented behavior: copy is collapsed into rename.
        #expect(GitChangeType.fromString("C") == .renamed)
        #expect(GitChangeType.fromString("COPIED") == .renamed)
    }

    @Test func unknownDefaultsToModified() {
        #expect(GitChangeType.fromString("") == .modified)
        #expect(GitChangeType.fromString("xyz") == .modified)
        #expect(GitChangeType.fromString("T") == .modified)
    }

    @Test func displayLabelMatchesRawValue() {
        #expect(GitChangeType.modified.displayLabel == "M")
        #expect(GitChangeType.added.displayLabel == "A")
        #expect(GitChangeType.deleted.displayLabel == "D")
        #expect(GitChangeType.renamed.displayLabel == "R")
        #expect(GitChangeType.untracked.displayLabel == "?")
    }
}

@Suite struct GitDiffStatsCountingTests {

    @Test func countsSimpleAdditionsAndDeletions() {
        let diff = """
        diff --git a/f.txt b/f.txt
        index 123..456 100644
        --- a/f.txt
        +++ b/f.txt
        @@ -1,2 +1,2 @@
         context line
        -old line
        +new line
        """
        let (ins, dels) = GitDiffStats.countInsertionsDeletions(in: diff)
        #expect(ins == 1)
        #expect(dels == 1)
    }

    @Test func skipsFileHeaders() {
        // +++/--- headers must NOT be counted.
        let diff = """
        --- a/file
        +++ b/file
        +added
        -removed
        """
        let (ins, dels) = GitDiffStats.countInsertionsDeletions(in: diff)
        #expect(ins == 1)
        #expect(dels == 1)
    }

    @Test func countsContentStartingWithPlusPlus() {
        // A real added line whose content begins with "++" is currently skipped
        // (mistaken for a header). Document this known limitation.
        let diff = "++ added line that looks like a header"
        let (ins, dels) = GitDiffStats.countInsertionsDeletions(in: diff)
        #expect(ins == 0)
        #expect(dels == 0)
    }

    @Test func ignoresContextAndHunkHeaders() {
        let diff = """
        @@ -1,3 +1,3 @@
          context
         other context
        """
        let (ins, dels) = GitDiffStats.countInsertionsDeletions(in: diff)
        #expect(ins == 0)
        #expect(dels == 0)
    }

    @Test func emptyDiffHasZeroCounts() {
        let (ins, dels) = GitDiffStats.countInsertionsDeletions(in: "")
        #expect(ins == 0)
        #expect(dels == 0)
    }

    @Test func multipleChangesAccumulate() {
        let diff = """
        +a
        +b
        -c
        +d
        """
        let (ins, dels) = GitDiffStats.countInsertionsDeletions(in: diff)
        #expect(ins == 3)
        #expect(dels == 1)
    }
}
