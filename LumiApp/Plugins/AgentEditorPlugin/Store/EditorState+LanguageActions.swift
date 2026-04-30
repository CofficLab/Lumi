import Foundation
import AppKit
import LanguageServerProtocol

@MainActor
extension EditorState {
    func showQuickFixesFromCurrentCursor() async {
        guard canPreview, isEditable else { return }
        guard let currentFileURL else { return }
        if let preflightMessage = projectLanguagePreflightMessage(operation: "快速修复") {
            showStatusToast(preflightMessage, level: .warning, duration: 2.4)
            return
        }

        let position = currentLSPPosition()
        let line = max(position.line, 0)
        let diagnostics = panelState.problemDiagnostics.filter { diagnostic in
            Int(diagnostic.range.start.line) <= line && Int(diagnostic.range.end.line) >= line
        }

        await codeActionProvider.requestCodeActionsForLine(
            uri: currentFileURL.absoluteString,
            line: line,
            character: max(position.character, 0),
            diagnostics: diagnostics,
            languageId: detectedLanguage?.tsName ?? "swift",
            selectedText: selectedTextForCodeActions()
        )

        guard presentCodeActionPanel(preferPreferred: true) else {
            showStatusToast("No quick fixes available", level: .info, duration: 1.8)
            return
        }
    }

    func dismissPeek() {
        currentPeekPresentation = nil
    }

    func dismissInlineRename() {
        currentInlineRenameState = nil
    }

    func updateInlineRenameDraft(_ draft: String) {
        guard var state = currentInlineRenameState else { return }
        state.draftName = draft
        state.invalidatePreview()
        currentInlineRenameState = state
    }

    func startInlineRename() {
        guard canPreview, isEditable else { return }
        guard let originalName = currentSymbolNameForRename(), !originalName.isEmpty else {
            showStatusToast("No symbol selected for rename", level: .warning, duration: 1.8)
            return
        }
        currentInlineRenameState = EditorInlineRenameState(
            originalName: originalName,
            draftName: originalName,
            isLoadingPreview: false,
            errorMessage: nil,
            previewSummary: nil,
            previewEdit: nil
        )
    }

    func previewInlineRename() async {
        guard var renameState = currentInlineRenameState else { return }
        let newName = renameState.trimmedDraftName
        guard !newName.isEmpty else {
            renameState.errorMessage = "Enter a new symbol name"
            currentInlineRenameState = renameState
            return
        }
        guard newName != renameState.originalName else {
            renameState.errorMessage = "Choose a different symbol name"
            currentInlineRenameState = renameState
            return
        }
        if let preflightMessage = projectLanguagePreflightMessage(operation: "重命名符号", symbolName: renameState.originalName) {
            renameState.errorMessage = preflightMessage
            currentInlineRenameState = renameState
            return
        }

        renameState.isLoadingPreview = true
        renameState.errorMessage = nil
        renameState.previewSummary = nil
        renameState.previewEdit = nil
        currentInlineRenameState = renameState

        let position = currentLSPPosition()
        guard let edit = await lspCoordinator.requestRename(
            line: position.line,
            character: position.character,
            newName: newName
        ) else {
            renameState.isLoadingPreview = false
            renameState.errorMessage = renameController.failedMessage()
            currentInlineRenameState = renameState
            return
        }

        let summary = workspaceEditController.summarize(
            edit,
            currentURI: currentFileURL?.absoluteString ?? "",
            projectRootPath: projectRootPath
        )
        renameState.isLoadingPreview = false
        renameState.previewEdit = edit
        renameState.previewSummary = summary.changedFiles > 0 ? summary : nil
        renameState.errorMessage = summary.changedFiles > 0 ? nil : renameController.notAppliedMessage()
        currentInlineRenameState = renameState
    }

    func applyInlineRename() {
        guard let renameState = currentInlineRenameState,
              let edit = renameState.previewEdit,
              let currentURI = currentFileURL?.absoluteString else {
            return
        }

        let changedFiles = workspaceEditController.apply(
            changes: edit.changes,
            documentChanges: edit.documentChanges,
            currentURI: currentURI,
            applyCurrentDocumentEdits: { [weak self] edits, reason in
                self?.applyTextEditsToCurrentDocument(edits, reason: reason)
            },
            applyExternalFileEdits: { [weak self] edits, url in
                self?.applyTextEditsToFile(edits, url: url) ?? false
            }
        )

        dismissInlineRename()
        if changedFiles == 0 {
            showStatusToast(renameController.notAppliedMessage(), level: .warning, duration: 1.8)
            return
        }
        showStatusToast(renameController.completedMessage(changedFiles: changedFiles), level: .success, duration: 1.8)
    }

    func openPeekItem(_ item: EditorPeekItem) {
        performNavigation(item.navigationRequest)
        dismissPeek()
    }

    func showPeekDefinitionFromCurrentCursor() async {
        if let preflightMessage = projectLanguagePreflightMessage(operation: "Peek Definition") {
            showStatusToast(preflightMessage, level: .warning, duration: 2.4)
            return
        }
        let position = currentLSPPosition()
        guard let location = await lspCoordinator.requestDefinition(line: position.line, character: position.character),
              let presentation = peekController.buildDefinitionPresentation(
                location: location,
                currentFileURL: currentFileURL,
                projectRootPath: projectRootPath,
                currentContent: content?.string
              ) else {
            dismissPeek()
            showStatusToast("No definition found", level: .info)
            return
        }
        currentPeekPresentation = presentation
    }

    func showPeekReferencesFromCurrentCursor() async {
        if let preflightMessage = projectLanguagePreflightMessage(operation: "Peek References") {
            showStatusToast(preflightMessage, level: .warning, duration: 2.4)
            return
        }
        let position = currentLSPPosition()
        let locations = await lspCoordinator.requestReferences(line: position.line, character: position.character)
        let presentation = peekController.buildReferencesPresentation(
            locations: locations,
            currentFileURL: currentFileURL,
            relativeFilePath: relativeFilePath,
            projectRootPath: projectRootPath,
            currentContent: content?.string
        )
        guard !presentation.items.isEmpty else {
            dismissPeek()
            showStatusToast("No references found", level: .info)
            return
        }
        currentPeekPresentation = presentation
    }

    func showReferencesFromCurrentCursor() async {
        if let preflightMessage = projectLanguagePreflightMessage(operation: "查找引用") {
            showStatusToast(preflightMessage, level: .warning, duration: 2.4)
            return
        }
        await languageActionFacade.showReferences(
            currentFileURL: currentFileURL,
            relativeFilePath: relativeFilePath,
            projectRootPath: projectRootPath,
            requestGenerationNext: { [weak self] in
                self?.referencesRequestGeneration.next() ?? 0
            },
            isRequestCurrent: { [weak self] generation in
                self?.referencesRequestGeneration.isCurrent(generation) ?? false
            },
            currentPosition: currentLSPPosition,
            requestReferences: { [weak self] line, character in
                guard let self else { return [] }
                return await self.lspCoordinator.requestReferences(line: line, character: character)
            },
            lspActionController: lspActionController,
            clearReferences: { [weak self] in
                self?.panelController.clearData(closeReferences: false)
            },
            setReferenceResults: { [weak self] results in
                self?.panelController.setReferenceResults(results)
            },
            updateReferenceVisibility: { [weak self] isVisible in
                self?.panelController.updateVisibility(references: isVisible)
            },
            syncSession: { [weak self] in
                self?.syncActiveSessionState()
            },
            showStatus: { [weak self] message, level, duration in
                self?.showStatusToast(message, level: level, duration: duration)
            }
        )
    }

    func goToDefinition(for selection: NSRange) async {
        await jump(to: selection, kind: .definition) { [weak self] range in
            await self?.jumpDelegate?.performGoToDefinition(forRange: range)
        }
    }

    func goToDeclaration(for selection: NSRange) async {
        await jump(to: selection, kind: .declaration) { [weak self] range in
            await self?.jumpDelegate?.performGoToDeclaration(forRange: range)
        }
    }

    func goToTypeDefinition(for selection: NSRange) async {
        await jump(to: selection, kind: .typeDefinition) { [weak self] range in
            await self?.jumpDelegate?.performGoToTypeDefinition(forRange: range)
        }
    }

    func goToImplementation(for selection: NSRange) async {
        await jump(to: selection, kind: .implementation) { [weak self] range in
            await self?.jumpDelegate?.performGoToImplementation(forRange: range)
        }
    }

    func showStatusToast(_ message: String, level: EditorStatusLevel, duration: TimeInterval = 1.8) {
        statusToastController.show(message: message, level: level, duration: duration)
    }

    func openCallHierarchy() async {
        if let preflightMessage = projectLanguagePreflightMessage(operation: "调用层级") {
            showStatusToast(preflightMessage, level: .warning, duration: 2.4)
            return
        }
        await languageActionFacade.openCallHierarchy(
            callHierarchyController: callHierarchyController,
            currentFileURL: currentFileURL,
            cursorLine: cursorLine,
            cursorColumn: cursorColumn,
            prepare: { [weak self] uri, line, character in
                await self?.callHierarchyProvider.prepareCallHierarchy(
                    uri: uri,
                    line: line,
                    character: character
                )
            },
            hasRootItem: { [weak self] in
                self?.callHierarchyProvider.rootItem != nil
            },
            showWarning: { [weak self] message in
                self?.showStatusToast(message, level: .warning)
            },
            openPanel: { [weak self] command in
                self?.performPanelCommand(command)
            }
        )
    }

    func promptRenameSymbol() {
        startInlineRename()
    }

    private func selectedTextForCodeActions() -> String? {
        guard let focusedTextView,
              let selection = focusedTextView.selectionManager.textSelections.first else { return nil }
        let range = selection.range
        guard range.location != NSNotFound,
              range.length > 0,
              let selectedRange = Range(range, in: focusedTextView.string) else {
            return nil
        }
        return String(focusedTextView.string[selectedRange])
    }

    func currentLSPPosition() -> (line: Int, character: Int) {
        (
            max(cursorLine - 1, 0),
            max(cursorColumn - 1, 0)
        )
    }

    func applyTextEditsToCurrentDocument(_ edits: [TextEdit], reason: String = "text_edits") {
        guard let text = documentController.currentText,
              let transaction = transactionController.transactionForTextEdits(
                edits,
                in: text,
                currentSelections: currentSelectionsAsNSRanges()
              ) else {
            return
        }
        let before = captureUndoState()
        guard let result = documentController.apply(transaction: transaction) else { return }
        commitDocumentEditResult(result, reason: reason)
        recordUndoChange(from: before, reason: reason)
    }

    func applyCodeActionWorkspaceEdit(_ edit: WorkspaceEdit) {
        let currentURI = currentFileURL?.absoluteString
        _ = workspaceEditController.apply(
            changes: edit.changes,
            documentChanges: edit.documentChanges,
            currentURI: currentURI ?? ""
        ) { [weak self] edits, reason in
            self?.applyTextEditsToCurrentDocument(edits, reason: reason)
        } applyExternalFileEdits: { [weak self] edits, url in
            self?.applyTextEditsToFile(edits, url: url) ?? false
        }
    }

    func applyTextEditsToFile(_ edits: [TextEdit], url: URL) -> Bool {
        workspaceEditController.applyTextEditsToFile(edits, url: url)
    }

    private func jump(
        to selection: NSRange,
        kind: EditorLSPActionController.JumpKind,
        perform: @escaping (_ range: NSRange) async -> Void
    ) async {
        await languageActionFacade.jump(
            selection: selection,
            kind: kind,
            lspActionController: lspActionController,
            showStatus: { [weak self] message, level, duration in
                self?.showStatusToast(message, level: level, duration: duration)
            },
            perform: perform
        )
    }

    private func renameSymbolWithLSP(to newName: String) async {
        if let preflightMessage = projectLanguagePreflightMessage(operation: "重命名符号") {
            showStatusToast(preflightMessage, level: .warning, duration: 2.4)
            return
        }
        await languageActionFacade.rename(
            newName: newName,
            currentURI: currentFileURL?.absoluteString,
            currentPosition: currentLSPPosition,
            requestRename: { [weak self] line, character, newName in
                guard let self else { return nil }
                return await self.lspCoordinator.requestRename(
                    line: line,
                    character: character,
                    newName: newName
                )
            },
            workspaceEditController: workspaceEditController,
            renameController: renameController,
            applyCurrentDocumentEdits: { [weak self] edits, reason in
                self?.applyTextEditsToCurrentDocument(edits, reason: reason)
            },
            applyExternalFileEdits: { [weak self] edits, url in
                self?.applyTextEditsToFile(edits, url: url) ?? false
            },
            showStatus: { [weak self] message, level, duration in
                self?.showStatusToast(message, level: level, duration: duration)
            }
        )
    }

    func projectLanguagePreflightMessage(
        operation: String,
        symbolName: String? = nil
    ) -> String? {
        guard let message = semanticCapability?.preflightMessage(
            uri: currentFileURL?.absoluteString,
            operation: operation,
            symbolName: symbolName,
            strength: .hard
        ) else {
            return nil
        }
        return EditorStatusMessageCatalog.languageFeatureUnavailable(
            operation: operation,
            reason: message
        )
    }

    func projectLanguagePreflightError(
        operation: String,
        symbolName: String? = nil
    ) -> EditorLanguageFeatureError? {
        semanticCapability?.preflightError(
            uri: currentFileURL?.absoluteString,
            operation: operation,
            symbolName: symbolName,
            strength: .hard
        )
    }

    func resyncProjectContext() {
        Task { @MainActor [weak self] in
            guard let self else { return }
            guard !self.isResyncingProjectContext else { return }
            self.isResyncingProjectContext = true
            defer { self.isResyncingProjectContext = false }

            await self.projectContextCapability?.resyncProjectContext()
            self.refreshProjectContextSnapshot()

            switch self.currentProjectContextStatus {
            case .available:
                self.showStatusToast("项目语义上下文已重新解析", level: .success, duration: 1.8)
            case .resolving:
                self.showStatusToast("项目语义上下文仍在解析中", level: .info, duration: 1.8)
            case .needsResync:
                self.showStatusToast("项目语义上下文仍需要重新同步", level: .warning, duration: 2.2)
            case .unavailable(let reason):
                self.showStatusToast("项目语义上下文重新解析失败：\(reason)", level: .error, duration: 2.6)
            case .unknown:
                self.showStatusToast("已触发项目语义上下文重新解析", level: .info, duration: 1.8)
            }
        }
    }
}
