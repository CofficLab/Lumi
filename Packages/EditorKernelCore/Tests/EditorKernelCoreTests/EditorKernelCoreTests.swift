import Foundation
import LanguageServerProtocol
import Testing
@testable import EditorKernelCore

struct EditorKernelCoreTests {
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
}
