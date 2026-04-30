import Foundation
import AppKit
import LanguageServerProtocol

@MainActor
extension EditorState {
    func showReferencesFromCurrentCursor() async {
        if let preflightMessage = xcodeLanguagePreflightMessage(operation: "查找引用") {
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
        if let preflightMessage = xcodeLanguagePreflightMessage(operation: "调用层级") {
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
        languageActionFacade.promptRenameSymbol(
            canPreview: canPreview,
            isEditable: isEditable,
            renameController: renameController,
            showStatus: { [weak self] message, level, duration in
                self?.showStatusToast(message, level: level, duration: duration)
            },
            runRename: { [weak self] newName in
                Task { @MainActor [weak self] in
                    await self?.renameSymbolWithLSP(to: newName)
                }
            }
        )
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
        if let preflightMessage = xcodeLanguagePreflightMessage(operation: "重命名符号") {
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

    func xcodeLanguagePreflightMessage(
        operation: String,
        symbolName: String? = nil
    ) -> String? {
        guard let message = XcodeSemanticAvailability.preflightMessage(
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

    func xcodeLanguagePreflightError(
        operation: String,
        symbolName: String? = nil
    ) -> XcodeLSPError? {
        XcodeSemanticAvailability.preflightError(
            uri: currentFileURL?.absoluteString,
            operation: operation,
            symbolName: symbolName,
            strength: .hard
        )
    }

    func resyncXcodeBuildContext() {
        Task { @MainActor [weak self] in
            guard let self else { return }
            guard !self.isResyncingXcodeBuildContext else { return }
            self.isResyncingXcodeBuildContext = true
            defer { self.isResyncingXcodeBuildContext = false }

            await XcodeProjectContextBridge.shared.resyncBuildContext()
            self.refreshXcodeContextSnapshot()

            let status = XcodeProjectContextBridge.shared.buildContextProvider?.buildContextStatus
            switch status {
            case .available:
                self.showStatusToast("Xcode build context 已重新解析", level: .success, duration: 1.8)
            case .resolving:
                self.showStatusToast("Xcode build context 仍在解析中", level: .info, duration: 1.8)
            case .needsResync:
                self.showStatusToast("Xcode build context 仍需要重新同步", level: .warning, duration: 2.2)
            case .unavailable(let reason):
                self.showStatusToast("Xcode build context 重新解析失败：\(reason)", level: .error, duration: 2.6)
            case .unknown, .none:
                self.showStatusToast("已触发 Xcode build context 重新解析", level: .info, duration: 1.8)
            }
        }
    }
}
