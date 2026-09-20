import Foundation
import Testing
import LanguageServerProtocol
@testable import EditorKernel

// MARK: - BracketAndIndent additional coverage

struct BracketAndIndentCoverageTests {
    let config = BracketPairsConfig.defaultForLanguage("swift")

    @Test
    func findMatchingBracketAtOpenAndClosePositions() {
        let text = "fn(a, [b])"
        // cursor right after "(" at offset 2 -> offset 3
        let forward = BracketMatcher.findMatchingBracket(in: text, at: 3, config: config)
        #expect(forward?.openPosition == 2)
        #expect(forward?.closePosition == 9)

        // cursor on ")" (offset 9)
        let backward = BracketMatcher.findMatchingBracket(in: text, at: 9, config: config)
        #expect(backward?.openPosition == 2)
        #expect(backward?.closePosition == 9)

        // cursor on "[" (offset 6)
        let inner = BracketMatcher.findMatchingBracket(in: text, at: 6, config: config)
        #expect(inner?.openPosition == 6)
        #expect(inner?.closePosition == 8)

        // no bracket nearby / unbalanced outer bracket still finds inner pair
        #expect(BracketMatcher.findMatchingBracket(in: "plain text", at: 3, config: config) == nil)
        let unbalanced = BracketMatcher.findMatchingBracket(in: "((x)", at: 4, config: config)
        #expect(unbalanced?.openPosition == 1)
        #expect(unbalanced?.closePosition == 3)
    }

    @Test
    func findMatchingBracketRejectsInvalidCursor() {
        #expect(BracketMatcher.findMatchingBracket(in: "abc", at: -1, config: config) == nil)
        #expect(BracketMatcher.findMatchingBracket(in: "abc", at: 99, config: config) == nil)
    }

    @Test
    func shouldAutoCloseRespectsStringAndCommentContexts() {
        let python = BracketPairsConfig.defaultForLanguage("python")
        // Inside a string literal -> no auto-close for quotes
        #expect(BracketMatcher.shouldAutoClose(in: "x = \"abc", at: 7, typedChar: "\"", config: python) == nil)
        // Inside a comment -> notIn .comment not declared for python, so brackets still autoclose
        #expect(BracketMatcher.shouldAutoClose(in: "// note", at: 7, typedChar: "(", config: python) != nil)
        // Default language: quotes auto-close at top level
        #expect(BracketMatcher.shouldAutoClose(in: "x = ", at: 4, typedChar: "\"", config: config) == "\"")
        // Non auto-close char
        #expect(BracketMatcher.shouldAutoClose(in: "x", at: 1, typedChar: "a", config: config) == nil)
    }

    @Test
    func shouldAutoSurroundAndAutoClosingEdit() {
        #expect(BracketMatcher.shouldAutoSurround(typedChar: "(", config: config))
        #expect(BracketMatcher.shouldAutoSurround(typedChar: ")", config: config))
        #expect(!BracketMatcher.shouldAutoSurround(typedChar: "x", config: config))

        // Surround selection
        let surround = BracketMatcher.autoClosingEdit(
            in: "abc",
            selection: NSRange(location: 0, length: 3),
            typedChar: "(",
            config: config
        )
        #expect(surround?.replacementText == "(abc)")
        #expect(surround?.selectedRange == NSRange(location: 5, length: 0))

        // Typing closing bracket over an existing one skips over it
        let skip = BracketMatcher.autoClosingEdit(
            in: "()",
            selection: NSRange(location: 1, length: 0),
            typedChar: ")",
            config: config
        )
        #expect(skip?.replacementText == "")
        #expect(skip?.selectedRange == NSRange(location: 2, length: 0))

        // Plain auto-close pair insertion
        let insert = BracketMatcher.autoClosingEdit(
            in: "",
            selection: NSRange(location: 0, length: 0),
            typedChar: "{",
            config: config
        )
        #expect(insert?.replacementText == "{}")
        #expect(insert?.selectedRange == NSRange(location: 1, length: 0))

        // Invalid selection is rejected
        #expect(BracketMatcher.autoClosingEdit(
            in: "abc",
            selection: NSRange(location: NSNotFound, length: 0),
            typedChar: "(",
            config: config
        ) == nil)
        #expect(BracketMatcher.autoClosingEdit(
            in: "abc",
            selection: NSRange(location: 2, length: 5),
            typedChar: "(",
            config: config
        ) == nil)
    }

    @Test
    func smartIndentEnterProducesIndentedNewlines() {
        // { } pair -> newline + indent + newline (prev "{" next "\n" falls to indent-after-brace)
        let between = SmartIndentHandler.handleEnter(in: "  {\n}", at: 3, tabSize: 4, useSpaces: true)
        #expect(between.textToInsert == "\n  " + "    ")
        #expect(between.cursorOffset == 2 + 4 + 1)

        // after { only
        let afterBrace = SmartIndentHandler.handleEnter(in: "{", at: 1, tabSize: 2, useSpaces: true)
        #expect(afterBrace.textToInsert == "\n  ")

        // plain line keeps indentation
        let plain = SmartIndentHandler.handleEnter(in: "    hello", at: 9, tabSize: 4, useSpaces: true)
        #expect(plain.textToInsert == "\n    ")

        // CRLF document uses CRLF newlines
        let crlf = SmartIndentHandler.handleEnter(in: "{\r\n}", at: 1, tabSize: 4, useSpaces: true)
        #expect(crlf.textToInsert.hasPrefix("\r\n"))
    }

    @Test
    func smartIndentTabAndBacktabAdjustSelections() {
        // Tab on a selection indents affected lines
        let tab = SmartIndentHandler.handleTab(
            in: "a\nb",
            selection: NSRange(location: 0, length: 3),
            tabSize: 2,
            useSpaces: true
        )
        #expect(tab?.replacementText == "  a\n  b")
        #expect(tab?.selectedRange == NSRange(location: 0, length: 7))

        // Backtab removes one indent unit
        let backtab = SmartIndentHandler.handleBacktab(
            in: "  a\n  b",
            selection: NSRange(location: 0, length: 7),
            tabSize: 2,
            useSpaces: true
        )
        #expect(backtab?.replacementText == "a\nb")

        // Backtab on unindented lines returns nil
        #expect(SmartIndentHandler.handleBacktab(
            in: "a",
            selection: NSRange(location: 0, length: 1),
            tabSize: 2,
            useSpaces: true
        ) == nil)

        // Caret tab returns a unit
        let caretTab = SmartIndentHandler.handleTab(at: 0, hasSelection: false, selectionStart: 0, selectionEnd: 0, tabSize: 4, useSpaces: true)
        #expect(caretTab.textToInsert == "    ")
    }
}

// MARK: - CursorMotionController additional coverage

struct CursorMotionCoverageTests {
    @Test
    func verticalMotionUsesDesiredColumnAndClamps() {
        let text = "abc\nlonger line\nxy"
        // column derived from offset clamps to the 3-char line above
        #expect(CursorMotionController.moveUp(location: 14, text: text, desiredColumn: nil).location == 3)
        #expect(CursorMotionController.moveUp(location: 14, text: text, desiredColumn: 2).location == 2)
        // moving up from first line pins to 0
        #expect(CursorMotionController.moveUp(location: 2, text: text, desiredColumn: nil).location == 0)
        // moving down from last line pins to end of document
        #expect(CursorMotionController.moveDown(location: 16, text: text, desiredColumn: nil).location == 18)
        #expect(CursorMotionController.moveDown(location: 1, text: text, desiredColumn: nil).location == 5)
        #expect(CursorMotionController.moveDown(location: 1, text: text, desiredColumn: 2).location == 6)
    }

    @Test
    func lineEndHandlesCRLFAndPlainLines() {
        #expect(CursorMotionController.moveToEndOfLine(location: 0, text: "ab\r\ncd").location == 2)
        #expect(CursorMotionController.moveToEndOfLine(location: 4, text: "ab\ncd").location == 5)
        #expect(CursorMotionController.moveToEndOfLine(location: 0, text: "ab\n").location == 2)
    }

    @Test
    func smartHomeTogglesBetweenContentAndColumnZero() {
        let text = "    code"
        #expect(CursorMotionController.smartHome(location: 6, text: text).location == 0)
        #expect(CursorMotionController.smartHome(location: 4, text: text).location == 0)
        #expect(CursorMotionController.smartHome(location: 0, text: text).location == 4)
        // no indentation -> single home
        #expect(CursorMotionController.smartHome(location: 2, text: "code").location == 0)
    }

    @Test
    func paragraphMotionMovesBetweenBlocks() {
        let text = "a\nb\n\nc\nd"
        #expect(CursorMotionController.moveParagraphForward(location: 1, text: text).location == 4)
        #expect(CursorMotionController.moveParagraphBackward(location: 5, text: text).location == 4)
        #expect(CursorMotionController.moveParagraphForward(location: 5, text: text).location == 8)
        // from inside a block, backward lands on start of block/empty block start
        #expect(CursorMotionController.moveParagraphBackward(location: 1, text: text).location == 0)
        // empty current line behavior
        #expect(CursorMotionController.moveParagraphBackward(location: 3, text: text).location == 0)
        #expect(CursorMotionController.moveParagraphForward(location: 3, text: text).location == 4)
    }

    @Test
    func leftRightMotionClampBoundaries() {
        #expect(CursorMotionController.moveLeft(location: 0, text: "abc").location == 0)
        #expect(CursorMotionController.moveRight(location: 3, text: "abc").location == 3)
        #expect(CursorMotionController.moveRight(location: 99, text: "abc").location == 3)
    }
}

// MARK: - Minimap / LargeFileMode coverage

@MainActor
struct MinimapAndLargeFileCoverageTests {
    @Test
    func minimapPolicyTitlesAndDetails() {
        let visible = EditorMinimapPolicy(userRequestedVisible: true, largeFileMode: .normal)
        #expect(visible.isVisible)
        #expect(visible.statusTitle == "Minimap On")

        let off = EditorMinimapPolicy(userRequestedVisible: false, largeFileMode: .normal)
        #expect(!off.isVisible)
        #expect(off.statusTitle == "Minimap Off")
        #expect(off.detailText == "Minimap is turned off in editor settings.")

        let gatedLarge = EditorMinimapPolicy(userRequestedVisible: true, largeFileMode: .large)
        #expect(gatedLarge.isForcedHidden)
        #expect(gatedLarge.statusTitle == "Minimap Gated")
        #expect(gatedLarge.detailText.contains("large file mode"))

        let gatedMega = EditorMinimapPolicy(userRequestedVisible: true, largeFileMode: .mega)
        #expect(gatedMega.detailText.contains("mega file mode"))
    }

    @Test
    func largeFileModeThresholdsAndFlags() {
        #expect(LargeFileMode.mode(for: 0) == .normal)
        #expect(LargeFileMode.mode(for: LargeFileMode.mediumThreshold) == .medium)
        #expect(LargeFileMode.mode(for: LargeFileMode.largeThreshold) == .large)
        #expect(LargeFileMode.mode(for: LargeFileMode.megaThreshold) == .mega)

        #expect(LargeFileMode.mega.isReadOnly)
        #expect(!LargeFileMode.large.isReadOnly)
        #expect(LargeFileMode.normal.maxSyntaxHighlightLines == .max)
        #expect(LargeFileMode.mega.maxSyntaxHighlightLines == 1_000)
        #expect(!LargeFileMode.medium.isMinimapDisabled)
        #expect(LargeFileMode.medium.isSemanticTokensDisabled)
        #expect(!LargeFileMode.medium.isInlayHintsDisabled)
    }

    @Test
    func longLineDetectorFindsOnlyLinesOverLimit() {
        #expect(LongLineDetector.findLongestLine(in: "short\nshort") == nil)
        let long = String(repeating: "a", count: 12_000)
        let found = LongLineDetector.findLongestLine(in: "x\n\(long)")
        #expect(found?.line == 1)
        #expect(found?.length == 12_000)
        // early exit respects custom limit
        let mid = String(repeating: "b", count: 50)
        #expect(LongLineDetector.findLongestLine(in: mid, limit: 10)?.length == 50)
    }

    @Test
    func viewportRenderControllerClampsRenderRange() {
        let controller = ViewportRenderController()
        controller.updateVisibleRange(startLine: 10, endLine: 20, totalLines: 30)
        #expect(controller.renderStartLine == 0) // 10 - 50 clamped
        #expect(controller.renderEndLine == 30) // 20 + 50 clamped
        #expect(controller.isLineVisible(0))
        #expect(!controller.isLineVisible(30))
        #expect(controller.shouldDebounceUpdate(from: 12, previousEndLine: 22))
        #expect(!controller.shouldDebounceUpdate(from: 30, previousEndLine: 22))
    }
}

// MARK: - EditorTextInputController coverage

@MainActor
struct TextInputControllerCoverageTests {
    let controller = EditorTextInputController()

    @Test
    func textInputPlanProducesBracketAutoClosing() {
        let plan = controller.textInputPlan(
            text: "(",
            replacementRange: NSRange(location: 0, length: 0),
            textViewSelections: [NSRange(location: 0, length: 0)],
            multiCursorSelectionCount: 1,
            currentText: "",
            languageId: "swift"
        )
        #expect(plan?.replacementText == "()")
        #expect(plan?.reason == "bracket_auto_closing")
    }

    @Test
    func textInputPlanFallsThroughForPlainCharacters() {
        let plan = controller.textInputPlan(
            text: "x",
            replacementRange: NSRange(location: 0, length: 0),
            textViewSelections: [NSRange(location: 0, length: 0)],
            multiCursorSelectionCount: 1,
            currentText: "",
            languageId: "swift"
        )
        #expect(plan == nil)
    }

    @Test
    func textInputPlanMultiCursorAutoClosing() {
        let plan = controller.textInputPlan(
            text: "(",
            replacementRange: NSRange(location: NSNotFound, length: 0),
            textViewSelections: [
                NSRange(location: 1, length: 0),
                NSRange(location: 4, length: 0),
            ],
            multiCursorSelectionCount: 2,
            currentText: "a b c",
            languageId: "swift"
        )
        #expect(plan?.replacementText == "a() b ()c")
        #expect(plan?.selectedRanges == [
            NSRange(location: 2, length: 0),
            NSRange(location: 5, length: 0),
        ])
        #expect(plan?.reason == "multi_cursor_bracket_auto_closing")
    }

    @Test
    func newlineAndTabPlansUseSmartIndent() {
        let newlinePlan = controller.insertNewlinePlan(
            textViewSelections: [NSRange(location: 1, length: 0)],
            multiCursorSelectionCount: 1,
            currentText: "{",
            tabSize: 2,
            useSpaces: true
        )
        #expect(newlinePlan?.replacementText == "\n  ")
        #expect(newlinePlan?.reason == "smart_indent_enter")

        let tabPlan = controller.insertTabPlan(
            textViewSelections: [NSRange(location: 0, length: 0)],
            multiCursorSelectionCount: 1,
            currentText: "ab",
            tabSize: 2,
            useSpaces: true
        )
        #expect(tabPlan?.replacementText == "  ")

        let backtabPlan = controller.insertBacktabPlan(
            textViewSelections: [NSRange(location: 0, length: 3)],
            multiCursorSelectionCount: 1,
            currentText: "  ab",
            tabSize: 2,
            useSpaces: true
        )
        #expect(backtabPlan?.replacementText == "ab")
        #expect(backtabPlan?.reason == "smart_outdent")

        // Multi-cursor requests bail out of single-cursor plans
        #expect(controller.insertNewlinePlan(
            textViewSelections: [NSRange(location: 0, length: 0)],
            multiCursorSelectionCount: 2,
            currentText: "a",
            tabSize: 2,
            useSpaces: true
        ) == nil)
        // No resolvable selection
        #expect(controller.insertTabPlan(
            textViewSelections: [],
            multiCursorSelectionCount: 1,
            currentText: "a",
            tabSize: 2,
            useSpaces: true
        ) == nil)
    }
}

// MARK: - EditorFindController coverage

@MainActor
struct FindControllerCoverageTests {
    let controller = EditorFindController()

    @Test
    func stateTransitionsTogglePanelAndQueries() {
        let base = EditorFindReplaceState()
        let opened = controller.stateForOpeningPanel(base)
        #expect(opened.isFindPanelVisible)

        let closed = controller.stateForClosingPanel(opened)
        #expect(!closed.isFindPanelVisible)

        let findUpdated = controller.stateForUpdatingFindQuery(closed, text: "abc")
        #expect(findUpdated.findText == "abc")
        #expect(findUpdated.isFindPanelVisible)

        let replaceUpdated = controller.stateForUpdatingReplaceQuery(findUpdated, text: "xyz")
        #expect(replaceUpdated.replaceText == "xyz")

        let optionsUpdated = controller.stateForUpdatingOptions(replaceUpdated) { $0.isCaseSensitive = true }
        #expect(optionsUpdated.options.isCaseSensitive)
    }

    @Test
    func matchesResultAndIndexNavigation() {
        var state = EditorFindReplaceState()
        state.findText = "l"
        let result = controller.matchesResult(
            state: state,
            text: "hello world",
            selections: [EditorSelection(range: EditorRange(location: 0, length: 0))]
        )
        #expect(result.matches.count == 3)
        #expect(result.selectedMatchIndex == 0)

        let next = controller.nextMatchIndex(matches: result.matches, selectedMatchIndex: 0)
        #expect(next == 1)
        let wrap = controller.nextMatchIndex(matches: result.matches, selectedMatchIndex: 2)
        #expect(wrap == 0)
        let previous = controller.previousMatchIndex(matches: result.matches, selectedMatchIndex: 1)
        #expect(previous == 0)
        let wrapBack = controller.previousMatchIndex(matches: result.matches, selectedMatchIndex: 0)
        #expect(wrapBack == 2)
        #expect(controller.nextMatchIndex(matches: [], selectedMatchIndex: nil) == nil)

        var applied = state
        controller.applyMatchesResult(result, to: &applied)
        #expect(applied.resultCount == 3)
        controller.applySelectedMatch(index: 1, match: result.matches[1], to: &applied)
        #expect(applied.selectedMatchIndex == 1)
        #expect(applied.selectedMatchRange == result.matches[1].range)
    }

    @Test
    func replaceTransactionsUseSelectedMatchAndReplaceAll() {
        var state = EditorFindReplaceState()
        state.findText = "foo"
        state.replaceText = "bar"
        state.selectedMatchIndex = 1
        let matches = [
            EditorFindMatch(range: EditorRange(location: 0, length: 3), matchedText: "foo"),
            EditorFindMatch(range: EditorRange(location: 4, length: 3), matchedText: "foo"),
        ]
        let current = controller.replaceCurrentTransaction(state: state, matches: matches)
        #expect(current?.replacements.first?.range.location == 4)

        let all = controller.replaceAllTransaction(state: state, matches: matches)
        #expect(all?.replacements.count == 2)
        #expect(controller.replaceAllTransaction(state: state, matches: []) == nil)
        #expect(controller.replaceCurrentTransaction(state: state, matches: []) == nil)
    }
}

// MARK: - EditorMultiCursorController coverage

@MainActor
struct MultiCursorControllerCoverageTests {
    let controller = EditorMultiCursorController()

    @Test
    func stateAndRangeHelpers() {
        let state = MultiCursorState(
            primary: MultiCursorSelection(location: 5, length: 0),
            secondary: [MultiCursorSelection(location: 1, length: 0)]
        )
        let cleared = controller.clearSecondary(from: state)
        #expect(!cleared.isEnabled)
        #expect(cleared.primary.location == 5)

        let replaced = controller.replacingPrimary(in: state, with: MultiCursorSelection(location: 9, length: 0))
        #expect(replaced.primary.location == 9)
        #expect(replaced.secondary.count == 1)

        let fromSelections = controller.state(from: [
            MultiCursorSelection(location: 3, length: 0),
            MultiCursorSelection(location: 1, length: 0),
        ])
        #expect(fromSelections.all.map(\.location) == [1, 3])

        #expect(controller.nsRanges(from: state) == [
            NSRange(location: 1, length: 0),
            NSRange(location: 5, length: 0),
        ])
        #expect(controller.nsRanges(from: fromSelections).count == 2)
        #expect(controller.clearSession() == nil)
    }

    @Test
    func occurrenceSearchAndSessionFlow() {
        let text = "foo bar foo" as NSString
        let context = controller.allOccurrencesContext(
            from: NSRange(location: 0, length: 3),
            in: text
        )
        #expect(context?.query == "foo")

        let allMatches = controller.ranges(of: "foo", in: text)
        #expect(allMatches.count == 2)

        let session = controller.allOccurrencesSession(for: context!, matches: allMatches)
        #expect(session.history.count == 2)

        let state = controller.state(from: allMatches)
        let next = controller.nextSelection(in: allMatches, currentState: state, session: session)
        #expect(next == nil)

        var updated = controller.appending(MultiCursorSelection(location: 8, length: 0), to: session)
        updated = controller.appending(MultiCursorSelection(location: 2, length: 0), to: updated)
        #expect(updated.history.count == 4)
        #expect(controller.removingLast(from: updated)?.history.count == 3)

        let collapsed = controller.collapsedSession(
            from: session,
            singleSelection: MultiCursorSelection(location: 0, length: 3),
            in: text
        )
        #expect(collapsed?.history.count == 1)

        let started = controller.startedSession(for: context!)
        #expect(started.history == [context!.baseSelection])
    }

    @Test
    func resolvedContextReusesMatchingSession() {
        let text = "abc def abc" as NSString
        let session = EditorMultiCursorSearchSession(
            query: "abc",
            baseSelection: MultiCursorSelection(location: 0, length: 3),
            history: [MultiCursorSelection(location: 0, length: 3)]
        )
        let reused = controller.resolvedContext(
            from: NSRange(location: 8, length: 3),
            in: text,
            existingSession: session
        )
        #expect(reused?.shouldStartSession == false)
        #expect(reused?.context.query == "abc")

        let fresh = controller.resolvedContext(
            from: NSRange(location: 4, length: 3),
            in: text,
            existingSession: nil
        )
        #expect(fresh?.shouldStartSession == true)
        #expect(fresh?.context.query == "def")
    }

    @Test
    func replacementAndOperationResultsBuildTransactions() {
        let (result, transaction) = controller.replacementResult(
            text: "aa bb",
            selections: [
                MultiCursorSelection(location: 0, length: 2),
                MultiCursorSelection(location: 3, length: 2),
            ],
            replacement: "x"
        )
        #expect(result.text == "x x")
        #expect(result.selections.map(\.location) == [1, 3])
        #expect(transaction.replacements.count == 2)

        let (indentResult, indentTransaction) = controller.operationResult(
            text: "a\nb",
            selections: [
                MultiCursorSelection(location: 0, length: 0),
                MultiCursorSelection(location: 2, length: 0),
            ],
            operation: .indent("  ")
        )
        #expect(indentResult.text == "  a\n  b")
        #expect(indentTransaction.replacements.count == 1)
        #expect(indentTransaction.replacements.first?.range.length == 3)
    }
}

// MARK: - EditorTransactionController coverage

@MainActor
struct TransactionControllerCoverageTests {
    let controller = EditorTransactionController()

    private func makeTextEdit(line: Int, character: Int, length: Int, newText: String) -> TextEdit {
        TextEdit(
            range: LSPRange(
                start: Position(line: line, character: character),
                end: Position(line: line, character: character + length)
            ),
            newText: newText
        )
    }

    @Test
    func textEditTransactionRemapsCurrentSelections() {
        let transaction = controller.transactionForTextEdits(
            [makeTextEdit(line: 0, character: 0, length: 0, newText: "inserted ")],
            in: "world",
            currentSelections: [NSRange(location: 3, length: 2)]
        )
        #expect(transaction?.updatedSelections?.first?.range.location == 12)
        #expect(transaction?.updatedSelections?.first?.range.length == 2)
    }

    @Test
    func inputEditTransactionValidatesRanges() {
        let valid = controller.transactionForInputEdit(
            replacementRange: NSRange(location: 0, length: 1),
            replacementText: "x",
            selectedRanges: [NSRange(location: 1, length: 0)]
        )
        #expect(valid?.replacements.count == 1)

        #expect(controller.transactionForInputEdit(
            replacementRange: NSRange(location: NSNotFound, length: 0),
            replacementText: "x",
            selectedRanges: []
        ) == nil)
        #expect(controller.transactionForInputEdit(
            replacementRange: NSRange(location: 0, length: 0),
            replacementText: "x",
            selectedRanges: [NSRange(location: -1, length: 0)]
        ) == nil)
    }

    @Test
    func completionEditCombinesAdditionalEditsAndPositionsCursor() {
        let completion = controller.transactionForCompletionEdit(
            text: "hello world",
            replacementRange: NSRange(location: 0, length: 5),
            replacementText: "greetings",
            additionalTextEdits: [makeTextEdit(line: 0, character: 11, length: 0, newText: "!")]
        )
        #expect(completion?.replacements.count == 2)
        // cursor after inserted completion text, remapped past the additional insert
        #expect(completion?.updatedSelections?.first?.range.location == 9)

        #expect(controller.transactionForCompletionEdit(
            text: "abc",
            replacementRange: NSRange(location: 0, length: 99),
            replacementText: "x",
            additionalTextEdits: nil
        ) == nil)
    }

    @Test
    func snippetEditBuildsSessionWithRemappedPlaceholderRanges() {
        let parsed = EditorSnippetParser.parse("func ${1:name}(${2}) {}")
        let payload = controller.transactionForSnippetEdit(
            text: "",
            replacementRange: NSRange(location: 0, length: 0),
            snippet: parsed,
            additionalTextEdits: nil
        )
        #expect(payload != nil)
        let session = payload?.session
        #expect(session?.groups.count == 2)
        #expect(session?.groups.first?.ranges.first?.location == 5)
        #expect(session?.exitSelection.location == parsed.exitSelection.location)

        // selections point at first placeholder occurrences
        let transaction = payload?.transaction
        #expect(transaction?.updatedSelections?.first?.range.location == 5)

        // invalid replacement range rejected
        #expect(controller.transactionForSnippetEdit(
            text: "abc",
            replacementRange: NSRange(location: 2, length: 5),
            snippet: parsed,
            additionalTextEdits: nil
        ) == nil)
    }

    @Test
    func commitPayloadCountsLinesAndMapsSelections() {
        let payload = controller.commitPayload(
            from: EditorEditResult(
                snapshot: EditorSnapshot(text: "a\nb\nc", version: 3),
                selections: [EditorSelection(range: EditorRange(location: 1, length: 2))]
            )
        )
        #expect(payload.totalLines == 3)
        #expect(payload.version == 3)
        #expect(payload.canonicalSelectionSet?.count == 1)
        #expect(payload.multiCursorSelections?.first?.length == 2)
    }
}

// MARK: - EditorSaveWorkflowController coverage

@MainActor
struct SaveWorkflowControllerCoverageTests {
    let controller = EditorSaveWorkflowController()

    @Test
    func saveNowIfNeededRunsOnlyWhenDirty() {
        var ran = false
        controller.saveNowIfNeeded(hasUnsavedChanges: false, reason: "focus", fileName: nil, verbose: false, log: { _ in }, runSave: { ran = true })
        #expect(!ran)
        controller.saveNowIfNeeded(hasUnsavedChanges: true, reason: "focus", fileName: "a.swift", verbose: true, log: { _ in }, runSave: { ran = true })
        #expect(ran)
    }

    @Test
    func saveNowSkipsWhileSaving() {
        var ran = false
        controller.saveNow(saveState: .saving) { ran = true }
        #expect(!ran)
        controller.saveNow(saveState: .editing) { ran = true }
        #expect(ran)
    }

    @Test
    func prepareAndSaveNowWithoutContentOrURLDoesNothing() async {
        let saveController = EditorSaveController()
        await controller.prepareAndSaveNow(
            currentContent: nil,
            fileURL: nil,
            saveController: saveController,
            options: .default,
            tabSize: 4,
            insertSpaces: true,
            currentFileURL: { nil },
            prepareFormatting: { _, _, _ in nil },
            applyPreparedSaveText: { _ in },
            currentText: { nil },
            diagnostics: { [] },
            requestCodeActions: { _, _, _ in [] },
            resolveCodeAction: { action in action },
            isCodeActionResolveSupported: false,
            applyWorkspaceEdit: { _ in },
            performSave: { _, _ in }
        )
        // reaching here without crashing is the assertion
    }
}

// MARK: - EditorLanguageActionFacade coverage

@MainActor
struct LanguageActionFacadeCoverageTests {
    let facade = EditorLanguageActionFacade()

    private final class PromptProvider: EditorRenamePrompting, EditorLSPActionProviding {
        var cancelled = false
        func promptForNewName() -> String? { cancelled ? nil : "newName" }
        func cancelledMessage() -> String { "cancelled" }
        func inProgressMessage() -> String { "in progress" }
        func failedMessage() -> String { "failed" }
        func notAppliedMessage() -> String { "not applied" }
        func completedMessage(changedFiles: Int) -> String { "done \(changedFiles)" }

        func referenceResults(
            from locations: [Location],
            currentFileURL: URL,
            relativeFilePath: String,
            projectRootPath: String?,
            previewLine: (URL, Int) -> String?
        ) -> [ReferenceResult] { [] }

        func jumpKindStatusMessage(_ kind: EditorLSPActionJumpKind) -> String { "jumping" }
    }

    @Test
    func jumpShowsStatusAndPerforms() async {
        let provider = PromptProvider()
        var performedRange: NSRange?
        var statuses: [String] = []
        await facade.jump(
            selection: NSRange(location: 4, length: 0),
            kind: .definition,
            lspActionProvider: provider,
            showStatus: { message, _, _ in statuses.append(message) },
            perform: { range in performedRange = range }
        )
        #expect(performedRange?.location == 4)
        #expect(statuses.count == 1)

        // invalid selection bails out
        await facade.jump(
            selection: NSRange(location: NSNotFound, length: 0),
            kind: .declaration,
            lspActionProvider: provider,
            showStatus: { message, _, _ in statuses.append(message) },
            perform: { _ in performedRange = NSRange(location: -1, length: 0) }
        )
        #expect(statuses.count == 1)
    }

    @Test
    func promptRenameHonorsCancelledPromptAndEditability() async {
        let provider = PromptProvider()
        var ran = false
        var statuses: [String] = []
        facade.promptRenameSymbol(
            canPreview: false,
            isEditable: true,
            renamePrompting: provider,
            showStatus: { message, _, _ in statuses.append(message) },
            runRename: { _ in ran = true }
        )
        #expect(!ran)
        #expect(statuses.isEmpty)

        provider.cancelled = true
        facade.promptRenameSymbol(
            canPreview: true,
            isEditable: true,
            renamePrompting: provider,
            showStatus: { message, _, _ in statuses.append(message) },
            runRename: { _ in ran = true }
        )
        #expect(!ran)
        #expect(statuses == ["cancelled"])

        provider.cancelled = false
        facade.promptRenameSymbol(
            canPreview: true,
            isEditable: true,
            renamePrompting: provider,
            showStatus: { message, _, _ in statuses.append(message) },
            runRename: { _ in ran = true }
        )
        #expect(ran)
        #expect(statuses.last == "in progress")
    }

    @Test
    func renameReportsFailureWhenServerReturnsNothing() async {
        let provider = PromptProvider()
        var statuses: [String] = []
        await facade.rename(
            newName: "x",
            currentURI: "file:///tmp/a.swift",
            currentPosition: { (line: 0, character: 0) },
            requestRename: { _, _, _ in nil },
            workspaceEditController: EditorWorkspaceEditController(),
            renamePrompting: provider,
            applyCurrentDocumentEdits: { _, _ in },
            applyExternalFileEdits: { _, _ in false },
            showStatus: { message, _, _ in statuses.append(message) }
        )
        #expect(statuses == ["failed"])

        // nil URI returns immediately
        statuses.removeAll()
        await facade.rename(
            newName: "x",
            currentURI: nil,
            currentPosition: { (line: 0, character: 0) },
            requestRename: { _, _, _ in nil },
            workspaceEditController: EditorWorkspaceEditController(),
            renamePrompting: provider,
            applyCurrentDocumentEdits: { _, _ in },
            applyExternalFileEdits: { _, _ in false },
            showStatus: { message, _, _ in statuses.append(message) }
        )
        #expect(statuses.isEmpty)
    }
}
