import Foundation
import AppKit

@MainActor
extension EditorState {
    func saveNow() {
        saveWorkflowController.saveNow(saveState: saveState) {
            Task { @MainActor [weak self] in
                await self?.prepareAndSaveNow()
            }
        }
    }

    func saveNowIfNeeded(reason: String) {
        saveWorkflowController.saveNowIfNeeded(
            hasUnsavedChanges: hasUnsavedChanges,
            reason: reason,
            fileName: currentFileURL?.lastPathComponent,
            verbose: Self.verbose,
            log: { [logger] message in
                logger.info("\(Self.t)\(message)")
            },
            runSave: { [weak self] in
                self?.saveNow()
            }
        )
    }

    func performSave(content: String, to url: URL?) {
        saveWorkflowController.performSave(
            content: content,
            url: url,
            verbose: Self.verbose,
            logInfo: { [logger] message in
                logger.info("\(Self.t)\(message)")
            },
            logError: { [logger] message in
                logger.error("\(Self.t)\(message)")
            },
            setSaveState: { [weak self] state in self?.saveState = state },
            saveController: saveController,
            saveStateController: saveStateController,
            documentController: documentController,
            clearConflict: { [weak self] in self?.clearExternalFileConflict() },
            syncSession: { [weak self] in self?.syncActiveSessionState() },
            scheduleSuccessClear: { [weak self] in self?.scheduleSuccessClear() },
            notifyDidSave: { [weak self] content in
                guard let self, let uri = self.currentFileURL?.absoluteString else { return }
                self.lspService.documentDidSave(uri: uri, text: content)
            },
            setHasUnsavedChanges: { [weak self] value in self?.hasUnsavedChanges = value }
        )
    }

    func prepareSaveFormatting(_ text: String, tabSize: Int, insertSpaces: Bool) async -> String? {
        if xcodeLanguagePreflightError(operation: "保存时格式化") != nil {
            return nil
        }
        return await formattingController.prepareSaveFormatting(
            text: text,
            tabSize: tabSize,
            insertSpaces: insertSpaces
        ) { [weak self] tabSize, insertSpaces in
            guard let self else { return nil }
            return await self.lspCoordinator.requestFormatting(
                tabSize: tabSize,
                insertSpaces: insertSpaces
            )
        }
    }

    func applyPreparedSaveText(_ text: String) {
        let before = captureUndoState()
        let replacePayload = documentReplaceController.replaceTextPayload(
            text,
            documentController: documentController,
            transactionController: transactionController
        )
        content = documentController.textStorage
        totalLines = replacePayload.commitPayload.totalLines
        lspCoordinator.replaceDocument(
            replacePayload.commitPayload.text,
            version: replacePayload.commitPayload.version
        )
        notifyContentChangedAfterSynchronizedEdit(using: replacePayload.commitPayload.text)
        recordUndoChange(from: before, reason: "save_prepare_text")
    }

    func prepareAndSaveNow() async {
        guard confirmProjectFileSaveIfNeeded() else {
            showStatusToast("已取消保存", level: .info, duration: 1.2)
            return
        }
        await saveWorkflowController.prepareAndSaveNow(
            currentContent: documentController.currentText ?? content?.string,
            fileURL: currentFileURL,
            saveController: saveController,
            options: savePipelineOptions,
            tabSize: tabWidth,
            insertSpaces: useSpaces,
            currentFileURL: { [weak self] in
                self?.currentFileURL
            },
            prepareFormatting: { [weak self] text, tabSize, insertSpaces in
                guard let self else { return nil }
                return await self.prepareSaveFormatting(
                    text,
                    tabSize: tabSize,
                    insertSpaces: insertSpaces
                )
            },
            applyPreparedSaveText: { [weak self] text in
                self?.applyPreparedSaveText(text)
            },
            currentText: { [weak self] in
                self?.documentController.currentText ?? self?.content?.string
            },
            diagnostics: { [weak self] in
                self?.panelState.problemDiagnostics ?? []
            },
            requestCodeActions: { [weak self] range, diagnostics, triggerKinds in
                guard let self else { return [] }
                if self.xcodeLanguagePreflightError(operation: "保存时代码修复") != nil {
                    return []
                }
                return await self.lspCoordinator.requestCodeAction(
                    range: range,
                    diagnostics: diagnostics,
                    triggerKinds: triggerKinds
                )
            },
            resolveCodeAction: { [weak self] action in
                guard let self else { return nil }
                return await self.lspService.resolveCodeAction(action)
            },
            isCodeActionResolveSupported: lspService.codeActionResolveSupported,
            applyWorkspaceEdit: { [weak self] edit in
                self?.applyCodeActionWorkspaceEdit(edit)
            },
            performSave: { [weak self] content, url in
                self?.performSave(content: content, to: url)
            }
        )
    }

    func scheduleSuccessClear() {
        saveController.scheduleSuccessClear(
            isSavedState: { [weak self] in
                if case .saved = self?.saveState {
                    return true
                }
                return false
            },
            clearState: { [weak self] in
                self?.saveState = .idle
            }
        )
    }

    func setupFileWatcher(for url: URL) {
        fileWatcherController.setup(
            for: url,
            externalFileController: externalFileController,
            onPoll: { [weak self] url, currentModDate in
                self?.pollFileChange(url: url, currentModDate: currentModDate)
            },
            cleanup: { [weak self] in
                self?.clearExternalFileConflict()
            },
            logInfo: { [logger] message in
                logger.info("\(Self.t)\(message)")
            }
        )
    }

    func cleanupFileWatcher() {
        fileWatcherController.cleanup(
            externalFileController: externalFileController,
            clearConflict: { [weak self] in
                self?.clearExternalFileConflict()
            }
        )
    }

    func pollFileChange(url: URL, currentModDate: Date) {
        guard externalFileWorkflowController.pollDecision(
            currentModDate: currentModDate,
            hasUnsavedChanges: hasUnsavedChanges,
            using: externalFileController
        ) else {
            return
        }
        reloadIfFileChangedExternally(url: url, currentModDate: currentModDate)
    }

    func reloadIfFileChangedExternally(url: URL, currentModDate: Date) {
        guard let currentContent = content?.string else { return }

        Task {
            do {
                guard let newContent = try await externalFileController.loadExternalText(from: url) else { return }

                switch self.externalFileWorkflowController.reloadDecision(
                    newContent: newContent,
                    currentContent: currentContent,
                    currentModDate: currentModDate,
                    hasUnsavedChanges: self.hasUnsavedChanges
                ) {
                case .unchanged:
                    self.externalFileController.recordUnchangedModificationDate(currentModDate)
                case .registerConflict(let content, let modificationDate):
                    self.registerExternalFileConflict(
                        content,
                        modificationDate: modificationDate
                    )
                case .applyExternalContent(let content, let modificationDate):
                    self.applyExternalContent(content, modificationDate: modificationDate)
                }
            } catch {
                if Self.verbose {
                    logger.error("\(Self.t)读取外部文件失败：\(error)")
                }
            }
        }
    }

    func registerExternalFileConflict(_ newContent: String, modificationDate: Date) {
        guard externalFileWorkflowController.applyConflictRegistration(
            content: newContent,
            modificationDate: modificationDate,
            using: externalFileController
        ) else {
            return
        }
        hasExternalFileConflict = true
        saveState = .conflict(
            EditorStatusMessageCatalog.externalFileChangedOnDisk(
                fileName: currentFileURL?.lastPathComponent,
                isProjectFile: isEditingProjectPBXProj
            )
        )
        syncActiveSessionState()
    }

    func clearExternalFileConflict() {
        externalFileController.clearConflict()
        hasExternalFileConflict = false
    }

    func reloadExternalFileConflict() {
        externalFileController.reloadConflict(
            applyExternalContent: { [weak self] content, modificationDate in
                self?.applyExternalContent(content, modificationDate: modificationDate)
            },
            clearConflict: { [weak self] in
                self?.clearExternalFileConflict()
            },
            syncSession: { [weak self] in
                self?.syncActiveSessionState()
            }
        )
    }

    func keepEditorVersionForExternalConflict() {
        externalFileController.keepEditorVersionForConflict(
            hasUnsavedChanges: hasUnsavedChanges,
            clearConflict: { [weak self] in
                self?.clearExternalFileConflict()
            },
            setSaveState: { [weak self] stateIsEditing in
                self?.saveState = stateIsEditing ? .editing : .idle
            },
            syncSession: { [weak self] in
                self?.syncActiveSessionState()
            }
        )
    }

    func applyExternalContent(_ newContent: String, modificationDate: Date) {
        if Self.verbose {
            logger.info("\(Self.t)检测到外部修改，重新加载：\(self.currentFileURL?.lastPathComponent ?? "")")
        }

        let replacePayload = documentReplaceController.replaceTextPayload(
            newContent,
            documentController: documentController,
            transactionController: transactionController
        )
        content = documentController.textStorage
        totalLines = replacePayload.commitPayload.totalLines

        documentController.markPersistedText(newContent)
        externalFileController.recordAppliedExternalContent(modificationDate: modificationDate)
        clearExternalFileConflict()
        hasUnsavedChanges = false
        saveState = .idle
        refreshFindMatches()

        lspCoordinator.replaceDocument(
            replacePayload.commitPayload.text,
            version: replacePayload.commitPayload.version
        )
        resetUndoHistory()
        syncActiveSessionState()
    }

    private func confirmProjectFileSaveIfNeeded() -> Bool {
        guard isEditingProjectPBXProj, let fileURL = currentFileURL else { return true }

        let alert = NSAlert()
        alert.messageText = "Confirm project.pbxproj save"
        alert.informativeText = EditorStatusMessageCatalog.projectFileSaveConfirmation(fileName: fileURL.lastPathComponent)
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Save in Lumi")
        alert.addButton(withTitle: "Cancel")

        return alert.runModal() == .alertFirstButtonReturn
    }
}
