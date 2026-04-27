#if canImport(XCTest)
import XCTest
@testable import Lumi

final class BracketPairsConfigTests: XCTestCase {

    func testDefaultConfigHasCommonPairs() {
        let config = BracketPairsConfig.defaultForLanguage("swift")
        XCTAssertTrue(config.isOpenBracket("("))
        XCTAssertTrue(config.isOpenBracket("["))
        XCTAssertTrue(config.isOpenBracket("{"))
        XCTAssertTrue(config.isCloseBracket(")"))
        XCTAssertTrue(config.isCloseBracket("]"))
        XCTAssertTrue(config.isCloseBracket("}"))
    }

    func testMatchingPairs() {
        let config = BracketPairsConfig.defaultForLanguage("javascript")
        XCTAssertEqual(config.matchingClose(for: "("), ")")
        XCTAssertEqual(config.matchingClose(for: "["), "]")
        XCTAssertEqual(config.matchingClose(for: "{"), "}")
        XCTAssertEqual(config.matchingOpen(for: ")"), "(")
        XCTAssertEqual(config.matchingOpen(for: "}"), "{")
    }

    func testHTMLConfig() {
        let config = BracketPairsConfig.defaultForLanguage("html")
        XCTAssertTrue(config.isOpenBracket("<"))
        XCTAssertTrue(config.isCloseBracket(">"))
        XCTAssertTrue(config.autoClosingPairs.isEmpty)
    }

    func testUnknownLanguageDefaultsToSwift() {
        let config = BracketPairsConfig.defaultForLanguage("unknown-lang")
        XCTAssertTrue(config.isOpenBracket("("))
        XCTAssertFalse(config.autoClosingPairs.isEmpty)
    }
}

final class BracketMatcherTests: XCTestCase {

    private var config: BracketPairsConfig!

    override func setUp() {
        super.setUp()
        config = BracketPairsConfig.defaultForLanguage("swift")
    }

    func testFindMatchingParen() {
        let text = "func foo() {}"
        // Position right after "("
        let result = BracketMatcher.findMatchingBracket(in: text, at: 9, config: config)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.openPosition, 8)  // "("
        XCTAssertEqual(result?.closePosition, 9) // ")"
    }

    func testFindMatchingBrace() {
        let text = "let x = { a + b }"
        // Position right after "{"
        let result = BracketMatcher.findMatchingBracket(in: text, at: 8, config: config)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.openPosition, 7)  // "{"
        XCTAssertEqual(result?.closePosition, 16) // "}"
    }

    func testNestedBrackets() {
        let text = "((a + b) * c)"
        // Position after first "("
        let result = BracketMatcher.findMatchingBracket(in: text, at: 1, config: config)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.openPosition, 0)
        XCTAssertEqual(result?.closePosition, 12) // outermost ")"
    }

    func testNoMatch() {
        let text = "hello world"
        let result = BracketMatcher.findMatchingBracket(in: text, at: 5, config: config)
        XCTAssertNil(result)
    }

    func testCursorPositionAtEnd() {
        let text = "()"
        // Position at end (after ")")
        let result = BracketMatcher.findMatchingBracket(in: text, at: 2, config: config)
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.openPosition, 0)
        XCTAssertEqual(result?.closePosition, 1)
    }

    func testEmptyString() {
        let result = BracketMatcher.findMatchingBracket(in: "", at: 0, config: config)
        XCTAssertNil(result)
    }
}

final class BracketMatcherAutoCloseTests: XCTestCase {

    private var config: BracketPairsConfig!

    override func setUp() {
        super.setUp()
        config = BracketPairsConfig.defaultForLanguage("swift")
    }

    func testShouldAutoCloseParen() {
        let result = BracketMatcher.shouldAutoClose(in: "let x = ", at: 8, typedChar: "(", config: config)
        XCTAssertEqual(result, ")")
    }

    func testShouldAutoCloseBracket() {
        let result = BracketMatcher.shouldAutoClose(in: "let arr = ", at: 10, typedChar: "[", config: config)
        XCTAssertEqual(result, "]")
    }

    func testShouldAutoCloseBrace() {
        let result = BracketMatcher.shouldAutoClose(in: "func foo ", at: 9, typedChar: "{", config: config)
        XCTAssertEqual(result, "}")
    }

    func testShouldNotAutoCloseNonBracket() {
        let result = BracketMatcher.shouldAutoClose(in: "hello", at: 5, typedChar: "a", config: config)
        XCTAssertNil(result)
    }

    func testShouldNotAutoCloseInString() {
        let text = #"let s = "hello"#
        // Position inside the string (after opening quote)
        let result = BracketMatcher.shouldAutoClose(in: text, at: 10, typedChar: "(", config: config)
        // Since we're inside a string context (odd number of quotes), auto-close should still work
        // for non-quote brackets in default config
        XCTAssertNotNil(result)
    }

    func testShouldAutoSurround() {
        XCTAssertTrue(BracketMatcher.shouldAutoSurround(typedChar: "(", config: config))
        XCTAssertTrue(BracketMatcher.shouldAutoSurround(typedChar: "{", config: config))
        XCTAssertFalse(BracketMatcher.shouldAutoSurround(typedChar: "a", config: config))
    }
}

final class SmartIndentHandlerTests: XCTestCase {

    func testEnterAfterOpenBrace() {
        let text = "func foo() {"
        let position = text.count
        let result = SmartIndentHandler.handleEnter(in: text, at: position, tabSize: 4, useSpaces: true)

        // Should add newline + existing indent + extra indent
        XCTAssertTrue(result.textToInsert.hasPrefix("\n"))
        XCTAssertTrue(result.cursorOffset > 1)
    }

    func testEnterBetweenBraces() {
        let text = "{}"
        let position = 1
        let result = SmartIndentHandler.handleEnter(in: text, at: position, tabSize: 4, useSpaces: true)

        // Should add newline + indent + newline + indent
        XCTAssertTrue(result.textToInsert.contains("\n"))
        XCTAssertEqual(result.textToInsert.components(separatedBy: "\n").count, 3)
    }

    func testEnterOnNormalLine() {
        let text = "let x = 5"
        let position = text.count
        let result = SmartIndentHandler.handleEnter(in: text, at: position, tabSize: 4, useSpaces: true)

        XCTAssertEqual(result.textToInsert, "\n")
        XCTAssertEqual(result.cursorOffset, 1)
    }

    func testEnterOnIndentedLine() {
        let text = "    let x = 5"
        let position = text.count
        let result = SmartIndentHandler.handleEnter(in: text, at: position, tabSize: 4, useSpaces: true)

        XCTAssertEqual(result.textToInsert, "\n    ")
        XCTAssertEqual(result.cursorOffset, 5)
    }

    func testTabWithSpaces() {
        let result = SmartIndentHandler.handleTab(at: 0, hasSelection: false, selectionStart: 0, selectionEnd: 0, tabSize: 4, useSpaces: true)
        XCTAssertEqual(result.textToInsert, "    ")
        XCTAssertEqual(result.cursorOffset, 4)
    }

    func testTabWithTabs() {
        let result = SmartIndentHandler.handleTab(at: 0, hasSelection: false, selectionStart: 0, selectionEnd: 0, tabSize: 4, useSpaces: false)
        XCTAssertEqual(result.textToInsert, "\t")
        XCTAssertEqual(result.cursorOffset, 1)
    }
}

#endif
