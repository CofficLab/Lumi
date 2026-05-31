import Foundation
import LanguageServerProtocol
import Testing
@testable import EditorKernel

struct EditorKernelTests {
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
    func configModelsNormalizeScopesAndApplyOverrides() {
        let context = EditorConfigContext(
            workspacePath: " /tmp/project/../project ",
            languageId: " Swift "
        )
        #expect(context.normalizedWorkspacePath == "/tmp/project")
        #expect(context.normalizedLanguageId == "swift")

        let scope = EditorConfigOverrideScope.language(" TypeScript ")
        #expect(scope.normalizedKey == "typescript")

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
        let overrideSnapshot = EditorScopedOverrideSnapshot(
            tabWidth: 2,
            useSpaces: false,
            wrapLines: false,
            formatOnSave: true
        )
        let resolved = overrideSnapshot.applying(to: base)
        #expect(resolved.tabWidth == 2)
        #expect(resolved.useSpaces == false)
        #expect(resolved.wrapLines == false)
        #expect(resolved.formatOnSave == true)
    }

    @Test
    func configPersistencePolicyResolvesScopesAndEncodesOverrides() {
        let global = EditorConfigSnapshot(
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
        let scoped = EditorScopedConfigSnapshot(
            global: global,
            workspaceOverrides: ["/tmp/project": .init(tabWidth: 2)],
            languageOverrides: ["swift": .init(useSpaces: false, formatOnSave: true)]
        )

        let resolved = EditorConfigPersistencePolicy.resolveConfig(
            for: .init(workspacePath: "/tmp/project", languageId: "SWIFT"),
            scoped: scoped
        )
        #expect(resolved.tabWidth == 2)
        #expect(resolved.useSpaces == false)
        #expect(resolved.formatOnSave)

        let overrideSnapshot = EditorConfigPersistencePolicy.overrideSnapshot(
            in: scoped,
            for: .language("swift")
        )
        #expect(overrideSnapshot.useSpaces == false)

        let updated = EditorConfigPersistencePolicy.updating(
            scoped,
            overrideSnapshot: .init(wrapLines: false),
            for: .workspace("/tmp/project")
        )
        #expect(updated.workspaceOverrides["/tmp/project"]?.wrapLines == false)

        let encoded = EditorConfigPersistencePolicy.encodeOverrideMap(updated.workspaceOverrides)
        let decoded = EditorConfigPersistencePolicy.decodeOverrideMap(encoded)
        #expect(decoded["/tmp/project"]?.wrapLines == false)
    }

    @Test
    func referenceResultBuildsStableIdentifiersFromCanonicalPaths() {
        let result = ReferenceResult(
            url: URL(fileURLWithPath: "/tmp/project/../project/File.swift"),
            line: 12,
            column: 4,
            path: "Sources/File.swift",
            preview: "let value = 1"
        )

        #expect(result.id == "/tmp/project/File.swift#12:4:let value = 1")
        #expect(result.stableIdentifier == result.id)
    }

    @Test
    func editorReferenceResultBuildsStableIdentifiersFromCanonicalPaths() {
        let result = EditorReferenceResult(
            url: URL(fileURLWithPath: "/tmp/project/../project/File.swift"),
            line: 8,
            column: 2,
            path: "Sources/File.swift",
            preview: "callSite()"
        )

        #expect(result.id == "/tmp/project/File.swift#8:2:callSite()")
        #expect(result.stableIdentifier == result.id)
    }

    @Test
    func foldingStateTracksCollapsedRangesAndEmptyState() {
        let range = EditorFoldingState.CollapsedRange(
            startLine: 3,
            endLine: 9,
            kind: .region
        )
        let state = EditorFoldingState(collapsedRanges: [range])

        #expect(state.isEmpty == false)
        #expect(state.collapsedRanges.contains(range))
    }

    @Test
    func semanticModelsPreserveSeverityReasonAndProblemProjection() {
        let reason = EditorSemanticAvailabilityReason(
            id: "missing-index",
            severity: .warning,
            title: "Missing Index",
            message: "Index metadata is unavailable.",
            suggestion: "Open the workspace in Xcode once."
        )
        let report = EditorSemanticAvailabilityReport(reasons: [reason])
        let problem = EditorSemanticProblem(reason: reason)
        let error = EditorLanguageFeatureError(
            domain: "xcode.semantic",
            code: "missing-index",
            message: "Index metadata is unavailable.",
            suggestion: "Open the workspace in Xcode once."
        )

        #expect(report.reasons == [reason])
        #expect(problem.id == reason.id)
        #expect(problem.severity == .warning)
        #expect(problem.title == reason.title)
        #expect(problem.message == reason.message)
        #expect(error.errorDescription == "Index metadata is unavailable.")
        #expect(error.recoverySuggestion == "Open the workspace in Xcode once.")
    }

    @Test
    func panelSessionStateDefaultsAndSnapshotStayInSync() {
        let state = EditorPanelSessionState(
            isOpenEditorsPanelPresented: true,
            isReferencePanelPresented: true,
            isWorkspaceSearchPresented: true,
            isCallHierarchyPresented: false,
            isProblemsPanelPresented: false
        )

        #expect(state.referenceResults.isEmpty)
        #expect(state.semanticProblems.isEmpty)
        #expect(state.snapshot == EditorPanelSnapshot(
            isOpenEditorsPanelPresented: true,
            isOutlinePanelPresented: false,
            isProblemsPanelPresented: false,
            isReferencePanelPresented: true,
            isWorkspaceSearchPresented: true,
            isWorkspaceSymbolSearchPresented: false,
            isCallHierarchyPresented: false
        ))
    }

    @Test
    func projectContextModelsExposeStatusDescriptionsAndSnapshotFields() {
        let snapshot = EditorProjectContextSnapshot(
            projectPath: "/tmp/App",
            workspaceName: "App",
            workspacePath: "/tmp/App",
            activeScheme: "App",
            activeSchemeBuildableTargets: ["App"],
            activeConfiguration: "Debug",
            activeDestination: "My Mac",
            contextStatus: .available("Indexed"),
            isStructuredProject: true,
            schemes: ["App"],
            configurations: ["Debug", "Release"],
            currentFilePath: "/tmp/App/Sources/Foo.swift",
            currentFilePrimaryTarget: "App",
            currentFileMatchedTargets: ["App"],
            currentFileIsInTarget: true
        )

        #expect(snapshot.workspaceName == "App")
        #expect(snapshot.currentFilePrimaryTarget == "App")
        #expect(EditorProjectContextStatus.unknown.displayDescription == "未初始化")
        #expect(EditorProjectContextStatus.needsResync.displayDescription == "需要重新同步")
        #expect(EditorProjectContextStatus.available("Indexed").displayDescription == "Indexed")
    }

    @Test
    func configFileStorePersistsAndRemovesValues() throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store = EditorConfigFileStore(settingsDirectoryURL: root)
        let fileManager = FileManager.default

        store.saveDict(["fontSize": 14.0, "useSpaces": true], fileManager: fileManager)
        let loaded = store.loadDict(fileManager: fileManager)
        #expect(loaded["fontSize"] as? Double == 14.0)
        #expect(loaded["useSpaces"] as? Bool == true)

        store.savingValue(2, forKey: "tabWidth")
        #expect(store.loadingValue(forKey: "tabWidth", as: Int.self) == 2)

        store.removingValue(forKey: "tabWidth")
        #expect(store.loadingValue(forKey: "tabWidth", as: Int.self) == nil)

        try? fileManager.removeItem(at: root)
    }

    @Test
    func configFileStoreQuarantinesCorruptSettingsAndRecovers() throws {
        let root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let store = EditorConfigFileStore(settingsDirectoryURL: root)
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: root, withIntermediateDirectories: true)

        let invalidData = Data("not a plist".utf8)
        try invalidData.write(to: store.settingsFileURL())

        #expect(store.loadDict(fileManager: fileManager).isEmpty)
        #expect((try? Data(contentsOf: store.corruptSettingsFileURL())) == invalidData)

        store.savingValue(16.0, forKey: "fontSize")
        #expect(store.loadingValue(forKey: "fontSize", as: Double.self) == 16.0)

        let reloadedStore = EditorConfigFileStore(settingsDirectoryURL: root)
        #expect(reloadedStore.loadingValue(forKey: "fontSize", as: Double.self) == 16.0)
    }

    @Test
    @MainActor
    func saveControllerBuildsPipelineOptionsAndClearsSavedState() async {
        let controller = EditorSaveController(successDisplayDuration: 0.01)
        let options = controller.pipelineOptions(
            trimTrailingWhitespace: true,
            insertFinalNewline: true,
            formatOnSave: false,
            organizeImportsOnSave: true,
            fixAllOnSave: false
        )
        #expect(options.textParticipants.trimTrailingWhitespace == true)
        #expect(options.textParticipants.insertFinalNewline == true)
        #expect(options.organizeImportsOnSave == true)

        var isSaved = true
        var cleared = false
        controller.scheduleSuccessClear(
            isSavedState: { isSaved },
            clearState: {
                cleared = true
                isSaved = false
            }
        )

        try? await Task.sleep(for: .milliseconds(50))
        #expect(cleared == true)
        controller.cancelSuccessClear()
    }

    @Test
    @MainActor
    func formattingControllerFormatsAndPreparesSaveText() async {
        let controller = EditorFormattingController()
        let edit = TextEdit(
            range: LSPRange(start: Position(line: 0, character: 0), end: Position(line: 0, character: 3)),
            newText: "let"
        )

        var statuses: [EditorStatusLevel] = []
        var appliedReason: String?
        await controller.formatDocument(
            canPreview: true,
            isEditable: true,
            tabSize: 4,
            insertSpaces: true,
            requestFormatting: { _, _ in [edit] },
            applyTextEdits: { _, reason in appliedReason = reason },
            showStatus: { _, level, _ in statuses.append(level) }
        )
        #expect(statuses == [.info, .success])
        #expect(appliedReason == "lsp_format_document")

        let prepared = await controller.prepareSaveFormatting(
            text: "var value",
            tabSize: 4,
            insertSpaces: true,
            requestFormatting: { _, _ in [edit] }
        )
        #expect(prepared == "let value")
    }

    @Test
    @MainActor
    func commandSuggestionPolicyDeduplicatesAndTracksRecents() {
        let suggestions: [EditorCommandSuggestion] = [
            .init(id: "b", title: "Beta", systemImage: "b.circle", order: 2, isEnabled: true, action: {}),
            .init(id: "a", title: "Alpha", systemImage: "a.circle", order: 1, isEnabled: true, action: {}),
            .init(id: "a", title: "Alpha Duplicate", systemImage: "a.circle", order: 3, isEnabled: true, action: {}),
        ]

        let deduplicated = EditorCommandSuggestionPolicy.deduplicatingSuggestions(suggestions)
        #expect(deduplicated.map(\.id) == ["a", "b"])

        var recent = ["x", "y"]
        var usage = ["y": 2]
        EditorCommandSuggestionPolicy.recordExecution(
            id: "y",
            recentCommandIDs: &recent,
            commandUsageCounts: &usage
        )
        #expect(recent == ["y", "x"])
        #expect(usage["y"] == 3)
    }

    @Test
    @MainActor
    func commandRouterBridgeMapsRegistryCommandsAndFallsBackToLegacy() {
        let shared = CommandRegistry.shared
        shared.clear()
        defer { shared.unregister(id: "registry") }

        var handled = false
        shared.register([
            KernelEditorCommand(
                id: "registry",
                title: "Registry Command",
                icon: "star",
                shortcut: nil,
                category: "edit",
                order: 1,
                enablement: .always
            ) {
                handled = true
            }
        ])

        let suggestions = EditorCommandRouterBridge.suggestionsFromRegistry(in: CommandContext())
        #expect(suggestions.map(\.id) == ["registry"])

        #expect(
            EditorCommandRouterBridge.execute(
                id: "registry",
                in: CommandContext(),
                legacySuggestions: []
            ) == true
        )
        #expect(handled == true)

        var legacyHandled = false
        let legacy = EditorCommandSuggestion(
            id: "legacy",
            title: "Legacy",
            systemImage: "command",
            order: 1,
            isEnabled: true
        ) {
            legacyHandled = true
        }
        #expect(
            EditorCommandRouterBridge.execute(
                id: "legacy",
                in: CommandContext(),
                legacySuggestions: [legacy]
            ) == true
        )
        #expect(legacyHandled == true)
    }

    @Test
    @MainActor
    func commandRouterBridgeRegistersLegacySuggestionsAndMapsContext() {
        let shared = CommandRegistry.shared
        shared.clear()
        defer { shared.clear() }

        let legacy = EditorCommandSuggestion(
            id: "legacy",
            title: "Legacy",
            systemImage: "hammer",
            order: 10,
            isEnabled: true,
            action: {}
        )

        EditorCommandRouterBridge.registerSuggestions([legacy], category: "custom")

        let mapped = EditorCommandRouterBridge.commandContext(
            from: EditorCommandContext(
                languageId: "swift",
                hasSelection: true,
                line: 12,
                character: 7
            ),
            isEditorActive: true,
            isMultiCursor: false
        )

        let suggestions = EditorCommandRouterBridge.suggestionsFromRegistry(
            in: mapped,
            filterCategory: "custom"
        )
        #expect(suggestions.map(\.id) == ["legacy"])
        #expect(mapped.languageId == "swift")
        #expect(mapped.hasSelection)
        #expect(mapped.line == 12)
        #expect(mapped.character == 7)
        #expect(mapped.isEditorActive)
        #expect(mapped.isMultiCursor == false)
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
    func cursorWordMotionClampsStaleLocations() {
        #expect(CursorMotionController.moveWordLeft(location: 50, text: "foo bar").location == 4)
        #expect(CursorMotionController.moveWordRight(location: -10, text: "foo bar").location == 3)

        let leftDelete = CursorMotionController.deleteWordLeft(location: 50, text: "foo bar")
        #expect(leftDelete.location == 4)
        #expect(leftDelete.selectionRange == NSRange(location: 4, length: 3))

        let rightDelete = CursorMotionController.deleteWordRight(location: -10, text: "foo bar")
        #expect(rightDelete.location == 0)
        #expect(rightDelete.selectionRange == NSRange(location: 0, length: 3))
    }

    @Test
    func cursorLineAndParagraphMotionClampNegativeLocations() {
        let text = "abc\n\ndef"

        #expect(CursorMotionController.moveRight(location: -10, text: text).location == 1)
        #expect(CursorMotionController.moveToBeginningOfLine(location: -10, text: text).location == 0)
        #expect(CursorMotionController.moveToEndOfLine(location: -10, text: text).location == 3)
        #expect(CursorMotionController.smartHome(location: -10, text: "    value").location == 4)
        #expect(CursorMotionController.moveUp(location: -10, text: text, desiredColumn: nil).location == 0)
        #expect(CursorMotionController.moveDown(location: -10, text: text, desiredColumn: nil).location == 4)
        #expect(CursorMotionController.moveParagraphBackward(location: -10, text: text).location == 0)
        #expect(CursorMotionController.moveParagraphForward(location: -10, text: text).location == 4)
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
    func snippetParserSupportsMultiDigitShorthandPlaceholders() {
        let result = EditorSnippetParser.parse("${10:value} = $10$0")

        #expect(result.text == "value = value")
        #expect(result.groups == [
            .init(index: 10, ranges: [
                NSRange(location: 0, length: 5),
                NSRange(location: 8, length: 5),
            ])
        ])
        #expect(result.exitSelection == NSRange(location: 13, length: 0))
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
    func multiCursorEditEngineClampsOverflowingSelections() {
        let inserted = MultiCursorEditEngine.apply(
            text: "abc",
            selections: [.init(location: Int.max, length: 1)],
            operation: .insert("x")
        )

        #expect(inserted.text == "abcx")
        #expect(inserted.selections == [.init(location: 4, length: 0)])

        let indented = MultiCursorEditEngine.apply(
            text: "abc",
            selections: [.init(location: Int.max, length: 1)],
            operation: .indent("  ")
        )

        #expect(indented.text == "  abc")
        #expect(indented.selections == [.init(location: 5, length: 0)])
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
    func findReplaceControllerTreatsStaleSelectedIndexAsNoSelection() {
        let matches = [
            EditorFindMatch(range: .init(location: 0, length: 3), matchedText: "foo"),
            EditorFindMatch(range: .init(location: 8, length: 3), matchedText: "foo")
        ]

        #expect(EditorFindReplaceController.nextMatchIndex(in: matches, selectedMatchIndex: 5) == 0)
        #expect(EditorFindReplaceController.previousMatchIndex(in: matches, selectedMatchIndex: 5) == 1)
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
    func quickOpenFilePolicyRejectsSiblingProjectWithSharedPrefix() {
        let fileURL = URL(fileURLWithPath: "/tmp/Lumi2/Sources/App/Main.swift")
        #expect(EditorQuickOpenFilePolicy.relativePath(for: fileURL, projectRootPath: "/tmp/Lumi") == "Main.swift")
    }

    @Test
    func quickOpenFilePolicyTrimsCopiedProjectRootPath() {
        let fileURL = URL(fileURLWithPath: "/tmp/Lumi/Sources/App/Main.swift")
        #expect(
            EditorQuickOpenFilePolicy.relativePath(
                for: fileURL,
                projectRootPath: " \n/tmp/Lumi/\t"
            ) == "Sources/App/Main.swift"
        )
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
    func lineEditingControllerMovesLineDownWithoutAddingTrailingNewline() {
        let moved = LineEditingController.moveLineDown(
            in: "one\ntwo\nthree",
            selections: [NSRange(location: 4, length: 0)]
        )

        #expect(moved?.replacementText == "one\nthree\ntwo")
        #expect(moved?.selectedRanges == [NSRange(location: 10, length: 0)])
    }

    @Test
    func lineEditingControllerRejectsStaleSelectionsWithoutCrashing() {
        let staleCursor = NSRange(location: 50, length: 0)
        let staleRange = NSRange(location: 1, length: 50)

        #expect(LineEditingController.deleteLine(in: "abc", selections: [staleCursor]) == nil)
        #expect(LineEditingController.copyLineUp(in: "abc", selections: [staleCursor]) == nil)
        #expect(LineEditingController.copyLineDown(in: "abc", selections: [staleCursor]) == nil)
        #expect(LineEditingController.moveLineUp(in: "abc", selections: [staleCursor]) == nil)
        #expect(LineEditingController.moveLineDown(in: "abc", selections: [staleCursor]) == nil)
        #expect(LineEditingController.insertLineAbove(in: "abc", selections: [staleCursor]) == nil)
        #expect(LineEditingController.insertLineBelow(in: "abc", selections: [staleCursor]) == nil)
        #expect(LineEditingController.sortLines(in: "abc", selections: [staleRange], descending: false) == nil)
        #expect(LineEditingController.toggleLineComment(in: "abc", selections: [staleCursor], commentPrefix: "//") == nil)
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
    func transactionControllerRejectsInvalidEditRanges() {
        let controller = EditorTransactionController()

        #expect(
            controller.transactionForInputEdit(
                replacementRange: NSRange(location: 0, length: -1),
                replacementText: "x",
                selectedRanges: []
            ) == nil
        )
        #expect(
            controller.transactionForInputEdit(
                replacementRange: NSRange(location: 0, length: 0),
                replacementText: "x",
                selectedRanges: [NSRange(location: Int.max, length: 1)]
            ) == nil
        )
        #expect(
            controller.transactionForCompletionEdit(
                text: "abc",
                replacementRange: NSRange(location: 2, length: 2),
                replacementText: "x",
                additionalTextEdits: nil
            ) == nil
        )
        #expect(
            controller.transactionForCompletionEdit(
                text: "abc",
                replacementRange: NSRange(location: Int.max, length: 1),
                replacementText: "x",
                additionalTextEdits: nil
            ) == nil
        )
        #expect(
            controller.transactionForSnippetEdit(
                text: "abc",
                replacementRange: NSRange(location: 1, length: -1),
                snippet: EditorSnippetParser.parse("$0"),
                additionalTextEdits: nil
            ) == nil
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
    @MainActor
    func externalFileWorkflowControllerDelegatesPollingAndConflictRegistration() {
        let controller = EditorExternalFileController()
        let workflow = EditorExternalFileWorkflowController()
        let modDate = Date(timeIntervalSince1970: 123)

        #expect(workflow.applyConflictRegistration(content: "a", modificationDate: modDate, using: controller))
        #expect(workflow.pollDecision(currentModDate: modDate.addingTimeInterval(0.2), hasUnsavedChanges: false, using: controller))
        #expect(
            workflow.reloadDecision(
                newContent: "new",
                currentContent: "old",
                currentModDate: modDate,
                hasUnsavedChanges: true
            ) == .registerConflict(content: "new", modificationDate: modDate)
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
    func lineOffsetTableSupportsUnicodeAndBounds() {
        let table = LineOffsetTable(content: "a\n😀b\n")
        #expect(table.lineCount == 3)
        #expect(table.utf16Offset(line: 1, character: 2) == 4)
        #expect(table.lineContaining(utf16Offset: 3) == 1)
        #expect(table.lineContaining(utf16Offset: 6) == 2)
        #expect(table.utf16Offset(line: 9, character: 0) == nil)
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
    func renderedRangePolicyFiltersOffsetsAndMatches() {
        let table = LineOffsetTable(content: "alpha\nbeta\ncarrot\n")
        let range = 1..<2

        #expect(EditorRenderedRangePolicy.isRenderedLine(1, renderRange: range))
        #expect(EditorRenderedRangePolicy.isRenderedOffset(7, renderRange: range, lineTable: table))
        #expect(EditorRenderedRangePolicy.isRenderedOffset(1, renderRange: range, lineTable: table) == false)

        let matches = [
            EditorFindMatch(range: .init(location: 1, length: 2), matchedText: "lp"),
            EditorFindMatch(range: .init(location: 7, length: 2), matchedText: "et"),
        ]
        #expect(
            EditorRenderedRangePolicy.renderedFindMatches(
                matches,
                renderRange: range,
                lineTable: table
            ).map(\.matchedText) == ["et"]
        )
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
    func runtimeAvailabilityPolicyClampsViewportAndClearDecisions() {
        #expect(
            EditorRuntimeAvailabilityPolicy.clampedVisibleRange(
                startLine: -10,
                endLine: 120,
                totalLines: 100
            ) == 0..<100
        )
        #expect(EditorRuntimeAvailabilityPolicy.shouldClearTransientProviders(isPrimaryCursorRendered: false))
        #expect(EditorRuntimeAvailabilityPolicy.shouldClearProvider(isEnabled: false))
        #expect(EditorRuntimeAvailabilityPolicy.shouldClearProvider(isEnabled: true) == false)
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
    func renamePolicyNormalizesInputAndFormatsSummary() {
        #expect(EditorRenamePolicy.normalizedProposedName("  renamed  ") == "renamed")
        #expect(EditorRenamePolicy.normalizedProposedName(" \n\t ") == nil)
        #expect(
            EditorRenamePolicy.completedMessage(
                prefix: "Rename completed, updated files:",
                changedFiles: 3
            ) == "Rename completed, updated files: 3"
        )
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
    func workspaceEditSummaryRejectsSiblingProjectWithSharedPrefix() {
        let edit = WorkspaceEdit(
            changes: [
                "file:///tmp/project2/Sources/Other.swift": [
                    TextEdit(
                        range: LSPRange(start: Position(line: 0, character: 0), end: Position(line: 0, character: 1)),
                        newText: "x"
                    )
                ],
            ],
            documentChanges: nil
        )

        let summary = EditorWorkspaceEditSummaryBuilder.summarize(
            edit,
            currentURI: "file:///tmp/project/file.swift",
            projectRootPath: "/tmp/project"
        )

        #expect(summary.fileLabels == ["Other.swift"])
    }

    @Test
    func workspaceEditSummaryUsesUnescapedFileURLsForLabels() {
        let edit = WorkspaceEdit(
            changes: [
                "file:///tmp/project/has space.swift": [
                    TextEdit(
                        range: LSPRange(start: Position(line: 0, character: 0), end: Position(line: 0, character: 1)),
                        newText: "x"
                    )
                ],
            ],
            documentChanges: nil
        )

        let summary = EditorWorkspaceEditSummaryBuilder.summarize(
            edit,
            currentURI: "file:///tmp/project/current.swift",
            projectRootPath: "/tmp/project"
        )

        #expect(summary.fileLabels == ["has space.swift"])
    }

    @Test
    @MainActor
    func workspaceEditControllerAppliesDocumentAndFileOperations() throws {
        let currentURI = "file:///tmp/project/file.swift"
        let externalURI = "file:///tmp/project/other.swift"
        let decoder = JSONDecoder()
        let createFile = try decoder.decode(
            CreateFile.self,
            from: #"{"kind":"create","uri":"file:///tmp/project/new.swift","options":{"overwrite":false,"ignoreIfExists":false}}"#.data(using: .utf8)!
        )
        let renameFile = try decoder.decode(
            RenameFile.self,
            from: #"{"kind":"rename","oldUri":"file:///tmp/project/old.swift","newUri":"file:///tmp/project/renamed.swift","options":{"overwrite":false,"ignoreIfExists":false}}"#.data(using: .utf8)!
        )
        let edit = WorkspaceEdit(
            changes: [
                currentURI: [
                    TextEdit(
                        range: LSPRange(start: Position(line: 0, character: 0), end: Position(line: 0, character: 1)),
                        newText: "a"
                    )
                ],
                externalURI: [
                    TextEdit(
                        range: LSPRange(start: Position(line: 1, character: 0), end: Position(line: 1, character: 2)),
                        newText: "bb"
                    )
                ],
            ],
            documentChanges: [
                .createFile(createFile),
                .renameFile(renameFile),
                .deleteFile(
                    DeleteFile(
                        kind: "delete",
                        uri: "file:///tmp/project/delete.swift",
                        options: .init(recursive: false, ignoreIfNotExists: false)
                    )
                ),
            ]
        )

        let controller = EditorWorkspaceEditController()
        var currentReasons: [String] = []
        var externalPaths: [String] = []
        var createCount = 0
        var renameCount = 0
        var deleteCount = 0

        let changed = controller.apply(
            changes: edit.changes,
            documentChanges: edit.documentChanges,
            currentURI: currentURI,
            applyCurrentDocumentEdits: { _, reason in currentReasons.append(reason) },
            applyExternalFileEdits: { _, url in
                externalPaths.append(url.path)
                return true
            },
            applyCreateFile: { _ in
                createCount += 1
                return true
            },
            applyRenameFile: { _ in
                renameCount += 1
                return true
            },
            applyDeleteFile: { _ in
                deleteCount += 1
                return true
            }
        )

        #expect(changed == 5)
        #expect(currentReasons == ["lsp_workspace_edit"])
        #expect(externalPaths == ["/tmp/project/other.swift"])
        #expect(createCount == 1)
        #expect(renameCount == 1)
        #expect(deleteCount == 1)
    }

    @Test
    @MainActor
    func workspaceEditControllerAppliesUnescapedExternalFileURLs() throws {
        let currentURI = "file:///tmp/project/file.swift"
        let externalURI = "file:///tmp/project/other file.swift"
        let edit = WorkspaceEdit(
            changes: [
                externalURI: [
                    TextEdit(
                        range: LSPRange(start: Position(line: 0, character: 0), end: Position(line: 0, character: 1)),
                        newText: "a"
                    )
                ],
            ],
            documentChanges: [
                .textDocumentEdit(
                    TextDocumentEdit(
                        textDocument: VersionedTextDocumentIdentifier(uri: "file://localhost/tmp/project/doc file.swift", version: 1),
                        edits: [
                            TextEdit(
                                range: LSPRange(start: Position(line: 1, character: 0), end: Position(line: 1, character: 1)),
                                newText: "b"
                            )
                        ]
                    )
                )
            ]
        )

        let controller = EditorWorkspaceEditController()
        var externalPaths: [String] = []

        let changed = controller.apply(
            changes: edit.changes,
            documentChanges: edit.documentChanges,
            currentURI: currentURI,
            applyCurrentDocumentEdits: { _, _ in },
            applyExternalFileEdits: { _, url in
                externalPaths.append(url.path)
                return true
            },
            applyCreateFile: { _ in false },
            applyRenameFile: { _ in false },
            applyDeleteFile: { _ in false }
        )

        #expect(changed == 2)
        #expect(externalPaths == ["/tmp/project/other file.swift", "/tmp/project/doc file.swift"])
    }

    @Test
    @MainActor
    func workspaceEditControllerAppliesTextEditsToFiles() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try "hello\nworld\n".write(to: url, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: url) }

        let edits = [
            TextEdit(
                range: LSPRange(start: Position(line: 1, character: 0), end: Position(line: 1, character: 5)),
                newText: "lumi"
            )
        ]

        let controller = EditorWorkspaceEditController()
        #expect(controller.applyTextEditsToFile(edits, url: url) == true)
        #expect(try String(contentsOf: url, encoding: .utf8) == "hello\nlumi\n")
    }

    @Test
    @MainActor
    func workspaceEditControllerAppliesTextEditsToUTF16Files() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try "hello\nworld\n".write(to: url, atomically: true, encoding: .utf16)
        defer { try? FileManager.default.removeItem(at: url) }

        let edits = [
            TextEdit(
                range: LSPRange(start: Position(line: 1, character: 0), end: Position(line: 1, character: 5)),
                newText: "lumi"
            )
        ]

        let controller = EditorWorkspaceEditController()
        #expect(controller.applyTextEditsToFile(edits, url: url) == true)

        var detectedEncoding = String.Encoding.utf8
        let updated = try String(contentsOf: url, usedEncoding: &detectedEncoding)
        #expect(updated == "hello\nlumi\n")
        #expect(detectedEncoding == .utf16)
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
    func multiCursorMatcherRejectsInvalidSelectionRanges() {
        let text = "cat" as NSString

        #expect(EditorMultiCursorMatcher.selectionText(for: NSRange(location: -1, length: 1), in: text) == nil)
        #expect(EditorMultiCursorMatcher.selectionText(for: NSRange(location: 1, length: -1), in: text) == nil)
        #expect(EditorMultiCursorMatcher.selectionText(for: NSRange(location: 2, length: 2), in: text) == nil)
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
        let fileURL = URL(fileURLWithPath: "/tmp/EditorKernelPeek.swift")
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
        #expect(presentation?.summary == "EditorKernelPeek.swift:2:5")
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
    func peekControllerAcceptsUnescapedFileURLs() {
        let location = Location(
            uri: "file:///tmp/Editor Kernel Peek.swift",
            range: LSPRange(
                start: Position(line: 2, character: 1),
                end: Position(line: 2, character: 4)
            )
        )
        let controller = EditorPeekController()

        let presentation = controller.buildDefinitionPresentation(
            location: location,
            currentFileURL: URL(fileURLWithPath: "/tmp/Editor Kernel Peek.swift"),
            projectRootPath: "/tmp",
            currentContent: "one\ntwo\nthree\n"
        )

        #expect(presentation?.summary == "Editor Kernel Peek.swift:3:2")
        #expect(presentation?.items.first?.target == .init(
            url: URL(fileURLWithPath: "/tmp/Editor Kernel Peek.swift"),
            line: 3,
            column: 2,
            highlightLine: true
        ))
        #expect(presentation?.items.first?.preview == "three")
    }

    @Test
    @MainActor
    func peekControllerReadsExternalUTF16Previews() throws {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("EditorKernelPeek-\(UUID().uuidString).swift")
        try "one\ntwo\nthree\n".write(to: fileURL, atomically: true, encoding: .utf16)
        defer { try? FileManager.default.removeItem(at: fileURL) }

        let location = Location(
            uri: fileURL.absoluteString,
            range: LSPRange(
                start: Position(line: 1, character: 0),
                end: Position(line: 1, character: 3)
            )
        )
        let controller = EditorPeekController()

        let presentation = controller.buildDefinitionPresentation(
            location: location,
            currentFileURL: nil,
            projectRootPath: fileURL.deletingLastPathComponent().path,
            currentContent: nil
        )

        #expect(presentation?.items.first?.preview == "two")
    }

    @Test
    @MainActor
    func peekControllerRejectsSiblingProjectWithSharedPrefix() {
        let fileURL = URL(fileURLWithPath: "/tmp/EditorKernelPeek2.swift")
        let location = Location(
            uri: fileURL.absoluteString,
            range: LSPRange(
                start: Position(line: 0, character: 0),
                end: Position(line: 0, character: 4)
            )
        )
        let controller = EditorPeekController()

        let presentation = controller.buildDefinitionPresentation(
            location: location,
            currentFileURL: nil,
            projectRootPath: "/tmp/EditorKernelPeek",
            currentContent: nil
        )

        #expect(presentation?.summary == "EditorKernelPeek2.swift:1:1")
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
    func workspaceSearchPolicyRejectsSiblingProjectWithSharedPrefix() {
        let output = """
        {"type":"match","data":{"path":{"text":"/tmp/project2/Sources/App.swift"},"lines":{"text":"let value = 1"},"line_number":3,"submatches":[{"start":4}]}}
        """

        let response = EditorWorkspaceSearchPolicy.parse(
            output: output,
            query: "value",
            projectRootPath: "/tmp/project",
            limit: 200
        )

        #expect(response.fileResults.map(\.path) == ["App.swift"])
    }

    @Test
    @MainActor
    func workspaceSearchControllerHandlesEmptyQueryAndExportsMarkdown() async throws {
        let controller = EditorWorkspaceSearchController()
        let empty = try await controller.search(
            query: "   ",
            projectRootPath: "/tmp/project"
        )
        #expect(empty.summary.totalMatches == 0)
        #expect(empty.summary.query == "   ")

        let url = try controller.exportSearchEditor(
            summary: .init(query: "value", totalMatches: 1, totalFiles: 1),
            fileResults: [
                .init(
                    url: URL(fileURLWithPath: "/tmp/project/Sources/App.swift"),
                    path: "Sources/App.swift",
                    matches: [
                        .init(
                            url: URL(fileURLWithPath: "/tmp/project/Sources/App.swift"),
                            line: 3,
                            column: 5,
                            path: "Sources/App.swift",
                            preview: "let value = 1"
                        )
                    ]
                )
            ]
        )
        defer { try? FileManager.default.removeItem(at: url) }
        let markdown = try String(contentsOf: url, encoding: .utf8)
        #expect(url.lastPathComponent.hasPrefix("search-results-"))
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

    @Test
    @MainActor
    func saveWorkflowControllerRunsOnlyWhenSaveIsNeeded() {
        let controller = EditorSaveWorkflowController()
        var saveNowCount = 0
        controller.saveNowIfNeeded(
            hasUnsavedChanges: false,
            reason: "autosave",
            fileName: "Demo.swift",
            verbose: true,
            log: { _ in },
            runSave: { saveNowCount += 1 }
        )
        #expect(saveNowCount == 0)

        controller.saveNowIfNeeded(
            hasUnsavedChanges: true,
            reason: "autosave",
            fileName: "Demo.swift",
            verbose: false,
            log: { _ in },
            runSave: { saveNowCount += 1 }
        )
        #expect(saveNowCount == 1)

        var runTaskCount = 0
        controller.saveNow(saveState: .saving) { runTaskCount += 1 }
        controller.saveNow(saveState: .editing) { runTaskCount += 1 }
        #expect(runTaskCount == 1)
    }

    @Test
    @MainActor
    func documentSymbolItemBuildsTreePathsAndIcons() {
        let leaf = EditorDocumentSymbolItem(
            id: "Root/child",
            name: "child",
            detail: "func",
            kind: .function,
            range: .init(
                start: .init(line: 4, character: 0),
                end: .init(line: 6, character: 0)
            ),
            selectionRange: .init(
                start: .init(line: 4, character: 4),
                end: .init(line: 4, character: 9)
            ),
            children: []
        )
        let root = EditorDocumentSymbolItem(
            id: "Root",
            name: "Root",
            detail: nil,
            kind: .class,
            range: .init(
                start: .init(line: 0, character: 0),
                end: .init(line: 10, character: 0)
            ),
            selectionRange: .init(
                start: .init(line: 0, character: 0),
                end: .init(line: 0, character: 4)
            ),
            children: [leaf]
        )

        #expect(root.iconSymbol == "square.stack")
        #expect(leaf.iconSymbol == "f.cursive")
        #expect(root.line == 1)
        #expect(leaf.column == 5)
        #expect(root.contains(line: 5))
        #expect(root.activePath(for: 5) == ["Root", "Root/child"])
        #expect(root.activeItems(for: 5)?.map(\.id) == ["Root", "Root/child"])
        #expect(root.activePath(for: 20) == nil)
    }

    @Test
    @MainActor
    func scrollStateDefaultsAndStoresViewportOrigin() {
        let initial = EditorScrollState()
        #expect(initial.viewportOrigin == .zero)

        let custom = EditorScrollState(viewportOrigin: CGPoint(x: 12, y: 34))
        #expect(custom.viewportOrigin == CGPoint(x: 12, y: 34))
    }

    @Test
    @MainActor
    func lspRequestPipelineTracksGenerationCancellationAndLatestApply() async {
        actor AppliedRecorder {
            var values: [Int] = []

            func append(_ value: Int) {
                values.append(value)
            }
        }

        let generation = RequestGeneration()
        #expect(generation.generation == 0)
        let gen1 = generation.next()
        #expect(gen1 == 1)
        #expect(generation.isCurrent(1))
        let gen2 = generation.invalidate()
        #expect(gen2 == 2)
        #expect(!generation.isCurrent(1))
        generation.reset()
        #expect(generation.generation == 0)

        let cancellation = CancellationContext()
        #expect(!cancellation.isCancelled)
        cancellation.cancel()
        #expect(cancellation.isCancelled)
        #expect(throws: CancellationError.self) {
            try cancellation.checkCancellation()
        }

        let lifecycle = LSPRequestLifecycle()
        let applied = AppliedRecorder()
        lifecycle.run(
            operation: {
                try? await Task.sleep(for: .milliseconds(40))
                return 1
            },
            apply: { value in
                Task { await applied.append(value) }
            }
        )
        lifecycle.run(
            operation: {
                try? await Task.sleep(for: .milliseconds(5))
                return 2
            },
            apply: { value in
                Task { await applied.append(value) }
            }
        )

        try? await Task.sleep(for: .milliseconds(80))
        #expect(await applied.values == [2])
    }

    @Test
    @MainActor
    func panelModelsAndControllerToggleExclusivePanelsAndMetadata() {
        #expect(EditorBottomPanelKind.problems.title == "Problems")
        #expect(EditorBottomPanelKind.callHierarchy.icon == "point.3.connected.trianglepath.dotted")

        let snapshot = EditorPanelSnapshot(
            isOpenEditorsPanelPresented: false,
            isOutlinePanelPresented: false,
            isProblemsPanelPresented: false,
            isReferencePanelPresented: true,
            isWorkspaceSearchPresented: false,
            isWorkspaceSymbolSearchPresented: false,
            isCallHierarchyPresented: false
        )

        let toggledOpenEditors = EditorPanelCommandController.apply(.toggleOpenEditors, to: snapshot)
        #expect(toggledOpenEditors.isOpenEditorsPanelPresented)
        #expect(!toggledOpenEditors.isOutlinePanelPresented)
        #expect(!toggledOpenEditors.isProblemsPanelPresented)
        #expect(toggledOpenEditors.isReferencePanelPresented == false)

        let openedSymbols = EditorPanelCommandController.apply(.openWorkspaceSymbolSearch, to: snapshot)
        #expect(openedSymbols.isWorkspaceSymbolSearchPresented)
        #expect(openedSymbols.isReferencePanelPresented)

        let closedReference = EditorPanelCommandController.apply(.closeReferences, to: openedSymbols)
        #expect(!closedReference.isReferencePanelPresented)
        #expect(closedReference.isWorkspaceSymbolSearchPresented)
    }

    @Test
    func panelVisibilityPolicyPresentsExclusiveBottomPanels() {
        let snapshot = EditorPanelSnapshot(
            isOpenEditorsPanelPresented: true,
            isOutlinePanelPresented: false,
            isProblemsPanelPresented: true,
            isReferencePanelPresented: false,
            isWorkspaceSearchPresented: false,
            isWorkspaceSymbolSearchPresented: false,
            isCallHierarchyPresented: false
        )

        let presented = EditorPanelVisibilityPolicy.presentingBottomPanel(.workspaceSymbols, in: snapshot)
        #expect(presented.isOpenEditorsPanelPresented)
        #expect(!presented.isProblemsPanelPresented)
        #expect(!presented.isReferencePanelPresented)
        #expect(!presented.isWorkspaceSearchPresented)
        #expect(presented.isWorkspaceSymbolSearchPresented)
        #expect(!presented.isCallHierarchyPresented)
    }

    @Test
    func panelVisibilityPolicySelectsMatchingDiagnosticAcrossSingleAndMultiLineRanges() {
        let singleLine = Diagnostic(
            range: .init(
                start: .init(line: 2, character: 3),
                end: .init(line: 2, character: 8)
            ),
            severity: .warning,
            message: "single"
        )
        let multiLine = Diagnostic(
            range: .init(
                start: .init(line: 4, character: 1),
                end: .init(line: 6, character: 2)
            ),
            severity: .error,
            message: "multi"
        )

        #expect(
            EditorPanelVisibilityPolicy.selectedDiagnostic(
                in: [singleLine, multiLine],
                line: 3,
                column: 6
            )?.message == "single"
        )
        #expect(
            EditorPanelVisibilityPolicy.selectedDiagnostic(
                in: [singleLine, multiLine],
                line: 6,
                column: 1
            )?.message == "multi"
        )
        #expect(
            EditorPanelVisibilityPolicy.selectedDiagnostic(
                in: [singleLine, multiLine],
                line: 1,
                column: 1
            ) == nil
        )
    }

    @Test
    func panelDataPolicyKeepsOnlyVisibleWorkspaceSearchState() {
        let url = URL(fileURLWithPath: "/tmp/A.swift")
        let results = [
            EditorWorkspaceSearchFileResult(
                url: url,
                path: "Sources/A.swift",
                matches: [
                    EditorWorkspaceSearchMatch(
                        url: url,
                        line: 3,
                        column: 1,
                        path: "Sources/A.swift",
                        preview: "alpha"
                    )
                ]
            )
        ]

        let normalized = EditorPanelDataPolicy.normalizedWorkspaceSearchState(
            collapsedFilePaths: ["Sources/A.swift", "Sources/B.swift"],
            selectedMatchID: "match-b",
            results: results
        )

        #expect(normalized.collapsedFilePaths == ["Sources/A.swift"])
        #expect(normalized.selectedMatchID == nil)

        let retoggled = EditorPanelDataPolicy.toggledCollapsedFilePath(
            "Sources/A.swift",
            in: normalized.collapsedFilePaths
        )
        #expect(retoggled.isEmpty)
    }

    @Test
    func panelDataPolicyDropsReferenceSelectionWhenResultDisappears() {
        let kept = EditorReferenceResult(
            url: URL(fileURLWithPath: "/tmp/A.swift"),
            line: 1,
            column: 1,
            path: "A.swift",
            preview: "alpha"
        )
        let removed = EditorReferenceResult(
            url: URL(fileURLWithPath: "/tmp/B.swift"),
            line: 2,
            column: 1,
            path: "B.swift",
            preview: "beta"
        )

        #expect(
            EditorPanelDataPolicy.normalizedReferenceSelection(
                selected: removed,
                availableResults: [kept]
            ) == nil
        )
        #expect(
            EditorPanelDataPolicy.normalizedReferenceSelection(
                selected: kept,
                availableResults: [kept]
            ) == kept
        )
    }

    @Test
    @MainActor
    func fileWatcherControllerDelegatesSetupAndCleanup() throws {
        let controller = EditorFileWatcherController()
        let external = EditorExternalFileController(pollInterval: 10)
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try "hello".write(to: tempURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        _ = external.registerConflictIfNeeded(content: "stale", modificationDate: .now)
        var cleanupCount = 0
        var logged: String?

        controller.setup(
            for: tempURL,
            externalFileController: external,
            onPoll: { _, _ in },
            cleanup: { cleanupCount += 1 },
            logInfo: { logged = $0 }
        )

        #expect(cleanupCount == 1)
        #expect(logged == "已启动文件轮询监听：\(tempURL.lastPathComponent)")
        #expect(external.conflictState == nil)

        controller.cleanup(
            externalFileController: external,
            clearConflict: { cleanupCount += 1 }
        )
        #expect(cleanupCount == 2)
    }

    @Test
    @MainActor
    func sessionItemModelsPreserveIDsAndDefaultTitles() {
        let sessionID = UUID()
        let fileURL = URL(fileURLWithPath: "/tmp/Demo.swift")

        let tab = EditorTab(sessionID: sessionID, fileURL: fileURL)
        #expect(tab.id == sessionID)
        #expect(tab.title == "Demo.swift")

        let untitled = EditorTab(sessionID: sessionID, fileURL: nil)
        #expect(untitled.title == "Untitled")

        let openEditor = EditorOpenEditorItem(
            sessionID: sessionID,
            fileURL: fileURL,
            title: "Demo.swift",
            isDirty: true,
            isPinned: false,
            isActive: true,
            recentActivationRank: 2
        )
        #expect(openEditor.id == sessionID)
        #expect(openEditor.recentActivationRank == 2)

        let target = EditorNavigationTarget(
            sessionID: sessionID,
            fileURL: fileURL,
            title: "Demo.swift",
            isDirty: true,
            isPinned: true
        )
        #expect(target.sessionID == sessionID)
        #expect(target.isPinned)
    }

    @Test
    @MainActor
    func packageManifestSyntaxParsesDependenciesAndHoverMarkdown() {
        let content = #"""
        let package = Package(
            dependencies: [
                .package(url: "https://github.com/apple/swift-log.git", from: "1.5.0"),
                .package(path: "../LocalKit")
            ]
        )
        """#

        let offset = (content as NSString).range(of: "swift-log.git").location
        let link = PackageManifestSyntax.dependencyLink(at: offset, in: content)
        #expect(link?.rawURL == "https://github.com/apple/swift-log.git")

        let dependency = PackageManifestSyntax.dependency(at: offset, in: content)
        #expect(dependency?.repositoryName == "swift-log")
        #expect(dependency?.requirement?.kind == .from)
        #expect(dependency?.requirement?.value == "1.5.0")

        let hover = PackageManifestSyntax.hoverMarkdown(line: 2, character: 38, in: content)
        #expect(hover?.contains("### Swift Package Dependency") == true)
        #expect(hover?.contains("swift-log") == true)
        #expect(hover?.contains("from 1.5.0") == true)
    }

    @Test
    @MainActor
    func packageManifestSyntaxIgnoresParenthesesInsideStringLiterals() {
        let content = #"""
        let package = Package(
            dependencies: [
                .package(url: "https://github.com/example/Package(Preview).git", branch: "feature(test)")
            ]
        )
        """#

        let urlOffset = (content as NSString).range(of: "Package(Preview).git").location
        let link = PackageManifestSyntax.dependencyLink(at: urlOffset, in: content)
        #expect(link?.rawURL == "https://github.com/example/Package(Preview).git")

        let branchOffset = (content as NSString).range(of: "feature(test)").location
        let dependency = PackageManifestSyntax.dependency(at: branchOffset, in: content)
        #expect(dependency?.repositoryName == "Package(Preview)")
        #expect(dependency?.requirement?.kind == .branch)
        #expect(dependency?.requirement?.value == "feature(test)")
    }

    @Test
    @MainActor
    func stringPreviewLinesReturnsExpectedPrefixesAndSuffixes() {
        let text = "one\ntwo\nthree\nfour"
        #expect(text.getFirstLines(2) == "one\ntwo")
        #expect(text.getLastLines(2) == "three\nfour")
        #expect(text.getFirstLines(10) == nil)
        #expect(text.getLastLines(10) == nil)
    }

}
