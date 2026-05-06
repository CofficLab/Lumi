import Foundation
import LanguageServerProtocol
import Testing
@testable import EditorKernelCore

struct EditorKernelCoreTests {
    @Test
    @MainActor
    func textInputControllerBuildsBracketAndIndentPlans() {
        let controller = EditorTextInputController()

        let autoClose = controller.textInputPlan(
            text: "(",
            replacementRange: NSRange(location: 1, length: 0),
            textViewSelections: [NSRange(location: 1, length: 0)],
            multiCursorSelectionCount: 1,
            currentText: "a)",
            languageId: "swift"
        )
        #expect(autoClose?.replacementText == "()")
        #expect(autoClose?.selectedRanges == [NSRange(location: 2, length: 0)])

        let newline = controller.insertNewlinePlan(
            textViewSelections: [NSRange(location: 1, length: 0)],
            multiCursorSelectionCount: 1,
            currentText: "{}",
            tabSize: 4,
            useSpaces: true
        )
        #expect(newline?.replacementText == "\n    \n")
        #expect(newline?.selectedRanges == [NSRange(location: 6, length: 0)])
    }

    @Test
    func bracketAndIndentPoliciesHandleLanguageAndOutdentRules() {
        let htmlConfig = BracketPairsConfig.defaultForLanguage("html")
        #expect(htmlConfig.autoClosingPairs.isEmpty)

        let pythonConfig = BracketPairsConfig.defaultForLanguage("python")
        #expect(
            BracketMatcher.shouldAutoClose(
                in: "print(\"value",
                at: 12,
                typedChar: "\"",
                config: pythonConfig
            ) == nil
        )

        let outdented = SmartIndentHandler.handleBacktab(
            in: "    one\n    two",
            selection: NSRange(location: 0, length: 13),
            tabSize: 4,
            useSpaces: true
        )
        #expect(outdented?.replacementText == "one\ntwo")
        #expect(outdented?.selectedRange == NSRange(location: 0, length: 5))
    }

    @Test
    @MainActor
    func inputCommandControllerBuildsLineEditAndCursorPlans() {
        let controller = EditorInputCommandController()

        let commented = controller.lineEditResult(
            kind: .toggleLineComment,
            text: "value",
            selections: [NSRange(location: 0, length: 0)],
            languageId: "python"
        )
        #expect(commented?.replacementText == "# value")

        let deleteLeft = controller.cursorMotionPlan(
            kind: .deleteWordLeft,
            text: "foo bar",
            currentLocation: 7,
            currentRange: NSRange(location: 7, length: 0)
        )
        if case let .transaction(transaction)? = deleteLeft {
            #expect(transaction.replacements == [
                .init(range: .init(location: 4, length: 3), text: "")
            ])
            #expect(transaction.updatedSelections == [
                .init(range: .init(location: 4, length: 0))
            ])
        } else {
            Issue.record("Expected delete-word-left transaction")
        }
    }

    @Test
    @MainActor
    func callHierarchyControllerPreparesCoordinatesAndOpensOnlyWhenRootExists() async {
        let controller = EditorCallHierarchyController()
        let fileURL = URL(fileURLWithPath: "/tmp/CallHierarchy.swift")

        var prepared: (String, Int, Int)?
        var warning: String?
        var opened = false

        await controller.openCallHierarchy(
            currentFileURL: fileURL,
            cursorLine: 3,
            cursorColumn: 5,
            prepare: { uri, line, character in
                prepared = (uri, line, character)
            },
            hasRootItem: { true },
            showWarning: { warning = $0 },
            openPanel: { opened = true }
        )

        #expect(prepared?.0 == fileURL.absoluteString)
        #expect(prepared?.1 == 2)
        #expect(prepared?.2 == 4)
        #expect(warning == nil)
        #expect(opened == true)

        opened = false
        await controller.openCallHierarchy(
            currentFileURL: fileURL,
            cursorLine: 1,
            cursorColumn: 1,
            prepare: { _, _, _ in },
            hasRootItem: { false },
            showWarning: { warning = $0 },
            openPanel: { opened = true }
        )

        #expect(warning == "未找到调用层级信息")
        #expect(opened == false)
    }

    @Test
    @MainActor
    func externalFileControllerTracksConflictsAndReloadThresholds() {
        let controller = EditorExternalFileController()
        let modDate = Date()

        #expect(controller.registerConflictIfNeeded(content: "A", modificationDate: modDate) == true)
        #expect(controller.registerConflictIfNeeded(content: "A", modificationDate: modDate) == false)

        controller.recordUnchangedModificationDate(modDate)
        #expect(controller.shouldReloadForChange(currentModDate: modDate.addingTimeInterval(0.2), hasUnsavedChanges: false) == false)
        #expect(controller.shouldReloadForChange(currentModDate: modDate.addingTimeInterval(0.2), hasUnsavedChanges: true) == true)
    }

    @Test
    @MainActor
    func externalFileControllerLoadsAndAppliesExternalText() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try "hello".write(to: url, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: url) }

        let controller = EditorExternalFileController()
        let loaded = try await controller.loadExternalText(from: url)
        #expect(loaded == "hello")

        let modDate = Date()
        _ = controller.registerConflictIfNeeded(content: "world", modificationDate: modDate)

        var applied: (String, Date)?
        var cleared = false
        var synced = false
        controller.reloadConflict(
            applyExternalContent: { content, date in applied = (content, date) },
            clearConflict: { cleared = true },
            syncSession: { synced = true }
        )

        #expect(applied?.0 == "world")
        #expect(applied?.1 == modDate)
        #expect(cleared == true)
        #expect(synced == true)
    }

    @Test
    func cursorMotionWordAndLineBehaviorsRemainStable() {
        #expect(CursorMotionController.moveWordLeft(location: 10, text: "foo  +  bar").location == 8)
        #expect(CursorMotionController.moveWordRight(location: 0, text: "foo  +  bar").location == 3)
        #expect(CursorMotionController.smartHome(location: 9, text: "    value").location == 0)
        #expect(CursorMotionController.moveToEndOfLine(location: 0, text: "abc\r\ndef").location == 3)
    }

    @Test
    func cursorDeleteWordLeftReturnsExpectedRange() {
        let target = CursorMotionController.deleteWordLeft(location: 7, text: "foo bar")
        #expect(target.location == 4)
        #expect(target.selectionRange == NSRange(location: 4, length: 3))
    }

    @Test
    func snippetParserSeedsRepeatedPlaceholdersAndImplicitExit() {
        let repeated = EditorSnippetParser.parse("${1:name} = $1$0")
        #expect(repeated.text == "name = name")
        #expect(repeated.groups == [
            .init(index: 1, ranges: [
                NSRange(location: 0, length: 4),
                NSRange(location: 7, length: 4),
            ])
        ])
        #expect(repeated.exitSelection == NSRange(location: 11, length: 0))

        let implicit = EditorSnippetParser.parse("func ${1:name}(${2:value})")
        #expect(implicit.text == "func name(value)")
        #expect(implicit.groups.map(\.index) == [1, 2])
        #expect(implicit.exitSelection == NSRange(location: 16, length: 0))
    }

    @Test
    func multiCursorEditEngineInsertDeleteAndOutdentBehaviorsRemainStable() {
        let inserted = MultiCursorEditEngine.apply(
            text: "hello world",
            selections: [
                .init(location: 0, length: 5),
                .init(location: 6, length: 5),
            ],
            operation: .insert("x")
        )
        #expect(inserted.text == "x x")
        #expect(inserted.selections == [
            .init(location: 1, length: 0),
            .init(location: 7, length: 0),
        ])

        let deleted = MultiCursorEditEngine.apply(
            text: "abcd",
            selections: [
                .init(location: 1, length: 0),
                .init(location: 3, length: 1),
            ],
            operation: .deleteBackward
        )
        #expect(deleted.text == "bc")
        #expect(deleted.selections == [
            .init(location: 0, length: 0),
            .init(location: 3, length: 0),
        ])

        let outdented = MultiCursorEditEngine.apply(
            text: "    one\n    two",
            selections: [.init(location: 0, length: 13)],
            operation: .outdent(tabSize: 4, useSpaces: true)
        )
        #expect(outdented.text == "one\ntwo")
        #expect(outdented.selections == [.init(location: 0, length: 5)])
    }

    @Test
    func textEditApplierHandlesMultipleEditsAndRejectsInvalidRanges() {
        let edits = [
            TextEdit(
                range: LSPRange(start: Position(line: 1, character: 0), end: Position(line: 1, character: 5)),
                newText: "earth"
            ),
            TextEdit(
                range: LSPRange(start: Position(line: 0, character: 0), end: Position(line: 0, character: 5)),
                newText: "hello"
            ),
        ]

        #expect(TextEditApplier.apply(edits: edits, to: "world\nworld") == "hello\nearth")

        let invalid = [
            TextEdit(
                range: LSPRange(start: Position(line: 3, character: 0), end: Position(line: 3, character: 1)),
                newText: "x"
            )
        ]
        #expect(TextEditApplier.apply(edits: invalid, to: "line") == nil)
    }

    @Test
    func editorSelectionSetNormalizesOrderingAndSupportsMultiCursorRoundTrip() {
        let set = EditorSelectionSet(selections: [
            .init(range: .init(location: 8, length: 2)),
            .init(range: .init(location: 2, length: 4)),
        ])

        #expect(set.primary?.range.location == 2)
        #expect(set.isMultiCursor == true)
        #expect(set.toMultiCursorSelections() == [
            .init(location: 2, length: 4),
            .init(location: 8, length: 2),
        ])

        let rebuilt = EditorSelectionSet(multiCursorSelections: [
            .init(location: 8, length: 2),
            .init(location: 2, length: 4),
        ])
        #expect(rebuilt == set)
    }

    @Test
    func editorSelectionSetMutationHelpersRemainStable() {
        let original = EditorSelectionSet(selections: [
            .init(range: .init(location: 3, length: 0)),
            .init(range: .init(location: 9, length: 1)),
        ])

        let replaced = original.replacingPrimary(.init(range: .init(location: 1, length: 2)))
        #expect(replaced.selections.map(\.range.location) == [1, 9])

        let added = original.addingSelection(.init(range: .init(location: 6, length: 0)))
        #expect(added.selections.map(\.range.location) == [3, 6, 9])

        let removed = added.removingLastSecondary()
        #expect(removed.selections.map(\.range.location) == [3, 6])
        #expect(removed.clearingSecondary().count == 1)
    }

    @Test
    func textEditTransactionBuilderMapsUnicodeOffsetsAndRejectsInvalidLines() {
        let edits = [
            TextEdit(
                range: LSPRange(start: Position(line: 0, character: 0), end: Position(line: 0, character: 2)),
                newText: "🙂"
            ),
            TextEdit(
                range: LSPRange(start: Position(line: 1, character: 0), end: Position(line: 1, character: 1)),
                newText: "ZZ"
            ),
        ]

        let transaction = TextEditTransactionBuilder.makeTransaction(edits: edits, in: "😀a\nz")
        #expect(transaction?.replacements == [
            .init(range: .init(location: 0, length: 2), text: "🙂"),
            .init(range: .init(location: 4, length: 1), text: "ZZ"),
        ])

        let invalid = [
            TextEdit(
                range: LSPRange(start: Position(line: 3, character: 0), end: Position(line: 3, character: 1)),
                newText: "x"
            )
        ]
        #expect(TextEditTransactionBuilder.makeTransaction(edits: invalid, in: "abc") == nil)
    }

    @Test
    func multiCursorTransactionBuilderDeleteBackwardBuildsExpectedReplacements() {
        let transaction = MultiCursorTransactionBuilder.makeTransaction(
            operation: .deleteBackward,
            selections: [
                .init(location: 0, length: 0),
                .init(location: 4, length: 0),
                .init(location: 8, length: 2),
            ],
            updatedSelections: [
                .init(location: 0, length: 0),
                .init(location: 3, length: 0),
                .init(location: 8, length: 0),
            ]
        )

        #expect(transaction.replacements == [
            .init(range: .init(location: 0, length: 0), text: ""),
            .init(range: .init(location: 3, length: 1), text: ""),
            .init(range: .init(location: 8, length: 2), text: ""),
        ])
        #expect(transaction.updatedSelections?.map(\.range.location) == [0, 3, 8])
    }

    @Test
    func findReplaceTransactionBuilderPreservesCaseAndSelectionUpdate() {
        let state = EditorFindReplaceState(
            findText: "world",
            replaceText: "planet",
            options: .init(preservesCase: true),
            selectedMatchIndex: 0
        )
        let matches = [
            EditorFindMatch(range: .init(location: 4, length: 5), matchedText: "WORLD")
        ]

        let transaction = EditorFindReplaceTransactionBuilder.replaceCurrent(state: state, matches: matches)
        #expect(transaction?.replacements == [
            .init(range: .init(location: 4, length: 5), text: "PLANET")
        ])
        #expect(transaction?.updatedSelections == [
            .init(range: .init(location: 4, length: 6))
        ])
    }

    @Test
    func findReplaceTransactionBuilderReplaceAllAndPreviewRespectCurrentSemantics() {
        let state = EditorFindReplaceState(
            findText: "world",
            replaceText: "planet",
            options: .init(preservesCase: true)
        )
        let matches = [
            EditorFindMatch(range: .init(location: 0, length: 5), matchedText: "World"),
            EditorFindMatch(range: .init(location: 8, length: 5), matchedText: "world"),
        ]

        let transaction = EditorFindReplaceTransactionBuilder.replaceAll(state: state, matches: matches)
        #expect(transaction?.replacements == [
            .init(range: .init(location: 0, length: 5), text: "Planet"),
            .init(range: .init(location: 8, length: 5), text: "planet"),
        ])
        #expect(EditorFindReplaceTransactionBuilder.previewReplacementText(for: matches[0], state: state) == "Planet")
    }

    @Test
    func findReplaceControllerMatchesRespectWordBoundariesAndSelectionScopes() {
        let wholeWord = EditorFindReplaceState(
            findText: "cat",
            options: .init(matchesWholeWord: true)
        )

        let wholeWordResult = EditorFindReplaceController.matches(
            in: "cat concatenate cat",
            state: wholeWord,
            selections: [],
            primarySelection: nil
        )
        #expect(wholeWordResult.matches.map(\.range) == [
            .init(location: 0, length: 3),
            .init(location: 16, length: 3),
        ])

        let scoped = EditorFindReplaceState(
            findText: "foo",
            options: .init(inSelectionOnly: true)
        )
        let scopedResult = EditorFindReplaceController.matches(
            in: "foo bar foo baz",
            state: scoped,
            selections: [.init(range: .init(location: 8, length: 3))],
            primarySelection: .init(range: .init(location: 8, length: 3))
        )
        #expect(scopedResult.matches.map(\.range) == [
            .init(location: 8, length: 3)
        ])
    }

    @Test
    func findReplaceControllerPrefersCurrentOrNextMatch() {
        var preferred = EditorFindReplaceState(findText: "foo")
        preferred.selectedMatchRange = .init(location: 4, length: 3)

        let preferredResult = EditorFindReplaceController.matches(
            in: "foo foo foo",
            state: preferred,
            selections: [],
            primarySelection: .init(range: .init(location: 0, length: 0))
        )
        #expect(preferredResult.selectedMatchIndex == 1)

        let next = EditorFindReplaceState(findText: "foo")
        let nextResult = EditorFindReplaceController.matches(
            in: "foo bar foo baz foo",
            state: next,
            selections: [],
            primarySelection: .init(range: .init(location: 5, length: 0))
        )
        #expect(nextResult.selectedMatchIndex == 1)
        #expect(EditorFindReplaceController.nextMatchIndex(in: nextResult.matches, selectedMatchIndex: 2) == 0)
        #expect(EditorFindReplaceController.previousMatchIndex(in: nextResult.matches, selectedMatchIndex: 0) == 2)
    }

    @Test
    @MainActor
    func findControllerStateAndMatchUpdatesRemainStable() {
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
        #expect(updatedFind.findText == "new")
        #expect(updatedFind.replaceText == "value")
        #expect(updatedFind.isFindPanelVisible == true)
        #expect(updatedFind.options == original.options)

        var state = EditorFindReplaceState()
        let match = EditorFindMatch(range: .init(location: 8, length: 4), matchedText: "test")
        controller.applyMatchesResult(
            .init(matches: [match], selectedMatchIndex: 0, selectedMatchRange: match.range),
            to: &state
        )
        #expect(state.resultCount == 1)
        #expect(state.selectedMatchIndex == 0)
        controller.applySelectedMatch(index: 2, match: match, to: &state)
        #expect(state.selectedMatchIndex == 2)
        #expect(state.selectedMatchRange == match.range)
    }

    @Test
    func findReplaceStateControllerPreservesOptionsAndResultMetadata() {
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

        #expect(updated.findText == "new")
        #expect(updated.replaceText == "after")
        #expect(updated.isFindPanelVisible == true)
        #expect(updated.options == existing.options)
        #expect(updated.resultCount == existing.resultCount)
        #expect(updated.selectedMatchIndex == existing.selectedMatchIndex)
        #expect(updated.selectedMatchRange == existing.selectedMatchRange)
    }

    @Test
    func quickOpenFilePolicyResolvesProjectRelativePathsAndParentLabels() {
        let fileURL = URL(fileURLWithPath: "/tmp/Lumi/Sources/App/Main.swift")
        #expect(
            EditorQuickOpenFilePolicy.relativePath(
                for: fileURL,
                projectRootPath: "/tmp/Lumi"
            ) == "Sources/App/Main.swift"
        )
        #expect(EditorQuickOpenFilePolicy.relativePath(for: fileURL, projectRootPath: "/tmp/Other") == "Main.swift")
        #expect(EditorQuickOpenFilePolicy.parentLabel(for: "Sources/App/Main.swift") == "App")
        #expect(EditorQuickOpenFilePolicy.parentLabel(for: "Main.swift") == nil)
    }

    @Test
    func quickOpenFilePolicyMatchesFuzzyQueriesAndEngineeringFiles() {
        #expect(EditorQuickOpenFilePolicy.fuzzyMatch("editorquickopen", query: "eqo"))
        #expect(!EditorQuickOpenFilePolicy.fuzzyMatch("editorquickopen", query: "eqz"))
        #expect(
            EditorQuickOpenFilePolicy.matchesFileQuery(
                "pbx",
                title: "Lumi",
                relativePath: "App/Lumi.xcodeproj/project.pbxproj"
            )
        )

        let packageURL = URL(fileURLWithPath: "/tmp/Lumi/Package.swift")
        #expect(EditorQuickOpenFilePolicy.engineeringFilePriorityBonus(for: packageURL) == 20)
        #expect(EditorQuickOpenFilePolicy.systemImage(for: packageURL) == "shippingbox")

        let configURL = URL(fileURLWithPath: "/tmp/Lumi/Debug.xcconfig")
        #expect(EditorQuickOpenFilePolicy.engineeringFilePriorityBonus(for: configURL) == 18)
        #expect(EditorQuickOpenFilePolicy.systemImage(for: configURL) == "slider.horizontal.3")
    }

    @Test
    func quickOpenFilePolicyMergesAndOrdersCandidates() {
        let sharedURL = URL(fileURLWithPath: "/tmp/Lumi/Sources/App/Main.swift")
        var candidatesByPath: [String: EditorQuickOpenFileCandidate] = [:]
        EditorQuickOpenFilePolicy.mergeCandidate(
            .init(
                fileURL: sharedURL,
                title: "Main.swift",
                subtitle: "Main.swift",
                parentLabel: nil,
                score: 10,
                recentRank: 8
            ),
            into: &candidatesByPath
        )
        EditorQuickOpenFilePolicy.mergeCandidate(
            .init(
                fileURL: sharedURL,
                title: "Main.swift",
                subtitle: "Sources/App/Main.swift",
                parentLabel: "App",
                score: 40,
                recentRank: 2
            ),
            into: &candidatesByPath
        )

        let merged = candidatesByPath[sharedURL.standardizedFileURL.path]
        #expect(merged?.subtitle == "Sources/App/Main.swift")
        #expect(merged?.parentLabel == "App")
        #expect(merged?.score == 40)
        #expect(merged?.recentRank == 2)

        let ordered = EditorQuickOpenFilePolicy.orderedCandidates([
            .init(
                fileURL: URL(fileURLWithPath: "/tmp/Lumi/B.swift"),
                title: "B.swift",
                subtitle: "B.swift",
                parentLabel: nil,
                score: 10,
                recentRank: 9
            ),
            .init(
                fileURL: URL(fileURLWithPath: "/tmp/Lumi/A.swift"),
                title: "A.swift",
                subtitle: "A.swift",
                parentLabel: nil,
                score: 20,
                recentRank: 5
            ),
            .init(
                fileURL: URL(fileURLWithPath: "/tmp/Lumi/C.swift"),
                title: "C.swift",
                subtitle: "C.swift",
                parentLabel: nil,
                score: 20,
                recentRank: 2
            ),
        ])
        #expect(ordered.map(\.title) == ["C.swift", "A.swift", "B.swift"])

        let duplicateTitles = EditorQuickOpenFilePolicy.duplicateTitles(in: [
            .init(
                fileURL: URL(fileURLWithPath: "/tmp/Lumi/One/Main.swift"),
                title: "Main.swift",
                subtitle: "One/Main.swift",
                parentLabel: "One",
                score: 10,
                recentRank: 1
            ),
            .init(
                fileURL: URL(fileURLWithPath: "/tmp/Lumi/Two/Main.swift"),
                title: "Main.swift",
                subtitle: "Two/Main.swift",
                parentLabel: "Two",
                score: 9,
                recentRank: 2
            ),
            .init(
                fileURL: URL(fileURLWithPath: "/tmp/Lumi/App.swift"),
                title: "App.swift",
                subtitle: "App.swift",
                parentLabel: nil,
                score: 8,
                recentRank: 3
            ),
        ])
        #expect(duplicateTitles == ["Main.swift"])
    }

    @Test
    func saveParticipantControllerTrimsTrailingWhitespaceAndPreservesCRLF() {
        let result = EditorSaveParticipantController.prepare(
            text: "one  \r\ntwo\t",
            options: .init(trimTrailingWhitespace: true, insertFinalNewline: true)
        )
        #expect(result.text == "one\r\ntwo\r\n")
        #expect(result.didTrimTrailingWhitespace)
        #expect(result.didInsertFinalNewline)
        #expect(result.changed)
    }

    @Test
    @MainActor
    func savePipelineControllerAppliesFormattingAndDeferredActions() async {
        let result = await EditorSavePipelineController.prepare(
            text: "value  ",
            options: .init(
                textParticipants: .init(trimTrailingWhitespace: true, insertFinalNewline: true),
                formatOnSave: true,
                organizeImportsOnSave: true,
                fixAllOnSave: true
            ),
            tabSize: 4,
            insertSpaces: true,
            formatDocument: { text, tabSize, insertSpaces in
                #expect(text == "value\n")
                #expect(tabSize == 4)
                #expect(insertSpaces)
                return text.uppercased()
            }
        )

        #expect(result.text == "VALUE\n")
        #expect(result.didApplyTextParticipants)
        #expect(result.didFormat)
        #expect(result.deferredActions == [.organizeImports, .fixAll])
        #expect(result.changed)
    }

    @Test
    func statusMessageCatalogBuildsExpectedMessages() {
        #expect(
            EditorStatusMessageCatalog.externalFileChangedOnDisk(fileName: "README.md")
                == "README.md changed on disk. Reload or keep the editor version."
        )
        #expect(
            EditorStatusMessageCatalog.externalFileChangedOnDisk(isProjectFile: true)
                == "project.pbxproj changed on disk. Prefer the project version or keep the Lumi version before saving again."
        )
        #expect(EditorStatusMessageCatalog.saveFailed("Disk full") == "Save failed. Disk full")
        #expect(EditorStatusMessageCatalog.fileNotFound() == "Save failed. The file no longer exists on disk.")
    }

    @Test
    func stateSupportTypesAndOverlayModelsRemainStable() {
        let bracketMatch = BracketMatchResult(openOffset: 2, closeOffset: 8)
        #expect(bracketMatch.ranges == [
            NSRange(location: 2, length: 1),
            NSRange(location: 8, length: 1),
        ])

        let hoverPlacement = EditorHoverOverlayPlacement(
            anchor: .topLeading,
            origin: CGPoint(x: 12, y: 24),
            cardSize: CGSize(width: 200, height: 80),
            isPresentedAboveSymbol: true
        )
        #expect(hoverPlacement.isPresentedAboveSymbol)

        let codeActionPlacement = EditorCodeActionIndicatorPlacement(
            origin: CGPoint(x: 10, y: 20),
            panelOrigin: CGPoint(x: 28, y: 20)
        )
        #expect(codeActionPlacement.panelOrigin.x == 28)
        #expect(EditorInlinePresentationKind.message(.warning) == .message(.warning))
        #expect(EditorSurfaceHighlightKind.hoverSymbol == .hoverSymbol)
    }

    @Test
    func gutterDecorationModelsPreserveKindsAndDefaults() {
        let context = EditorGutterDecorationContext(
            languageId: "swift",
            currentLine: 10,
            visibleLineRange: 5..<20,
            renderLineRange: 0..<40,
            isLargeFileMode: false
        )
        #expect(context.currentLine == 10)

        let suggestion = EditorGutterDecorationSuggestion(
            id: "diag-10",
            line: 10,
            kind: .diagnostic(.error),
            badgeText: "1"
        )
        #expect(suggestion.lane == 0)
        #expect(suggestion.priority == 0)
        #expect(suggestion.badgeText == "1")
        #expect(suggestion.kind == .diagnostic(.error))

        let symbolKind = EditorGutterDecorationKind.symbol(.class)
        #expect(symbolKind == .symbol(.class))
        #expect(EditorGutterDecorationKind.gitChange(.added) == .gitChange(.added))
    }

    @Test
    @MainActor
    func undoControllerAndManagerMaintainUndoRedoStacks() {
        let controller = EditorUndoController()
        let manager = EditorUndoManager()
        let before = controller.captureState(
            currentText: "alpha",
            selections: [.init(range: .init(location: 0, length: 0))]
        )
        let after = controller.captureState(
            currentText: "beta",
            selections: [.init(range: .init(location: 2, length: 0))]
        )

        let flags = controller.recordChange(
            in: manager,
            from: before,
            to: after,
            reason: "typing",
            isRestoringUndoState: false
        )
        #expect(flags.canUndo)
        #expect(!flags.canRedo)

        let undone = controller.performUndo(in: manager)
        #expect(undone?.state == before)
        #expect(!(undone?.canUndo ?? true))
        #expect(undone?.canRedo == true)

        let redone = controller.performRedo(in: manager)
        #expect(redone?.state == after)
        #expect(redone?.canUndo == true)
        #expect(redone?.canRedo == false)
    }

    @Test
    func editorBufferAppliesTransactionsAndPreservesSelectionPassThrough() {
        let buffer = EditorBuffer(text: "alpha beta gamma")
        let result = buffer.apply(
            EditorTransaction(
                replacements: [
                    .init(range: .init(location: 11, length: 5), text: "delta"),
                    .init(range: .init(location: 0, length: 5), text: "omega"),
                ]
            )
        )
        #expect(result?.snapshot.text == "omega beta delta")
        #expect(result?.snapshot.version == 1)

        let emptyResult = buffer.apply(
            EditorTransaction(
                replacements: [],
                updatedSelections: [.init(range: .init(location: 3, length: 0))]
            )
        )
        #expect(emptyResult?.snapshot.version == 1)
        #expect(emptyResult?.selections == [.init(range: .init(location: 3, length: 0))])
    }

    @Test
    func editorBufferRejectsInvalidRangeWithoutMutatingState() {
        let buffer = EditorBuffer(text: "abc")
        let result = buffer.apply(
            EditorTransaction(
                replacements: [.init(range: .init(location: 10, length: 1), text: "z")]
            )
        )
        #expect(result == nil)
        #expect(buffer.text == "abc")
        #expect(buffer.version == 0)
    }

    @Test
    func lineEditingControllerSupportsDeleteInsertSortAndTranspose() {
        let deleted = LineEditingController.deleteLine(
            in: "one\ntwo\nthree",
            selections: [NSRange(location: 4, length: 0)]
        )
        #expect(deleted?.replacementText == "one\nthree")

        let inserted = LineEditingController.insertLineBelow(
            in: "    alpha",
            selections: [NSRange(location: 4, length: 0)]
        )
        #expect(inserted?.replacementText == "    alpha\n    ")
        #expect(inserted?.selectedRanges.first == NSRange(location: 14, length: 0))

        let sorted = LineEditingController.sortLines(
            in: "b\na\n",
            selections: [NSRange(location: 0, length: 3)],
            descending: false
        )
        #expect(sorted?.replacementText == "a\nb\n")

        let transposed = LineEditingController.transpose(
            in: "ab",
            selections: [NSRange(location: 1, length: 0)]
        )
        #expect(transposed?.replacementText == "ba")
        #expect(transposed?.selectedRanges == [NSRange(location: 2, length: 0)])
    }

    @Test
    @MainActor
    func commandRegistryFiltersAndExecutesCommandsByContext() {
        let registry = CommandRegistry()
        defer { registry.clear() }

        var executed = false
        registry.register([
            .selectionCommand(
                id: "selection.only",
                title: "Selection Only",
                category: "editing"
            ) {
                executed = true
            },
            .command(
                id: "always.on",
                title: "Always On",
                category: "editing",
                order: 1
            ) {}
        ])

        var context = CommandContext()
        context.hasSelection = false
        #expect(registry.availableCommands(in: context).map(\.id) == ["always.on"])
        #expect(!registry.execute(id: "selection.only", context: context))

        context.hasSelection = true
        #expect(registry.availableCommands(in: context).map(\.id) == ["selection.only", "always.on"])
        #expect(registry.execute(id: "selection.only", context: context))
        #expect(executed)
    }

    @Test
    @MainActor
    func transactionControllerBuildsCompletionAndCommitPayloads() {
        let controller = EditorTransactionController()

        #expect(
            controller.transactionForInputEdit(
                replacementRange: NSRange(location: NSNotFound, length: 0),
                replacementText: "x",
                selectedRanges: []
            ) == nil
        )

        let completion = controller.transactionForCompletionEdit(
            text: "name",
            replacementRange: NSRange(location: 0, length: 4),
            replacementText: "value",
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
        #expect(completion?.replacements.count == 2)
        #expect(completion?.updatedSelections == [.init(range: .init(location: 9, length: 0))])

        let payload = controller.commitPayload(
            from: EditorEditResult(
                snapshot: .init(text: "a\nb\n", version: 4),
                selections: [
                    .init(range: .init(location: 2, length: 1)),
                    .init(range: .init(location: 5, length: 0)),
                ]
            )
        )
        #expect(payload.text == "a\nb\n")
        #expect(payload.version == 4)
        #expect(payload.totalLines == 3)
        #expect(
            payload.canonicalSelectionSet
                == EditorSelectionSet(
                    selections: [
                        .init(range: .init(location: 2, length: 1)),
                        .init(range: .init(location: 5, length: 0)),
                    ]
                )
        )
        #expect(
            payload.multiCursorSelections == [
                .init(location: 2, length: 1),
                .init(location: 5, length: 0),
            ]
        )
    }

    @Test
    @MainActor
    func editorPerformanceCollectsSummariesAndSlowEvents() {
        let performance = EditorPerformance()
        performance.clear()

        _ = performance.measure(.editTransaction) {}
        let slowToken = performance.begin(.renderBracketMatch)
        performance.end(slowToken, metadata: ["reason": "manual"])

        let summary = performance.summary(for: .editTransaction)
        #expect(summary?.count == 1)
        #expect(summary?.event == .editTransaction)

        let report = performance.report()
        #expect(report.contains("Editor Performance Report"))
        #expect(report.contains("edit.transaction"))
    }

    @Test
    func externalFileReloadPolicyChoosesConflictOrApplyBasedOnDirtyState() {
        let modDate = Date(timeIntervalSince1970: 123)
        #expect(
            EditorExternalFileReloadPolicy.reloadDecision(
                newContent: "same",
                currentContent: "same",
                currentModDate: modDate,
                hasUnsavedChanges: false
            ) == .unchanged
        )
        #expect(
            EditorExternalFileReloadPolicy.reloadDecision(
                newContent: "new",
                currentContent: "old",
                currentModDate: modDate,
                hasUnsavedChanges: true
            ) == .registerConflict(content: "new", modificationDate: modDate)
        )
        #expect(
            EditorExternalFileReloadPolicy.reloadDecision(
                newContent: "new",
                currentContent: "old",
                currentModDate: modDate,
                hasUnsavedChanges: false
            ) == .applyExternalContent(content: "new", modificationDate: modDate)
        )
    }

    @Test
    func saveWorkflowPolicyGuardsAutosaveAndDuplicateSaveRuns() {
        #expect(EditorSaveWorkflowPolicy.shouldSaveNowIfNeeded(hasUnsavedChanges: true))
        #expect(!EditorSaveWorkflowPolicy.shouldSaveNowIfNeeded(hasUnsavedChanges: false))
        #expect(EditorSaveWorkflowPolicy.shouldRunSaveTask(isSaving: false))
        #expect(!EditorSaveWorkflowPolicy.shouldRunSaveTask(isSaving: true))
    }

    @Test
    @MainActor
    func editorCommandCategoryAndPresentationRemainStable() {
        #expect(EditorCommandCategory.resolve("find") == .find)
        #expect(EditorCommandCategory.resolve("missing") == .other)
        #expect(EditorCommandCategory.orderIndex(for: "edit") < EditorCommandCategory.orderIndex(for: "other"))

        let suggestions = [
            EditorCommandSuggestion(
                id: "go.definition",
                title: "Go to Definition",
                systemImage: "arrow.turn.down.right",
                category: "navigation",
                shortcut: .init(key: "b", modifiers: [.command]),
                order: 2,
                isEnabled: true,
                action: {}
            ),
            EditorCommandSuggestion(
                id: "find.replace",
                title: "Replace",
                systemImage: "text.magnifyingglass",
                category: "find",
                shortcut: .init(key: "h", modifiers: [.option, .command]),
                order: 1,
                isEnabled: true,
                action: {}
            ),
            EditorCommandSuggestion(
                id: "format.document",
                title: "Format Document",
                systemImage: "textformat",
                category: "format",
                shortcut: .init(key: "i", modifiers: [.shift, .option]),
                order: 0,
                isEnabled: true,
                action: {}
            ),
        ]

        let model = EditorCommandPresentationModel.build(
            from: suggestions,
            recentCommandIDs: ["find.replace"],
            commandUsageCounts: ["go.definition": 3],
            query: ""
        )

        #expect(model.recentCommands.map(\.id) == ["find.replace"])
        #expect(model.frequentCommands.map(\.id) == ["go.definition"])
        #expect(model.sections.map(\.category) == [.format])
        #expect(model.flattenedCommands.map(\.id) == ["find.replace", "go.definition", "format.document"])
    }

    @Test
    @MainActor
    func editorCommandPresentationFiltersByShortcutAndCategoryScope() {
        let suggestions = [
            EditorCommandSuggestion(
                id: "find.replace",
                title: "Replace",
                systemImage: "text.magnifyingglass",
                category: "find",
                shortcut: .init(key: "h", modifiers: [.option, .command]),
                order: 1,
                isEnabled: true,
                action: {}
            ),
            EditorCommandSuggestion(
                id: "format.document",
                title: "Format Document",
                systemImage: "textformat",
                category: "format",
                shortcut: .init(key: "i", modifiers: [.shift, .option]),
                order: 0,
                isEnabled: true,
                action: {}
            ),
            EditorCommandSuggestion(
                id: "lsp.rename",
                title: "Rename Symbol",
                systemImage: "pencil",
                category: "lsp",
                order: 2,
                isEnabled: true,
                action: {}
            ),
        ]

        let byShortcut = EditorCommandPresentationModel.build(
            from: suggestions,
            recentCommandIDs: [],
            query: "⇧⌥I"
        )
        #expect(byShortcut.flattenedCommands.map(\.id) == ["format.document"])

        let onlyLSP = EditorCommandPresentationModel.build(
            from: suggestions,
            recentCommandIDs: [],
            allowedCategories: EditorCommandCategoryScope.lspActions
        )
        #expect(Set(onlyLSP.flattenedCommands.map(\.id)) == ["format.document", "lsp.rename"])
        #expect(EditorCommandCategoryScope.editorContextMenu.contains(.chat))
        #expect(EditorCommandCategoryScope.editorContextMenu.contains(.save) == false)
    }

    @Test
    @MainActor
    func quickOpenQueryParserParsesScopedQueries() {
        let documentSymbols = EditorQuickOpenQueryParser.parse("@ methods")
        #expect(documentSymbols.scope == .documentSymbols)
        #expect(documentSymbols.searchText == "methods")
        #expect(documentSymbols.hasExplicitScope == true)

        let workspaceSymbols = EditorQuickOpenQueryParser.parse("# service")
        #expect(workspaceSymbols.scope == .workspaceSymbols)
        #expect(workspaceSymbols.searchText == "service")

        let commands = EditorQuickOpenQueryParser.parse("> format")
        #expect(commands.scope == .commands)
        #expect(commands.searchText == "format")

        let line = EditorQuickOpenQueryParser.parse(":12:7")
        #expect(line.scope == .line)
        #expect(line.line == 12)
        #expect(line.column == 7)
    }

    @Test
    @MainActor
    func quickOpenQueryParserDefaultsToFileSearchForPlainQuery() {
        let query = EditorQuickOpenQueryParser.parse("  AppDelegate  ")

        #expect(query.scope == .files)
        #expect(query.searchText == "AppDelegate")
        #expect(query.hasExplicitScope == false)
        #expect(query.line == nil)
        #expect(query.column == nil)
    }

    @Test
    func largeFileModeThresholdsAndFeatureFlagsRemainStable() {
        #expect(LargeFileMode.mode(for: 0) == .normal)
        #expect(LargeFileMode.mode(for: LargeFileMode.mediumThreshold) == .medium)
        #expect(LargeFileMode.mode(for: LargeFileMode.largeThreshold) == .large)
        #expect(LargeFileMode.mode(for: LargeFileMode.megaThreshold) == .mega)

        #expect(LargeFileMode.medium.isSemanticTokensDisabled == true)
        #expect(LargeFileMode.medium.isInlayHintsDisabled == false)
        #expect(LargeFileMode.large.isMinimapDisabled == true)
        #expect(LargeFileMode.mega.isReadOnly == true)
    }

    @Test
    func longLineDetectorAndMinimapPolicyRemainStable() {
        #expect(LongLineDetector.findLongestLine(in: "short\nline", limit: 10) == nil)
        #expect(LongLineDetector.findLongestLine(in: "ok\n123456", limit: 6) == .init(line: 1, length: 6))

        let visible = EditorMinimapPolicy(userRequestedVisible: true, largeFileMode: .normal)
        #expect(visible.isVisible == true)
        #expect(visible.statusTitle == "Minimap On")

        let gated = EditorMinimapPolicy(userRequestedVisible: true, largeFileMode: .large)
        #expect(gated.isForcedHidden == true)
        #expect(gated.isVisible == false)
        #expect(gated.statusTitle == "Minimap Gated")
    }

    @Test
    func viewportFeaturePolicyRemainsStable() {
        #expect(EditorViewportFeaturePolicy.isViewportFeatureEnabled(viewportRange: 0..<0, maxLine: 1_000) == true)
        #expect(EditorViewportFeaturePolicy.isViewportFeatureEnabled(viewportRange: 500..<800, maxLine: 1_000) == true)
        #expect(EditorViewportFeaturePolicy.isViewportFeatureEnabled(viewportRange: 1_000..<1_200, maxLine: 1_000) == false)

        #expect(
            EditorViewportFeaturePolicy.isLongLineProtectionSuppressingSyntaxHighlighting(
                largeFileMode: .large,
                longestDetectedLine: .init(line: 8, length: 20_000)
            ) == true
        )
        #expect(
            EditorViewportFeaturePolicy.isLongLineProtectionSuppressingSyntaxHighlighting(
                largeFileMode: .medium,
                longestDetectedLine: .init(line: 8, length: 20_000)
            ) == false
        )
        #expect(
            EditorViewportFeaturePolicy.isViewportSyntaxFeatureEnabled(
                viewportRange: 0..<100,
                maxLine: 10_000,
                largeFileMode: .large,
                longestDetectedLine: .init(line: 3, length: 15_000)
            ) == false
        )
        #expect(
            EditorViewportFeaturePolicy.isViewportSyntaxFeatureEnabled(
                viewportRange: 200..<400,
                maxLine: 1_000,
                largeFileMode: .medium,
                longestDetectedLine: nil
            ) == true
        )
    }

    @Test
    func inlineRenameStatePreviewFlagsRemainStable() {
        var state = EditorInlineRenameState(
            originalName: "name",
            draftName: " renamed ",
            isLoadingPreview: false,
            errorMessage: "stale",
            previewSummary: .init(changedFiles: 1, changedLocations: 2, fileLabels: ["Current File"]),
            previewEdit: WorkspaceEdit(changes: [:], documentChanges: nil)
        )

        #expect(state.trimmedDraftName == "renamed")
        #expect(state.canPreview == true)
        #expect(state.canApply == true)

        state.invalidatePreview()
        #expect(state.errorMessage == nil)
        #expect(state.previewSummary == nil)
        #expect(state.previewEdit == nil)
        #expect(state.canApply == false)
    }

    @Test
    func workspaceEditSummaryBuilderSummarizesCurrentAndExternalEdits() {
        let edit = WorkspaceEdit(
            changes: [
                "file:///tmp/project/file.swift": [
                    TextEdit(
                        range: LSPRange(start: Position(line: 0, character: 0), end: Position(line: 0, character: 1)),
                        newText: "a"
                    )
                ]
            ],
            documentChanges: [
                .textDocumentEdit(
                    TextDocumentEdit(
                        textDocument: VersionedTextDocumentIdentifier(uri: "file:///tmp/project/other.swift", version: 1),
                        edits: [
                            TextEdit(
                                range: LSPRange(start: Position(line: 1, character: 0), end: Position(line: 1, character: 2)),
                                newText: "bb"
                            )
                        ]
                    )
                ),
                .deleteFile(
                    DeleteFile(
                        kind: "delete",
                        uri: "file:///tmp/project/old.swift",
                        options: .init(recursive: false, ignoreIfNotExists: false)
                    )
                ),
            ]
        )

        let summary = EditorWorkspaceEditSummaryBuilder.summarize(
            edit,
            currentURI: "file:///tmp/project/file.swift",
            projectRootPath: "/tmp/project"
        )

        #expect(summary.changedFiles == 3)
        #expect(summary.changedLocations == 3)
        #expect(summary.fileLabels == ["Current File", "other.swift", "old.swift"])
        #expect(summary.summaryText == "3 changes in 3 files")
    }

    @Test
    @MainActor
    func saveStateAndControllerRemainStable() {
        #expect(EditorSaveState.saved.icon == "checkmark.circle.fill")
        #expect(EditorSaveState.error("x").icon == "exclamationmark.triangle.fill")

        let controller = EditorSaveStateController()
        var persisted: String?
        var hasUnsavedChanges = true
        var saveState: EditorSaveState = .editing
        var clearedConflict = false
        var synced = false
        var scheduledClear = false
        var notifiedContent: String?

        controller.applySaveSuccess(
            content: "hello",
            markPersistedText: { persisted = $0 },
            clearConflict: { clearedConflict = true },
            syncSession: { synced = true },
            scheduleSuccessClear: { scheduledClear = true },
            notifyDidSave: { notifiedContent = $0 },
            setHasUnsavedChanges: { hasUnsavedChanges = $0 },
            setSaveState: { saveState = $0 }
        )

        #expect(persisted == "hello")
        #expect(hasUnsavedChanges == false)
        #expect(clearedConflict == true)
        #expect(synced == true)
        #expect(scheduledClear == true)
        #expect(notifiedContent == "hello")
        #expect(saveState == .saved)
    }

    @Test
    @MainActor
    func appearanceAndDocumentReplaceControllersRemainStable() {
        let appearance = EditorAppearanceController()
        #expect(appearance.syncThemeSilently(currentThemeId: "a", incomingThemeId: "a") == false)
        #expect(appearance.syncThemeSilently(currentThemeId: "a", incomingThemeId: "b") == true)

        let transactionController = EditorTransactionController()
        let controller = EditorDocumentReplaceController()
        let payload = controller.replaceTextPayload(
            "updated",
            replaceText: { text in
                EditorEditResult(
                    snapshot: EditorSnapshot(text: text, version: 4),
                    selections: [
                        EditorSelection(range: EditorRange(location: text.utf16.count, length: 0))
                    ]
                )
            },
            transactionController: transactionController
        )

        #expect(payload.commitPayload.text == "updated")
        #expect(payload.commitPayload.version == 4)
        #expect(payload.commitPayload.totalLines == 1)
        #expect(payload.commitPayload.canonicalSelectionSet?.primary?.range.location == 7)
        #expect(payload.commitPayload.multiCursorSelections == [.init(location: 7, length: 0)])
        #expect(EditorCursorState.initial.primary?.range.location == 0)
    }

    @Test
    func multiCursorStateAndStateControllerRemainStable() {
        var state = MultiCursorState()
        state.addSecondary(.init(location: 8, length: 1))
        state.addSecondary(.init(location: 3, length: 0))

        #expect(state.isEnabled == true)
        #expect(state.all == [
            .init(location: 0, length: 0),
            .init(location: 3, length: 0),
            .init(location: 8, length: 1),
        ])

        let rebuilt = EditorMultiCursorStateController.state(from: state.all)
        #expect(rebuilt == state)
        #expect(EditorMultiCursorStateController.clearSecondary(from: state).all == [.init(location: 0, length: 0)])
    }

    @Test
    func multiCursorMatcherAndSearchControllerRemainStable() {
        let text = "cat concatenate cat" as NSString
        let matches = EditorMultiCursorMatcher.ranges(of: "cat", in: text)
        #expect(matches == [
            .init(location: 0, length: 3),
            .init(location: 16, length: 3),
        ])

        let context = EditorMultiCursorMatcher.searchContext(
            from: NSRange(location: 0, length: 0),
            in: text
        )
        #expect(context?.query == "cat")

        let session = EditorMultiCursorSearchController.session(for: context!)
        let next = EditorMultiCursorSearchController.nextSelection(
            in: matches,
            currentState: MultiCursorState(primary: .init(location: 0, length: 3), secondary: []),
            session: session
        )
        #expect(next == .init(location: 16, length: 3))

        let collapsed = EditorMultiCursorSearchController.collapsedSession(
            from: EditorMultiCursorSearchController.appending(.init(location: 16, length: 3), to: session),
            singleSelection: .init(location: 0, length: 3),
            in: text
        )
        #expect(collapsed?.history == [.init(location: 0, length: 3)])
    }

    @Test
    @MainActor
    func multiCursorWorkflowControllerRemainsStable() {
        let controller = EditorMultiCursorWorkflowController()
        let text = "cat concatenate cat" as NSString

        let next = controller.addNextOccurrenceResult(
            from: NSRange(location: 0, length: 0),
            currentState: .init(),
            existingSession: nil,
            text: text
        )

        #expect(next?.state.all == [
            .init(location: 0, length: 3),
            .init(location: 16, length: 3),
        ])
        #expect(next?.session?.history == [
            .init(location: 0, length: 3),
            .init(location: 16, length: 3),
        ])
        #expect(next?.logAction == "addNextOccurrence.added")

        let all = controller.addAllOccurrencesResult(
            from: NSRange(location: 0, length: 0),
            currentState: .init(),
            text: text
        )
        #expect(all?.state.all == [
            .init(location: 0, length: 3),
            .init(location: 16, length: 3),
        ])

        let removed = controller.removeLastOccurrenceResult(
            currentState: all!.state,
            existingSession: all!.session
        )
        #expect(removed?.state.all == [.init(location: 0, length: 3)])
    }

    @Test
    @MainActor
    func multiCursorControllerBuildsTransactionsAndSessions() {
        let controller = EditorMultiCursorController()
        let text = "cat dog" as NSString
        let state = MultiCursorState(
            primary: .init(location: 0, length: 3),
            secondary: [.init(location: 4, length: 3)]
        )

        #expect(controller.nsRanges(from: state) == [
            NSRange(location: 0, length: 3),
            NSRange(location: 4, length: 3),
        ])

        let replacement = controller.replacementResult(
            text: text as String,
            selections: state.all,
            replacement: "x"
        )
        #expect(replacement.result.text == "x x")
        #expect(replacement.transaction.replacements.count == 2)

        let context = controller.allOccurrencesContext(
            from: NSRange(location: 0, length: 0),
            in: text
        )
        #expect(context?.query == "cat")

        let session = controller.startedSession(for: context!)
        let collapsed = controller.collapsedSession(
            from: controller.appending(.init(location: 0, length: 3), to: session),
            singleSelection: .init(location: 0, length: 3),
            in: text
        )
        #expect(collapsed?.history == [.init(location: 0, length: 3)])
    }

    @Test
    @MainActor
    func shortcutCatalogPolicyFiltersAndDetectsConflicts() {
        let commands: [EditorShortcutDefinition] = [
            .init(
                id: "builtin.find",
                title: "Find",
                category: .find,
                defaultShortcut: .init(key: "f", modifiers: [.command])
            ),
            .init(
                id: "builtin.rename",
                title: "Rename Symbol",
                category: .navigation,
                defaultShortcut: .init(key: "r", modifiers: [.control, .command])
            ),
        ]
        let customBindings = [
            "builtin.find": EditorKeybindingEntry(
                commandID: "builtin.find",
                key: "g",
                modifiers: [.command, .shift]
            )
        ]

        let filtered = EditorShortcutCatalogPolicy.filteredCommands(
            commands,
            query: "⌘⇧G",
            category: nil,
            customBindings: customBindings
        )
        #expect(filtered.map(\.id) == ["builtin.find"])

        let conflicts = EditorShortcutCatalogPolicy.conflicts(
            in: commands,
            for: "builtin.rename",
            candidate: .init(key: "g", modifiers: [.shift, .command]),
            customBindings: customBindings
        )
        #expect(conflicts.map(\.id) == ["builtin.find"])
    }

    @Test
    @MainActor
    func selectionMappingPolicyNormalizesRangesAndGuardsMultiCursorLoss() {
        let canonical = EditorSelectionMappingPolicy.canonicalSelectionSet(
            from: [
                NSRange(location: 8, length: 1),
                NSRange(location: NSNotFound, length: 0),
                NSRange(location: 2, length: 0),
            ]
        )
        #expect(canonical?.selections == [
            .init(range: .init(location: 2, length: 0)),
            .init(range: .init(location: 8, length: 1)),
        ])

        let currentState = EditorSelectionSet(selections: [
            .init(range: .init(location: 2, length: 0)),
            .init(range: .init(location: 8, length: 1)),
        ])
        let viewSelections = EditorSelectionSet(selections: [
            .init(range: .init(location: 2, length: 0)),
        ])
        #expect(
            EditorSelectionMappingPolicy.shouldAcceptCanonicalUpdate(
                viewSelections: viewSelections,
                currentState: currentState
            ) == false
        )
        #expect(
            EditorSelectionMappingPolicy.rangesAreEqual(
                EditorSelectionMappingPolicy.targetViewRanges(for: currentState),
                [NSRange(location: 2, length: 0), NSRange(location: 8, length: 1)]
            ) == true
        )
    }

    @Test
    @MainActor
    func peekControllerBuildsDefinitionPresentationFromCurrentBuffer() {
        let fileURL = URL(fileURLWithPath: "/tmp/EditorKernelCorePeek.swift")
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

        #expect(presentation?.mode == .definition)
        #expect(presentation?.summary == "EditorKernelCorePeek.swift:2:5")
        #expect(presentation?.items.first?.preview == "value")
        #expect(presentation?.items.first?.target == .init(
            url: fileURL,
            line: 2,
            column: 5,
            highlightLine: true
        ))
    }

    @Test
    @MainActor
    func settingsQuickOpenPolicyFiltersAndSortsMatchingItems() {
        let items: [EditorSettingsQuickOpenSearchItem] = [
            .init(
                id: "editor.font-size",
                title: "Font Size",
                subtitle: "Editor typography",
                keywords: ["font", "typography"],
                sectionTitle: "Display"
            ),
            .init(
                id: "editor.format-on-save",
                title: "Format On Save",
                subtitle: "Save pipeline",
                keywords: ["format", "save"],
                sectionTitle: "Save"
            ),
        ]

        let matches = EditorSettingsQuickOpenPolicy.matchingItems(items, query: "save")
        #expect(matches.map(\.id) == ["editor.format-on-save"])

        let fontMatches = EditorSettingsQuickOpenPolicy.matchingItems(items, query: "font")
        #expect(fontMatches.map(\.id) == ["editor.font-size"])
    }

    @Test
    @MainActor
    func workspaceSearchPolicyParsesRipgrepOutputAndFormatsMarkdown() {
        let output = """
        {"type":"match","data":{"path":{"text":"/tmp/project/Sources/App.swift"},"lines":{"text":"let value = 1"},"line_number":3,"submatches":[{"start":4}]}}
        {"type":"match","data":{"path":{"text":"/tmp/project/Tests/AppTests.swift"},"lines":{"text":"value should equal 1"},"line_number":8,"submatches":[{"start":0}]}}
        """

        let response = EditorWorkspaceSearchPolicy.parse(
            output: output,
            query: "value",
            projectRootPath: "/tmp/project",
            limit: 200
        )

        #expect(response.summary == .init(query: "value", totalMatches: 2, totalFiles: 2))
        #expect(response.fileResults.map(\.path) == ["Sources/App.swift", "Tests/AppTests.swift"])
        #expect(response.fileResults.first?.matches.first?.column == 5)

        let markdown = EditorWorkspaceSearchPolicy.markdownContent(
            summary: response.summary,
            fileResults: response.fileResults
        )
        #expect(markdown.contains("# Search Results"))
        #expect(markdown.contains("## Sources/App.swift"))
        #expect(markdown.contains("`L3:C5` let value = 1"))
    }

    @Test
    @MainActor
    func statusToastPolicyNormalizesDurationsByLevel() {
        let info = EditorStatusToastPolicy.presentation(level: .info, duration: 0.2)
        #expect(info == .init(level: .info, duration: 1.0, autoDismiss: false))

        let warning = EditorStatusToastPolicy.presentation(level: .warning, duration: 1.2)
        #expect(warning == .init(level: .warning, duration: 2.0, autoDismiss: false))

        let error = EditorStatusToastPolicy.presentation(level: .error, duration: 3.0)
        #expect(error == .init(level: .error, duration: 3.0, autoDismiss: true))
    }
}
