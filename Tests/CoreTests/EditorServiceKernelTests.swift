#if canImport(XCTest)
import XCTest
@testable import Lumi

/// EditorService 内核纯逻辑测试。
///
/// 这组测试只覆盖 `LumiApp/Core/Services/EditorService` 下无需 UI / 插件环境的逻辑，
/// 保持 `CoreTests` 作为内核回归测试目录的职责。
@MainActor
final class EditorServiceKernelTests: XCTestCase {

    /// 回归：多行缩进时 `lineStarts` 返回的是 UTF-16 偏移。
    /// 之前这里把偏移直接当作 `String.Index` 的字符位移使用，遇到 emoji 会触发越界崩溃。
    func testSmartIndentHandlerTabSafelyIndentsUnicodeLines() {
        let text = "😀 first\nsecond"

        let result = SmartIndentHandler.handleTab(
            in: text,
            selection: NSRange(location: 0, length: (text as NSString).length),
            tabSize: 4,
            useSpaces: true
        )

        XCTAssertEqual(result?.replacementText, "    😀 first\n    second")
        XCTAssertEqual(
            result?.selectedRange,
            NSRange(location: 0, length: ("    😀 first\n    second" as NSString).length)
        )
    }

    /// 通过输入控制器验证同一条内核路径，确保编辑器层仍能拿到有效 plan。
    func testEditorTextInputControllerInsertTabPlanSupportsUnicodeSelections() {
        let controller = EditorTextInputController()
        let text = "😀 first\nsecond"

        let plan = controller.insertTabPlan(
            textViewSelections: [NSRange(location: 0, length: (text as NSString).length)],
            multiCursorSelectionCount: 1,
            currentText: text,
            tabSize: 4,
            useSpaces: true
        )

        XCTAssertEqual(plan?.reason, "smart_outdent")
        XCTAssertEqual(plan?.replacementText, "    😀 first\n    second")
        XCTAssertEqual(
            plan?.selectedRanges,
            [NSRange(location: 0, length: ("    😀 first\n    second" as NSString).length)]
        )
    }

    func testSmartIndentHandlerEnterBetweenBracesAddsIndentedBlankLine() {
        let result = SmartIndentHandler.handleEnter(
            in: "{}",
            at: 1,
            tabSize: 4,
            useSpaces: true
        )

        XCTAssertEqual(result.textToInsert, "\n    \n")
        XCTAssertEqual(result.cursorOffset, 5)
    }

    func testSmartIndentHandlerBacktabOutdentsAllSelectedLines() {
        let text = "    first\n    second"

        let result = SmartIndentHandler.handleBacktab(
            in: text,
            selection: NSRange(location: 0, length: (text as NSString).length),
            tabSize: 4,
            useSpaces: true
        )

        XCTAssertEqual(result?.replacementText, "first\nsecond")
        XCTAssertEqual(
            result?.selectedRange,
            NSRange(location: 0, length: ("first\nsecond" as NSString).length)
        )
    }

    func testSmartIndentHandlerEnterPreservesCRLFLineEndings() {
        let text = "if true {\r\n    value\r\n}"

        let result = SmartIndentHandler.handleEnter(
            in: text,
            at: "if true {\r\n    value".count,
            tabSize: 4,
            useSpaces: true
        )

        XCTAssertEqual(result.textToInsert, "\r\n    ")
        XCTAssertEqual(result.cursorOffset, 6)
    }

    func testSmartIndentHandlerTabUsesHardTabsWhenConfigured() {
        let result = SmartIndentHandler.handleTab(
            at: 0,
            hasSelection: false,
            selectionStart: 0,
            selectionEnd: 0,
            tabSize: 4,
            useSpaces: false
        )

        XCTAssertEqual(result.textToInsert, "\t")
        XCTAssertEqual(result.cursorOffset, 1)
    }

    func testSmartIndentHandlerBacktabReturnsNilWhenLineHasNoIndent() {
        let result = SmartIndentHandler.handleBacktab(
            in: "value",
            selection: NSRange(location: 0, length: 5),
            tabSize: 4,
            useSpaces: true
        )

        XCTAssertNil(result)
    }

    func testSmartIndentHandlerBacktabRemovesLeadingSpacesFromCurrentLine() {
        let text = "    let value = 1"

        let result = SmartIndentHandler.handleBacktab(
            in: text,
            selection: NSRange(location: text.count, length: 0),
            tabSize: 4,
            useSpaces: true
        )

        XCTAssertEqual(result?.replacementText, "let value = 1")
        XCTAssertEqual(result?.selectedRange, NSRange(location: text.count - 4, length: 0))
    }

    func testSmartIndentHandlerTabIndentsAllSelectedLines() {
        let text = "first\nsecond"

        let result = SmartIndentHandler.handleTab(
            in: text,
            selection: NSRange(location: 0, length: (text as NSString).length),
            tabSize: 4,
            useSpaces: true
        )

        XCTAssertEqual(result?.replacementText, "    first\n    second")
        XCTAssertEqual(
            result?.selectedRange,
            NSRange(location: 0, length: ("    first\n    second" as NSString).length)
        )
    }

    func testBracketPairsConfigHTMLDisablesAutoClosingPairs() {
        let config = BracketPairsConfig.defaultForLanguage("html")

        XCTAssertTrue(config.isOpenBracket("<"))
        XCTAssertTrue(config.isCloseBracket(">"))
        XCTAssertTrue(config.autoClosingPairs.isEmpty)
    }

    func testBracketPairsConfigUnknownLanguageFallsBackToDefaultPairs() {
        let config = BracketPairsConfig.defaultForLanguage("unknown-lang")

        XCTAssertTrue(config.isOpenBracket("("))
        XCTAssertEqual(config.matchingClose(for: "{"), "}")
        XCTAssertFalse(config.autoClosingPairs.isEmpty)
    }

    func testBracketMatcherFindsNestedOuterPair() {
        let config = BracketPairsConfig.defaultForLanguage("swift")

        let result = BracketMatcher.findMatchingBracket(
            in: "((a + b) * c)",
            at: 1,
            config: config
        )

        XCTAssertEqual(result?.openPosition, 0)
        XCTAssertEqual(result?.closePosition, 12)
    }

    func testBracketMatcherFindsPairWhenCursorIsAtEnd() {
        let config = BracketPairsConfig.defaultForLanguage("swift")

        let result = BracketMatcher.findMatchingBracket(
            in: "()",
            at: 2,
            config: config
        )

        XCTAssertEqual(result?.openPosition, 0)
        XCTAssertEqual(result?.closePosition, 1)
    }

    func testBracketMatcherAutoClosingEditSurroundsSelection() {
        let config = BracketPairsConfig.defaultForLanguage("swift")

        let result = BracketMatcher.autoClosingEdit(
            in: "value",
            selection: NSRange(location: 0, length: 5),
            typedChar: "(",
            config: config
        )

        XCTAssertEqual(result?.replacementText, "(value)")
        XCTAssertEqual(result?.selectedRange, NSRange(location: 7, length: 0))
    }

    func testBracketMatcherAutoClosingEditSkipsExistingCloseBracket() {
        let config = BracketPairsConfig.defaultForLanguage("swift")

        let result = BracketMatcher.autoClosingEdit(
            in: "()",
            selection: NSRange(location: 1, length: 0),
            typedChar: ")",
            config: config
        )

        XCTAssertEqual(result?.replacementText, "")
        XCTAssertEqual(result?.selectedRange, NSRange(location: 2, length: 0))
    }

    func testBracketMatcherDoesNotAutoCloseHTMLAngleBracket() {
        let config = BracketPairsConfig.defaultForLanguage("html")

        let result = BracketMatcher.autoClosingEdit(
            in: "",
            selection: NSRange(location: 0, length: 0),
            typedChar: "<",
            config: config
        )

        XCTAssertNil(result)
    }

    func testBracketMatcherPythonQuoteDoesNotAutoCloseInsideStringContext() {
        let config = BracketPairsConfig.defaultForLanguage("python")
        let text = "print(\"hel"

        let result = BracketMatcher.shouldAutoClose(
            in: text,
            at: (text as NSString).length,
            typedChar: "\"",
            config: config
        )

        XCTAssertNil(result)
    }

    func testBracketMatcherShouldAutoSurroundOnlyBracketCharacters() {
        let config = BracketPairsConfig.defaultForLanguage("swift")

        XCTAssertTrue(BracketMatcher.shouldAutoSurround(typedChar: "(", config: config))
        XCTAssertTrue(BracketMatcher.shouldAutoSurround(typedChar: "}", config: config))
        XCTAssertFalse(BracketMatcher.shouldAutoSurround(typedChar: "a", config: config))
    }

    func testEditorTextInputControllerAutoClosingPlanWrapsBracketInsertion() {
        let controller = EditorTextInputController()

        let plan = controller.textInputPlan(
            text: "(",
            replacementRange: NSRange(location: 5, length: 0),
            textViewSelections: [NSRange(location: 5, length: 0)],
            multiCursorSelectionCount: 1,
            currentText: "hello world",
            languageId: "swift"
        )

        XCTAssertEqual(plan?.replacementText, "()")
        XCTAssertEqual(plan?.selectedRanges, [NSRange(location: 6, length: 0)])
        XCTAssertEqual(plan?.reason, "bracket_auto_closing")
    }

    func testEditorTextInputControllerIgnoresNonBracketSingleCharacterInput() {
        let controller = EditorTextInputController()

        let plan = controller.textInputPlan(
            text: "a",
            replacementRange: NSRange(location: 0, length: 0),
            textViewSelections: [NSRange(location: 0, length: 0)],
            multiCursorSelectionCount: 1,
            currentText: "",
            languageId: "swift"
        )

        XCTAssertNil(plan)
    }

    func testEditorTextInputControllerMultiCursorAutoClosingProducesWholeDocumentPlan() {
        let controller = EditorTextInputController()

        let plan = controller.textInputPlan(
            text: "(",
            replacementRange: NSRange(location: NSNotFound, length: 0),
            textViewSelections: [
                NSRange(location: 0, length: 0),
                NSRange(location: 2, length: 0),
            ],
            multiCursorSelectionCount: 2,
            currentText: "xy",
            languageId: "swift"
        )

        XCTAssertEqual(plan?.replacementRange, NSRange(location: 0, length: 2))
        XCTAssertEqual(plan?.replacementText, "()xy()")
        XCTAssertEqual(
            plan?.selectedRanges,
            [NSRange(location: 1, length: 0), NSRange(location: 3, length: 0)]
        )
        XCTAssertEqual(plan?.reason, "multi_cursor_bracket_auto_closing")
    }

    func testEditorTextInputControllerInsertNewlinePlanBetweenBracesKeepsSmartIndent() {
        let controller = EditorTextInputController()

        let plan = controller.insertNewlinePlan(
            textViewSelections: [NSRange(location: 1, length: 0)],
            multiCursorSelectionCount: 1,
            currentText: "{}",
            tabSize: 4,
            useSpaces: true
        )

        XCTAssertEqual(plan?.replacementRange, NSRange(location: 1, length: 0))
        XCTAssertEqual(plan?.replacementText, "\n    \n")
        XCTAssertEqual(plan?.selectedRanges, [NSRange(location: 6, length: 0)])
        XCTAssertEqual(plan?.reason, "smart_indent_enter")
    }

    func testEditorTextInputControllerInsertNewlineReturnsNilForMultiCursor() {
        let controller = EditorTextInputController()

        let plan = controller.insertNewlinePlan(
            textViewSelections: [
                NSRange(location: 0, length: 0),
                NSRange(location: 1, length: 0),
            ],
            multiCursorSelectionCount: 2,
            currentText: "{}",
            tabSize: 4,
            useSpaces: true
        )

        XCTAssertNil(plan)
    }

    func testEditorTextInputControllerInsertTabWithoutSelectionUsesIndentUnit() {
        let controller = EditorTextInputController()

        let plan = controller.insertTabPlan(
            textViewSelections: [NSRange(location: 3, length: 0)],
            multiCursorSelectionCount: 1,
            currentText: "abc",
            tabSize: 4,
            useSpaces: false
        )

        XCTAssertEqual(plan?.replacementRange, NSRange(location: 3, length: 0))
        XCTAssertEqual(plan?.replacementText, "\t")
        XCTAssertEqual(plan?.selectedRanges, [NSRange(location: 4, length: 0)])
        XCTAssertEqual(plan?.reason, "smart_indent_enter")
    }

    func testEditorTextInputControllerInsertBacktabReturnsNilForMultiCursor() {
        let controller = EditorTextInputController()

        let plan = controller.insertBacktabPlan(
            textViewSelections: [NSRange(location: 0, length: 4)],
            multiCursorSelectionCount: 2,
            currentText: "    test",
            tabSize: 4,
            useSpaces: true
        )

        XCTAssertNil(plan)
    }
}
#endif
