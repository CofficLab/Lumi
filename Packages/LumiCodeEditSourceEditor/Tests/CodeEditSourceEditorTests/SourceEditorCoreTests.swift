import XCTest
@testable import CodeEditSourceEditor

final class SourceEditorCoreTests: XCTestCase {
    func testFindMethodDisplayNames() {
        XCTAssertEqual(FindMethod.allCases.count, 5)
        XCTAssertEqual(FindMethod.contains.displayName, "Contains")
        XCTAssertEqual(FindMethod.matchesWord.displayName, "Matches Word")
        XCTAssertEqual(FindMethod.startsWith.displayName, "Starts With")
        XCTAssertEqual(FindMethod.endsWith.displayName, "Ends With")
        XCTAssertEqual(FindMethod.regularExpression.displayName, "Regular Expression")
    }

    func testFindPanelModeDisplayNames() {
        XCTAssertEqual(FindPanelMode.allCases, [.find, .replace])
        XCTAssertEqual(FindPanelMode.find.displayName, "Find")
        XCTAssertEqual(FindPanelMode.replace.displayName, "Replace")
    }

    func testFindPanelClearsStaleCurrentMatchIndex() {
        let viewModel = FindPanelViewModel(target: MockFindPanelTarget())
        viewModel.findMatches = [NSRange(location: 0, length: 4)]
        viewModel.currentFindMatchIndex = 4

        XCTAssertNil(viewModel.validCurrentFindMatchIndex())
        XCTAssertNil(viewModel.currentFindMatchIndex)
    }

    func testFindPanelKeepsValidCurrentMatchIndex() {
        let viewModel = FindPanelViewModel(target: MockFindPanelTarget())
        viewModel.findMatches = [
            NSRange(location: 0, length: 4),
            NSRange(location: 10, length: 4)
        ]
        viewModel.currentFindMatchIndex = 1

        XCTAssertEqual(viewModel.validCurrentFindMatchIndex(), 1)
        XCTAssertEqual(viewModel.currentFindMatchIndex, 1)
    }

    func testInvisibleCharactersEmptyDisablesAllTriggers() {
        let config = InvisibleCharactersConfiguration.empty

        XCTAssertFalse(config.showSpaces)
        XCTAssertFalse(config.showTabs)
        XCTAssertFalse(config.showLineEndings)
        XCTAssertTrue(config.triggerCharacters().isEmpty)
    }

    func testInvisibleCharactersTriggerCharactersFollowEnabledGroups() {
        let config = InvisibleCharactersConfiguration(
            showSpaces: true,
            showTabs: false,
            showLineEndings: true
        )

        let triggers = config.triggerCharacters()

        XCTAssertTrue(triggers.contains(InvisibleCharactersConfiguration.Symbols.space))
        XCTAssertFalse(triggers.contains(InvisibleCharactersConfiguration.Symbols.tab))
        XCTAssertTrue(triggers.contains(InvisibleCharactersConfiguration.Symbols.lineFeed))
        XCTAssertTrue(triggers.contains(InvisibleCharactersConfiguration.Symbols.carriageReturn))
        XCTAssertTrue(triggers.contains(InvisibleCharactersConfiguration.Symbols.paragraphSeparator))
        XCTAssertTrue(triggers.contains(InvisibleCharactersConfiguration.Symbols.lineSeparator))
    }

    func testInvisibleCharactersCodableRoundTripPreservesReplacements() throws {
        var config = InvisibleCharactersConfiguration(showSpaces: true, showTabs: true, showLineEndings: true)
        config.spaceReplacement = "."
        config.tabReplacement = "tab"

        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(InvisibleCharactersConfiguration.self, from: data)

        XCTAssertEqual(decoded, config)
    }

    func testTreeSitterByteRangeDoublesUTF16Offsets() {
        let range = NSRange(location: 3, length: 5)

        XCTAssertEqual(range.treeSitterByteRange, 6..<16)
    }

    func testTreeSitterByteRangeRejectsNegativeRanges() {
        XCTAssertNil(NSRange(location: -1, length: 1).treeSitterByteRange)
        XCTAssertNil(NSRange(location: 1, length: -1).treeSitterByteRange)
    }

    func testTreeSitterByteRangeRejectsOverflowingRanges() {
        let maxUTF16Location = Int(UInt32.max / 2)

        XCTAssertNotNil(NSRange(location: maxUTF16Location, length: 0).treeSitterByteRange)
        XCTAssertNil(NSRange(location: maxUTF16Location, length: 1).treeSitterByteRange)
        XCTAssertNil(NSRange(location: Int.max, length: 1).treeSitterByteRange)
    }

    func testRangeStoreIgnoresInvalidStorageEditRanges() {
        var store = RangeStore<TestRangeStoreElement>(documentLength: 5)

        store.storageUpdated(editedRange: NSRange(location: -1, length: 1), changeInLength: 0)
        store.storageUpdated(editedRange: NSRange(location: 1, length: -1), changeInLength: 0)

        XCTAssertEqual(store.length, 5)
    }

    func testRangeStoreIgnoresOverflowingStorageEditRanges() {
        var store = RangeStore<TestRangeStoreElement>(documentLength: 5)

        store.storageUpdated(editedRange: NSRange(location: Int.max, length: 1), changeInLength: 0)
        store.storageUpdated(editedRange: NSRange(location: 1, length: Int.max), changeInLength: -1)

        XCTAssertEqual(store.length, 5)
    }
}

private struct TestRangeStoreElement: RangeStoreElement {
    let value: Int
    var isEmpty: Bool { false }
}
