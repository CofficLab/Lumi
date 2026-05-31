#if canImport(XCTest)
import EditorKernel
import Foundation
import LanguageServerProtocol
import XCTest
@testable import EditorService

@MainActor
final class EditorKernelPureLogicTests: XCTestCase {

    func testEditorMinimapPolicyVisibleStateUsesUserPreference() {
        let policy = EditorMinimapPolicy(userRequestedVisible: true, largeFileMode: .normal)

        XCTAssertFalse(policy.isForcedHidden)
        XCTAssertTrue(policy.isVisible)
        XCTAssertEqual(policy.statusTitle, "Minimap On")
        XCTAssertEqual(policy.detailText, "Minimap is visible for the current editor.")
    }

    func testEditorMinimapPolicyLargeFileStateIsGated() {
        let policy = EditorMinimapPolicy(userRequestedVisible: true, largeFileMode: .large)

        XCTAssertTrue(policy.isForcedHidden)
        XCTAssertFalse(policy.isVisible)
        XCTAssertEqual(policy.statusTitle, "Minimap Gated")
        XCTAssertEqual(
            policy.detailText,
            "Minimap hidden in large file mode to keep viewport rendering responsive."
        )
    }

    func testEditorPeekModeTitlesRemainStable() {
        XCTAssertEqual(EditorPeekMode.definition.title, "Peek Definition")
        XCTAssertEqual(EditorPeekMode.references.title, "Peek References")
    }

    func testEditorFileStateRelativeFilePathRejectsSiblingProjectWithSharedPrefix() {
        let state = EditorFileState()
        state.currentFileURL = URL(fileURLWithPath: "/tmp/Lumi2/Sources/App/Main.swift")

        XCTAssertEqual(state.relativeFilePath(projectRootPath: "/tmp/Lumi"), "Main.swift")
    }

    func testEditorFileStateRelativeFilePathTrimsCopiedProjectRootPath() {
        let state = EditorFileState()
        state.currentFileURL = URL(fileURLWithPath: "/tmp/Lumi/Sources/App/Main.swift")

        XCTAssertEqual(
            state.relativeFilePath(projectRootPath: " \n/tmp/Lumi/\t"),
            "Sources/App/Main.swift"
        )
    }

    func testEditorPeekControllerBuildsDefinitionPresentationFromCurrentBuffer() throws {
        let fileURL = URL(fileURLWithPath: "/tmp/EditorKernelPureLogicTests.swift")
        let location = Location(
            uri: fileURL.absoluteString,
            range: LSPRange(
                start: Position(line: 1, character: 4),
                end: Position(line: 1, character: 7)
            )
        )
        let controller = EditorPeekController()

        let presentation = controller.buildDefinitionPresentation(
            location: location,
            currentFileURL: fileURL,
            projectRootPath: "/tmp",
            currentContent: "struct Demo {\n    value\n}\n"
        )

        XCTAssertEqual(presentation?.mode, .definition)
        XCTAssertEqual(presentation?.summary, "EditorKernelPureLogicTests.swift:2:5")
        XCTAssertEqual(presentation?.items.count, 1)
        XCTAssertEqual(presentation?.items.first?.title, "EditorKernelPureLogicTests.swift")
        XCTAssertEqual(presentation?.items.first?.subtitle, "EditorKernelPureLogicTests.swift:2:5")
        XCTAssertEqual(presentation?.items.first?.preview, "value")
        XCTAssertEqual(presentation?.items.first?.badgeText, "Definition")

        guard let target = presentation?.items.first?.target else {
            return XCTFail("Expected peek target")
        }
        XCTAssertEqual(target.url, fileURL)
        XCTAssertEqual(target.line, 2)
        XCTAssertEqual(target.column, 5)
        XCTAssertTrue(target.highlightLine)
    }

    func testEditorPeekControllerReferencesFallBackWhenNoFileCanBeResolved() {
        let location = Location(
            uri: "not-a-file-uri",
            range: LSPRange(
                start: Position(line: 0, character: 0),
                end: Position(line: 0, character: 0)
            )
        )
        let controller = EditorPeekController()

        let presentation = controller.buildReferencesPresentation(
            locations: [location],
            currentFileURL: nil,
            relativeFilePath: "Sources/Fallback.swift",
            projectRootPath: nil,
            currentContent: nil
        )

        XCTAssertEqual(presentation.mode, .references)
        XCTAssertEqual(presentation.summary, "Sources/Fallback.swift")
        XCTAssertTrue(presentation.items.isEmpty)
    }

    func testTextEditApplierAppliesMultipleEditsFromBackToFront() {
        let edits = [
            TextEdit(
                range: LSPRange(
                    start: Position(line: 1, character: 0),
                    end: Position(line: 1, character: 5)
                ),
                newText: "earth"
            ),
            TextEdit(
                range: LSPRange(
                    start: Position(line: 0, character: 0),
                    end: Position(line: 0, character: 5)
                ),
                newText: "hello"
            ),
        ]

        let result = TextEditApplier.apply(edits: edits, to: "world\nworld")

        XCTAssertEqual(result, "hello\nearth")
    }

    func testTextEditApplierReturnsNilWhenEditRangeIsInvalid() {
        let edits = [
            TextEdit(
                range: LSPRange(
                    start: Position(line: 3, character: 0),
                    end: Position(line: 3, character: 1)
                ),
                newText: "x"
            )
        ]

        XCTAssertNil(TextEditApplier.apply(edits: edits, to: "line"))
    }

    func testTextEditTransactionBuilderMapsUnicodeLSPPositionsToEditorRanges() {
        let edits = [
            TextEdit(
                range: LSPRange(
                    start: Position(line: 0, character: 2),
                    end: Position(line: 0, character: 3)
                ),
                newText: "b"
            ),
            TextEdit(
                range: LSPRange(
                    start: Position(line: 1, character: 0),
                    end: Position(line: 1, character: 1)
                ),
                newText: "c"
            ),
        ]

        let transaction = TextEditTransactionBuilder.makeTransaction(edits: edits, in: "😀a\nz")

        XCTAssertEqual(
            transaction?.replacements,
            [
                .init(range: EditorRange(location: 2, length: 1), text: "b"),
                .init(range: EditorRange(location: 4, length: 1), text: "c"),
            ]
        )
    }

    func testTextEditTransactionBuilderRejectsOutOfBoundsLines() {
        let edits = [
            TextEdit(
                range: LSPRange(
                    start: Position(line: 9, character: 0),
                    end: Position(line: 9, character: 1)
                ),
                newText: "x"
            )
        ]

        XCTAssertNil(TextEditTransactionBuilder.makeTransaction(edits: edits, in: "abc"))
    }

    func testTextViewBridgeRejectsOverflowingNativeRanges() {
        let bridge = TextViewBridge()

        XCTAssertNil(bridge.lspRange(from: NSRange(location: Int.max, length: 1), in: "abc"))
        XCTAssertNil(bridge.lspRange(from: NSRange(location: 1, length: Int.max), in: "abc"))
    }

    func testTextViewBridgeLastCharacterKeepsComposedCharactersIntact() {
        XCTAssertEqual(TextViewBridge.lastCharacter(before: 1, in: "a"), "a")
        XCTAssertEqual(TextViewBridge.lastCharacter(before: 2, in: "😀"), "😀")
        XCTAssertEqual(TextViewBridge.lastCharacter(before: 2, in: "e\u{301}"), "e\u{301}")
    }

    func testTextViewBridgeLastCharacterRejectsInvalidLocations() {
        XCTAssertNil(TextViewBridge.lastCharacter(before: NSNotFound, in: "abc"))
        XCTAssertNil(TextViewBridge.lastCharacter(before: 0, in: "abc"))
        XCTAssertNil(TextViewBridge.lastCharacter(before: -1, in: "abc"))
        XCTAssertNil(TextViewBridge.lastCharacter(before: 4, in: "abc"))
    }

    func testEditorViewStateControllerIgnoresOverflowingSelectionEnds() {
        let state = EditorViewStateController.positions(
            from: [MultiCursorSelection(location: 1, length: Int.max)],
            text: "abc",
            positionResolver: { offset, _ in
                offset == 1 ? Position(line: 0, character: 1) : nil
            }
        )

        XCTAssertEqual(state.primaryCursorLine, 1)
        XCTAssertEqual(state.primaryCursorColumn, 2)
        XCTAssertEqual(state.cursorPositions.first?.end, nil)
    }

    func testEditorViewStateControllerDoesNotOverflowFallbackSelectionEnd() {
        let state = EditorViewStateController.positions(
            from: [MultiCursorSelection(location: Int.max, length: Int.max)],
            text: "abc",
            fallbackLine: 4,
            fallbackColumn: Int.max,
            positionResolver: { _, _ in nil }
        )

        XCTAssertEqual(state.primaryCursorLine, 4)
        XCTAssertEqual(state.primaryCursorColumn, Int.max)
        XCTAssertEqual(state.cursorPositions.first?.end, nil)
    }

    func testEditorOverlayControllerRejectsInvalidSelectionEndOffsets() {
        XCTAssertEqual(
            EditorOverlayController.inclusiveEndOffset(for: EditorRange(location: 3, length: 4)),
            6
        )
        XCTAssertNil(EditorOverlayController.inclusiveEndOffset(for: EditorRange(location: 3, length: 0)))
        XCTAssertNil(EditorOverlayController.inclusiveEndOffset(for: EditorRange(location: -1, length: 4)))
        XCTAssertNil(EditorOverlayController.inclusiveEndOffset(for: EditorRange(location: 3, length: -1)))
        XCTAssertNil(EditorOverlayController.inclusiveEndOffset(for: EditorRange(location: Int.max, length: 1)))
        XCTAssertNil(EditorOverlayController.inclusiveEndOffset(for: EditorRange(location: 1, length: Int.max)))
    }

    func testFindReplaceTransactionBuilderReplaceCurrentPreservesUppercaseMatch() {
        let state = EditorFindReplaceState(
            replaceText: "hello",
            options: EditorFindReplaceOptions(preservesCase: true),
            selectedMatchIndex: 0
        )
        let matches = [
            EditorFindMatch(range: EditorRange(location: 4, length: 5), matchedText: "WORLD")
        ]

        let transaction = EditorFindReplaceTransactionBuilder.replaceCurrent(
            state: state,
            matches: matches
        )

        XCTAssertEqual(
            transaction,
            EditorTransaction(
                replacements: [.init(range: EditorRange(location: 4, length: 5), text: "HELLO")],
                updatedSelections: [.init(range: EditorRange(location: 4, length: 5))]
            )
        )
    }

    func testFindReplaceTransactionBuilderReplaceAllPreservesTitleCaseAndClearsSelections() {
        let state = EditorFindReplaceState(
            replaceText: "planet",
            options: EditorFindReplaceOptions(preservesCase: true)
        )
        let matches = [
            EditorFindMatch(range: EditorRange(location: 0, length: 5), matchedText: "World"),
            EditorFindMatch(range: EditorRange(location: 8, length: 5), matchedText: "world"),
        ]

        let transaction = EditorFindReplaceTransactionBuilder.replaceAll(
            state: state,
            matches: matches
        )

        XCTAssertEqual(
            transaction,
            EditorTransaction(
                replacements: [
                    .init(range: EditorRange(location: 0, length: 5), text: "Planet"),
                    .init(range: EditorRange(location: 8, length: 5), text: "planet"),
                ],
                updatedSelections: nil
            )
        )
    }

    func testFindReplaceTransactionBuilderReturnsNilWhenNoSelectedMatchExists() {
        let state = EditorFindReplaceState(
            replaceText: "value",
            selectedMatchIndex: 2
        )
        let matches = [
            EditorFindMatch(range: EditorRange(location: 0, length: 3), matchedText: "old")
        ]

        XCTAssertNil(EditorFindReplaceTransactionBuilder.replaceCurrent(state: state, matches: matches))
    }

    func testFindReplaceTransactionBuilderPreviewReturnsReplacementWithoutCasePreservation() {
        let state = EditorFindReplaceState(
            replaceText: "planet",
            options: EditorFindReplaceOptions(preservesCase: false)
        )
        let match = EditorFindMatch(range: EditorRange(location: 0, length: 5), matchedText: "WORLD")

        let preview = EditorFindReplaceTransactionBuilder.previewReplacementText(for: match, state: state)

        XCTAssertEqual(preview, "planet")
    }

    func testEditorConfigContextNormalizesWorkspacePathAndLanguage() {
        let context = EditorConfigContext(
            workspacePath: " /tmp/demo/../demo/project ",
            languageId: " Swift "
        )

        XCTAssertEqual(context.normalizedWorkspacePath, "/tmp/demo/project")
        XCTAssertEqual(context.normalizedLanguageId, "swift")
    }

    func testEditorConfigOverrideScopeUsesNormalizedKeys() {
        XCTAssertEqual(
            EditorConfigOverrideScope.workspace("/tmp/demo/../demo/project").normalizedKey,
            "/tmp/demo/project"
        )
        XCTAssertEqual(
            EditorConfigOverrideScope.language(" TypeScript ").normalizedKey,
            "typescript"
        )
    }

    func testEditorScopedOverrideSnapshotAppliesOnlyProvidedFields() {
        let base = EditorConfigSnapshot(
            fontSize: 13,
            tabWidth: 4,
            useSpaces: true,
            formatOnSave: false,
            organizeImportsOnSave: false,
            fixAllOnSave: false,
            trimTrailingWhitespaceOnSave: true,
            insertFinalNewlineOnSave: true,
            wrapLines: true,
            showMinimap: true,
            showGutter: true,
            showFoldingRibbon: true,
            currentThemeId: "xcode-dark"
        )
        let override = EditorScopedOverrideSnapshot(
            tabWidth: 2,
            useSpaces: false,
            wrapLines: nil,
            formatOnSave: true
        )

        let resolved = override.applying(to: base)

        XCTAssertEqual(resolved.tabWidth, 2)
        XCTAssertEqual(resolved.useSpaces, false)
        XCTAssertEqual(resolved.formatOnSave, true)
        XCTAssertEqual(resolved.wrapLines, true)
        XCTAssertEqual(resolved.currentThemeId, "xcode-dark")
    }

    func testEditorScopedOverrideSnapshotDictionaryRoundTrips() {
        let override = EditorScopedOverrideSnapshot(
            tabWidth: 8,
            useSpaces: true,
            wrapLines: false,
            formatOnSave: true
        )

        let decoded = EditorScopedOverrideSnapshot.from(dictionary: override.dictionaryRepresentation)

        XCTAssertEqual(decoded, override)
        XCTAssertFalse(decoded.isEmpty)
    }

    func testEditorQuickOpenControllerParsesScopedQueries() {
        let controller = EditorQuickOpenController()

        let documentSymbols = controller.parse("@ methods")
        XCTAssertEqual(documentSymbols.scope, .documentSymbols)
        XCTAssertEqual(documentSymbols.searchText, "methods")
        XCTAssertTrue(documentSymbols.hasExplicitScope)

        let workspaceSymbols = controller.parse("# service")
        XCTAssertEqual(workspaceSymbols.scope, .workspaceSymbols)
        XCTAssertEqual(workspaceSymbols.searchText, "service")

        let commands = controller.parse("> format")
        XCTAssertEqual(commands.scope, .commands)
        XCTAssertEqual(commands.searchText, "format")

        let line = controller.parse(":12:7")
        XCTAssertEqual(line.scope, .line)
        XCTAssertEqual(line.line, 12)
        XCTAssertEqual(line.column, 7)
    }

    func testEditorQuickOpenControllerDefaultsToFileSearchForPlainQuery() {
        let controller = EditorQuickOpenController()

        let query = controller.parse("  AppDelegate  ")

        XCTAssertEqual(query.scope, .files)
        XCTAssertEqual(query.searchText, "AppDelegate")
        XCTAssertFalse(query.hasExplicitScope)
        XCTAssertNil(query.line)
        XCTAssertNil(query.column)
    }

    func testCursorMotionControllerMoveWordLeftSkipsWhitespaceAndOperators() {
        let target = CursorMotionController.moveWordLeft(location: 10, text: "foo  +  bar")

        XCTAssertEqual(target.location, 8)
        XCTAssertNil(target.selectionRange)
    }

    func testCursorMotionControllerMoveWordRightStopsAtEndOfNextWord() {
        let target = CursorMotionController.moveWordRight(location: 0, text: "foo  +  bar")

        XCTAssertEqual(target.location, 3)
        XCTAssertNil(target.selectionRange)
    }

    func testCursorMotionControllerDeleteWordLeftReturnsDeletionRange() {
        let target = CursorMotionController.deleteWordLeft(location: 7, text: "foo bar")

        XCTAssertEqual(target.location, 4)
        XCTAssertEqual(target.selectionRange, NSRange(location: 4, length: 3))
    }

    func testCursorMotionControllerSmartHomeTogglesBetweenIndentAndLineStart() {
        let text = "    value"

        XCTAssertEqual(CursorMotionController.smartHome(location: 9, text: text).location, 0)
        XCTAssertEqual(CursorMotionController.smartHome(location: 0, text: text).location, 4)
        XCTAssertEqual(CursorMotionController.smartHome(location: 2, text: text).location, 4)
    }

    func testCursorMotionControllerMoveToEndOfLineHandlesCRLF() {
        let text = "abc\r\ndef"

        XCTAssertEqual(CursorMotionController.moveToEndOfLine(location: 1, text: text).location, 3)
        XCTAssertEqual(CursorMotionController.moveToEndOfLine(location: 5, text: text).location, 8)
    }

    func testCursorMotionControllerParagraphNavigationRespectsBlankLines() {
        let text = "first\nsecond\n\nthird\n\n"

        XCTAssertEqual(CursorMotionController.moveParagraphForward(location: 0, text: text).location, 13)
        XCTAssertEqual(CursorMotionController.moveParagraphBackward(location: 13, text: text).location, 0)
    }

    func testMultiCursorEditEngineInsertReplacesSelectionAndPreservesOrder() {
        let result = MultiCursorEditEngine.apply(
            text: "abcd",
            selections: [
                .init(location: 1, length: 1),
                .init(location: 3, length: 1),
            ],
            operation: .insert("X")
        )

        XCTAssertEqual(result.text, "aXcX")
        XCTAssertEqual(
            result.selections,
            [
                .init(location: 2, length: 0),
                .init(location: 4, length: 0),
            ]
        )
    }

    func testMultiCursorEditEngineDeleteBackwardDeletesSelectedTextAndPreviousCharacter() {
        let result = MultiCursorEditEngine.apply(
            text: "abcd",
            selections: [
                .init(location: 1, length: 0),
                .init(location: 3, length: 1),
            ],
            operation: .deleteBackward
        )

        XCTAssertEqual(result.text, "bc")
        XCTAssertEqual(
            result.selections,
            [
                .init(location: 0, length: 0),
                .init(location: 3, length: 0),
            ]
        )
    }

    func testMultiCursorEditEngineIndentExpandsCoveredSelections() {
        // Mirror core semantics: selection expands to cover all affected lines.
        let result = MultiCursorEditEngine.apply(
            text: "one\ntwo",
            selections: [
                .init(location: 0, length: 7)
            ],
            operation: .indent("  ")
        )

        XCTAssertEqual(result.text, "  one\n  two")
        // Kernel implementation keeps the selection spanning the whole edited region.
        XCTAssertEqual(result.selections, [.init(location: 0, length: 13)])
    }

    func testMultiCursorEditEngineOutdentRemovesLeadingSpacesAndShiftsSelections() {
        // Use the same stable scenario as EditorKernel tests to avoid diverging expectations.
        let result = MultiCursorEditEngine.apply(
            text: "    one\n    two",
            selections: [
                .init(location: 0, length: 13)
            ],
            operation: .outdent(tabSize: 4, useSpaces: true)
        )

        XCTAssertEqual(result.text, "one\ntwo")
        XCTAssertEqual(result.selections, [.init(location: 0, length: 5)])
    }

    func testMultiCursorStateAddSecondaryRejectsDuplicatesAndInvalidSelections() {
        var state = MultiCursorState(primary: .init(location: 3, length: 0), secondary: [])

        state.addSecondary(.init(location: 6, length: 0))
        state.addSecondary(.init(location: 6, length: 0))
        state.addSecondary(.init(location: -1, length: 0))
        state.addSecondary(.init(location: 3, length: 0))

        XCTAssertEqual(state.all, [.init(location: 3, length: 0), .init(location: 6, length: 0)])
        XCTAssertTrue(state.isEnabled)
    }

    func testEditorMultiCursorStateControllerReplacingPrimaryPreservesSecondaryOrder() {
        let state = MultiCursorState(
            primary: .init(location: 10, length: 0),
            secondary: [.init(location: 20, length: 0), .init(location: 30, length: 0)]
        )

        let updated = EditorMultiCursorStateController.replacingPrimary(
            in: state,
            with: .init(location: 5, length: 1)
        )

        XCTAssertEqual(
            updated.all,
            [
                .init(location: 5, length: 1),
                .init(location: 20, length: 0),
                .init(location: 30, length: 0),
            ]
        )
    }

    func testEditorMultiCursorMatcherNormalizedRangeClampsToTextBounds() {
        let text = "hello" as NSString

        XCTAssertEqual(
            EditorMultiCursorMatcher.normalizedRange(NSRange(location: 4, length: 99), in: text),
            NSRange(location: 4, length: 1)
        )
        XCTAssertEqual(
            EditorMultiCursorMatcher.normalizedRange(NSRange(location: NSNotFound, length: 1), in: text),
            NSRange(location: NSNotFound, length: 0)
        )
    }

    func testEditorMultiCursorMatcherResolvesWordSelectionFromCaret() {
        let text = "alpha beta" as NSString

        let selection = EditorMultiCursorMatcher.resolvedBaseSelection(
            from: NSRange(location: 7, length: 0),
            in: text
        )

        XCTAssertEqual(selection, .init(location: 6, length: 4))
    }

    func testEditorMultiCursorMatcherRangesUseWholeWordMatchingForIdentifiers() {
        let text = "cat scatter cat _cat cat_" as NSString

        let ranges = EditorMultiCursorMatcher.ranges(of: "cat", in: text)

        XCTAssertEqual(
            ranges,
            [
                .init(location: 0, length: 3),
                .init(location: 12, length: 3),
            ]
        )
    }

    func testEditorMultiCursorSearchControllerResolvedContextReusesExistingSession() {
        let text = "value value" as NSString
        let session = EditorMultiCursorSearchSession(
            query: "value",
            baseSelection: .init(location: 0, length: 5),
            history: [.init(location: 0, length: 5)]
        )

        let resolved = EditorMultiCursorSearchController.resolvedContext(
            from: NSRange(location: 6, length: 5),
            in: text,
            existingSession: session
        )

        XCTAssertEqual(
            resolved,
            EditorMultiCursorResolvedContext(
                context: .init(baseSelection: .init(location: 0, length: 5), query: "value"),
                shouldStartSession: false
            )
        )
    }

    func testEditorMultiCursorSearchControllerNextSelectionSkipsAlreadySelectedMatches() {
        let matches: [MultiCursorSelection] = [
            .init(location: 0, length: 5),
            .init(location: 6, length: 5),
            .init(location: 12, length: 5),
        ]
        let state = MultiCursorState(
            primary: .init(location: 0, length: 5),
            secondary: [.init(location: 6, length: 5)]
        )
        let session = EditorMultiCursorSearchSession(
            query: "value",
            baseSelection: .init(location: 0, length: 5),
            history: [.init(location: 0, length: 5), .init(location: 6, length: 5)]
        )

        let next = EditorMultiCursorSearchController.nextSelection(
            in: matches,
            currentState: state,
            session: session
        )

        XCTAssertEqual(next, .init(location: 12, length: 5))
    }

    func testEditorMultiCursorControllerSummaryTextReflectsCursorCount() {
        let controller = EditorMultiCursorController()

        let single = controller.summaryText(for: MultiCursorState())
        let multiple = controller.summaryText(
            for: MultiCursorState(
                primary: .init(location: 0, length: 0),
                secondary: [.init(location: 3, length: 0), .init(location: 6, length: 0)]
            )
        )

        XCTAssertEqual(single, "1")
        XCTAssertEqual(multiple, "3" + String(localized: " cursors", table: "LumiEditor"))
    }

    func testEditorFindControllerStateUpdatesKeepPanelVisibleAndPreserveOtherFields() {
        let controller = EditorFindController()
        let original = EditorFindReplaceState(
            findText: "old",
            replaceText: "value",
            isFindPanelVisible: false,
            options: .init(isCaseSensitive: true),
            resultCount: 3,
            selectedMatchIndex: 1,
            selectedMatchRange: .init(location: 4, length: 3)
        )

        let updatedFind = controller.stateForUpdatingFindQuery(original, text: "new")
        let updatedReplace = controller.stateForUpdatingReplaceQuery(original, text: "next")

        XCTAssertEqual(updatedFind.findText, "new")
        XCTAssertEqual(updatedFind.replaceText, "value")
        XCTAssertTrue(updatedFind.isFindPanelVisible)
        XCTAssertEqual(updatedFind.options, original.options)

        XCTAssertEqual(updatedReplace.findText, "old")
        XCTAssertEqual(updatedReplace.replaceText, "next")
        XCTAssertTrue(updatedReplace.isFindPanelVisible)
        XCTAssertEqual(updatedReplace.selectedMatchIndex, original.selectedMatchIndex)
    }

    func testEditorFindControllerApplyMethodsUpdateMatchSelectionState() {
        let controller = EditorFindController()
        var state = EditorFindReplaceState()
        let match = EditorFindMatch(range: .init(location: 8, length: 4), matchedText: "test")

        controller.applyMatchesResult(
            .init(matches: [match], selectedMatchIndex: 0, selectedMatchRange: match.range),
            to: &state
        )

        XCTAssertEqual(state.resultCount, 1)
        XCTAssertEqual(state.selectedMatchIndex, 0)
        XCTAssertEqual(state.selectedMatchRange, .init(location: 8, length: 4))

        controller.applySelectedMatch(index: 2, match: match, to: &state)

        XCTAssertEqual(state.selectedMatchIndex, 2)
        XCTAssertEqual(state.selectedMatchRange, match.range)
    }

    func testEditorFindReplaceStateControllerPreservesOptionsAndResultMetadata() {
        let existing = EditorFindReplaceState(
            findText: "old",
            replaceText: "before",
            isFindPanelVisible: false,
            options: .init(matchesWholeWord: true, preservesCase: true),
            resultCount: 8,
            selectedMatchIndex: 3,
            selectedMatchRange: .init(location: 20, length: 5)
        )

        let updated = EditorFindReplaceStateController.state(
            findText: "new",
            replaceText: "after",
            isFindPanelVisible: true,
            preserving: existing
        )

        XCTAssertEqual(updated.findText, "new")
        XCTAssertEqual(updated.replaceText, "after")
        XCTAssertTrue(updated.isFindPanelVisible)
        XCTAssertEqual(updated.options, existing.options)
        XCTAssertEqual(updated.resultCount, existing.resultCount)
        XCTAssertEqual(updated.selectedMatchIndex, existing.selectedMatchIndex)
        XCTAssertEqual(updated.selectedMatchRange, existing.selectedMatchRange)
    }

    func testMultiCursorTransactionBuilderDeleteBackwardBuildsExpectedReplacements() {
        let transaction = MultiCursorTransactionBuilder.makeTransaction(
            operation: .deleteBackward,
            selections: [
                .init(location: 0, length: 0),
                .init(location: 5, length: 2),
                .init(location: 9, length: 0),
            ],
            updatedSelections: [
                .init(location: 0, length: 0),
                .init(location: 5, length: 0),
                .init(location: 8, length: 0),
            ]
        )

        XCTAssertEqual(
            transaction.replacements,
            [
                .init(range: .init(location: 0, length: 0), text: ""),
                .init(range: .init(location: 5, length: 2), text: ""),
                .init(range: .init(location: 8, length: 1), text: ""),
            ]
        )
        XCTAssertEqual(
            transaction.updatedSelections,
            [
                .init(range: .init(location: 0, length: 0)),
                .init(range: .init(location: 5, length: 0)),
                .init(range: .init(location: 8, length: 0)),
            ]
        )
    }

    func testEditorTransactionControllerTransactionForInputEditRejectsInvalidRange() {
        let controller = EditorTransactionController()

        XCTAssertNil(
            controller.transactionForInputEdit(
                replacementRange: NSRange(location: NSNotFound, length: 0),
                replacementText: "x",
                selectedRanges: [NSRange(location: 1, length: 0)]
            )
        )
    }

    func testEditorTransactionControllerCompletionEditMovesCursorAfterAdditionalEdits() {
        let controller = EditorTransactionController()
        let transaction = controller.transactionForCompletionEdit(
            text: "foo",
            replacementRange: NSRange(location: 3, length: 0),
            replacementText: "bar",
            additionalTextEdits: [
                TextEdit(
                    range: LSPRange(
                        start: Position(line: 0, character: 0),
                        end: Position(line: 0, character: 0)
                    ),
                    newText: "let "
                )
            ]
        )

        XCTAssertEqual(transaction?.replacements.count, 2)
        XCTAssertEqual(transaction?.updatedSelections, [.init(range: .init(location: 10, length: 0))])
    }

    func testEditorTransactionControllerCommitPayloadMapsSelectionsIntoBothForms() {
        let controller = EditorTransactionController()
        let result = EditorEditResult(
            snapshot: .init(text: "a\nb\n", version: 4),
            selections: [
                .init(range: .init(location: 2, length: 1)),
                .init(range: .init(location: 5, length: 0)),
            ]
        )

        let payload = controller.commitPayload(from: result)

        XCTAssertEqual(payload.text, "a\nb\n")
        XCTAssertEqual(payload.version, 4)
        XCTAssertEqual(payload.totalLines, 3)
        XCTAssertEqual(
            payload.canonicalSelectionSet,
            EditorSelectionSet(
                selections: [
                    .init(range: .init(location: 2, length: 1)),
                    .init(range: .init(location: 5, length: 0)),
                ]
            )
        )
        XCTAssertEqual(
            payload.multiCursorSelections,
            [
                .init(location: 2, length: 1),
                .init(location: 5, length: 0),
            ]
        )
    }

    func testCommandRouterContextMirrorsLegacyValuesAndEditorStateFlags() {
        let legacy = EditorCommandContext(languageId: "swift", hasSelection: true, line: 7, character: 3)
        let context = CommandRouter.commandContext(from: legacy, isEditorActive: true, isMultiCursor: false)

        XCTAssertEqual(context.languageId, "swift")
        XCTAssertTrue(context.hasSelection)
        XCTAssertEqual(context.line, 7)
        XCTAssertEqual(context.character, 3)
        XCTAssertTrue(context.isEditorActive)
        XCTAssertFalse(context.isMultiCursor)
    }

    func testCommandRouterRegistersSuggestionsAndExecutesViaRegistry() {
        let registry = CommandRegistry.shared
        registry.clear()
        defer { registry.clear() }

        var executions = 0
        CommandRouter.registerSuggestions(
            [
                EditorCommandSuggestion(
                    id: "kernel.test",
                    title: "Kernel Test",
                    systemImage: "hammer",
                    shortcut: nil,
                    order: 5,
                    isEnabled: true
                ) {
                    executions += 1
                }
            ],
            category: "testing"
        )

        let context = CommandContext()
        let suggestions = CommandRouter.suggestionsFromRegistry(in: context, filterCategory: "testing")

        XCTAssertEqual(suggestions.map(\.id), ["kernel.test"])
        XCTAssertTrue(CommandRouter.execute(id: "kernel.test", in: context, legacySuggestions: []))
        XCTAssertEqual(executions, 1)
    }

    func testCommandRouterFallsBackToLegacySuggestionsWhenRegistryMisses() {
        let registry = CommandRegistry.shared
        registry.clear()
        defer { registry.clear() }

        var executions = 0
        let suggestions = [
            EditorCommandSuggestion(
                id: "legacy.only",
                title: "Legacy",
                systemImage: "clock",
                shortcut: nil,
                order: 1,
                isEnabled: true
            ) {
                executions += 1
            }
        ]

        let executed = CommandRouter.execute(id: "legacy.only", in: CommandContext(), legacySuggestions: suggestions)

        XCTAssertTrue(executed)
        XCTAssertEqual(executions, 1)
    }

    func testEditorInputCommandControllerDeleteWordLeftProducesDeletionTransaction() {
        let controller = EditorInputCommandController()
        let plan = controller.cursorMotionPlan(
            kind: .deleteWordLeft,
            text: "foo bar",
            currentLocation: 7,
            currentRange: NSRange(location: 7, length: 0)
        )

        guard case let .transaction(transaction)? = plan else {
            return XCTFail("Expected transaction plan")
        }

        XCTAssertEqual(transaction.replacements, [.init(range: .init(location: 4, length: 3), text: "")])
        XCTAssertEqual(transaction.updatedSelections, [.init(range: .init(location: 4, length: 0))])
    }

    func testEditorInputCommandControllerSmartHomeSelectExpandsSelectionFromAnchor() {
        let controller = EditorInputCommandController()
        let plan = controller.cursorMotionPlan(
            kind: .smartHomeSelect,
            text: "    value",
            currentLocation: 9,
            currentRange: NSRange(location: 9, length: 0)
        )

        guard case let .selections(ranges)? = plan else {
            return XCTFail("Expected selection plan")
        }

        XCTAssertEqual(ranges, [NSRange(location: 0, length: 9)])
    }

    func testEditorSnippetParserSeedsRepeatedPlaceholdersAndTracksExplicitExit() {
        let result = EditorSnippetParser.parse("${1:name} = $1$0")

        XCTAssertEqual(result.text, "name = name")
        XCTAssertEqual(
            result.groups,
            [
                .init(
                    index: 1,
                    ranges: [
                        NSRange(location: 0, length: 4),
                        NSRange(location: 7, length: 4),
                    ]
                )
            ]
        )
        XCTAssertEqual(result.exitSelection, NSRange(location: 11, length: 0))
    }

    func testEditorSnippetParserUsesImplicitExitAtEndWhenZeroPlaceholderIsMissing() {
        let result = EditorSnippetParser.parse("func ${1:name}(${2:value})")

        XCTAssertEqual(result.text, "func name(value)")
        XCTAssertEqual(result.groups.map(\.index), [1, 2])
        XCTAssertEqual(result.exitSelection, NSRange(location: 16, length: 0))
    }

    func testEditorSnippetParserTreatsEscapedMarkersAsLiteralText() {
        let result = EditorSnippetParser.parse("\\$1 and ${2:va\\}lue}")

        XCTAssertEqual(result.text, "$1 and va}lue")
        XCTAssertEqual(result.groups, [.init(index: 2, ranges: [NSRange(location: 7, length: 6)])])
    }

    func testEditorCommandCategoryResolveAndOrderIndexFallBackToOther() {
        XCTAssertEqual(EditorCommandCategory.resolve("find"), .find)
        XCTAssertEqual(EditorCommandCategory.resolve("missing"), .other)
        XCTAssertLessThan(
            EditorCommandCategory.orderIndex(for: "edit"),
            EditorCommandCategory.orderIndex(for: "other")
        )
    }

    func testEditorCommandPresentationModelBuildsRecentFrequentAndCategorizedSections() {
        let suggestions = [
            makeSuggestion(id: "edit.copy", title: "Copy", category: "edit", order: 20),
            makeSuggestion(id: "find.inFile", title: "Find In File", category: "find", order: 10),
            makeSuggestion(id: "nav.open", title: "Open Symbol", category: "navigation", order: 30),
            makeSuggestion(id: "edit.cut", title: "Cut", category: "edit", order: 5),
        ]

        let model = EditorCommandPresentationModel.build(
            from: suggestions,
            recentCommandIDs: ["find.inFile"],
            commandUsageCounts: [
                "edit.copy": 3,
                "nav.open": 2,
            ],
            frequentLimit: 1
        )

        XCTAssertEqual(model.recentCommands.map(\.id), ["find.inFile"])
        XCTAssertEqual(model.frequentCommands.map(\.id), ["edit.copy"])
        XCTAssertEqual(model.sections.map(\.category), [.edit, .navigation])
        XCTAssertEqual(model.sections.first?.commands.map(\.id), ["edit.cut"])
        XCTAssertEqual(model.flattenedCommands.map(\.id), ["find.inFile", "edit.copy", "edit.cut", "nav.open"])
    }

    func testEditorCommandPresentationModelFiltersByQueryShortcutAndAllowedCategories() {
        let suggestions = [
            makeSuggestion(
                id: "edit.comment",
                title: "Toggle Comment",
                category: "edit",
                shortcut: .init(key: "/", modifiers: [.command]),
                order: 10
            ),
            makeSuggestion(id: "lsp.rename", title: "Rename Symbol", category: "lsp", order: 5),
        ]

        let byShortcut = EditorCommandPresentationModel.build(
            from: suggestions,
            recentCommandIDs: [],
            query: "⌘/"
        )
        let onlyLSP = EditorCommandPresentationModel.build(
            from: suggestions,
            recentCommandIDs: [],
            allowedCategories: [.lsp]
        )

        XCTAssertEqual(byShortcut.flattenedCommands.map(\.id), ["edit.comment"])
        XCTAssertEqual(onlyLSP.flattenedCommands.map(\.id), ["lsp.rename"])
    }

    func testCommandSuggestionsSortByCategoryOrderThenCommandOrderThenTitle() {
        let sorted = [
            makeSuggestion(id: "b", title: "Beta", category: "edit", order: 10),
            makeSuggestion(id: "a", title: "Alpha", category: "edit", order: 10),
            makeSuggestion(id: "z", title: "Zoom", category: "navigation", order: 1),
            makeSuggestion(id: "x", title: "Misc", category: nil, order: 0),
        ].sortedForCommandPresentation()

        XCTAssertEqual(sorted.map(\.id), ["a", "b", "z", "x"])
    }

    func testEditorCommandCategoryScopeSetsRemainStable() {
        XCTAssertTrue(EditorCommandCategoryScope.lspActions.contains(.navigation))
        XCTAssertTrue(EditorCommandCategoryScope.editorContextMenu.contains(.chat))
        XCTAssertFalse(EditorCommandCategoryScope.editorContextMenu.contains(.save))
    }

    private func makeSuggestion(
        id: String,
        title: String,
        category: String?,
        shortcut: EditorCommandShortcut? = nil,
        order: Int
    ) -> EditorCommandSuggestion {
        EditorCommandSuggestion(
            id: id,
            title: title,
            systemImage: "hammer",
            category: category,
            shortcut: shortcut,
            order: order,
            isEnabled: true,
            action: {}
        )
    }
}
#endif
