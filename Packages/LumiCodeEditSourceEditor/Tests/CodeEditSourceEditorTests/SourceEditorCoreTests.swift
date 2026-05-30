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
}
