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

    /// 自动保存入口（带完整守卫）。
    ///
    /// 与手动保存的区别：跳过需要弹窗确认的文件（project.pbxproj）以及
    /// 不可写/二进制/截断预览的文件，避免静默覆盖或产生破坏性写入。
    /// 同时复用 `saveNowIfNeeded` 的脏检查与重入保护。
    func triggerAutoSave(reason: String) {
        // 模式守卫：仅自动保存模式开启时才执行
        guard autoSaveMode != .off else { return }

        // 外部冲突守卫：有冲突时绝不自动保存，防止覆盖磁盘上的新内容
        guard !hasExternalFileConflict else { return }

        // 文件存在性守卫：没有关联文件（新建未保存）无法自动保存
        guard currentFileURL != nil else { return }

        // 可写性守卫：二进制、截断预览、只读大文件不自动保存
        guard isAutoSaveEligible else { return }

        // 确认守卫：跳过需要弹窗确认的文件（pbxproj），避免阻塞主线程
        guard !isEditingProjectPBXProj else { return }

        saveNowIfNeeded(reason: reason)
    }

    /// 当前文件是否适合自动保存（非二进制、非截断、可编辑）。
    var isAutoSaveEligible: Bool {
        !isBinaryFile && !isTruncated && isEditable && !largeFileMode.isReadOnly
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
            markPersistedText: documentController.markPersistedText,
            clearConflict: { [weak self] in self?.clearExternalFileConflict() },
            syncSession: { [weak self] in self?.syncActiveSessionState() },
            scheduleSuccessClear: { [weak self] in self?.scheduleSuccessClear() },
            notifyDidSave: { [weak self] content in
                guard let self, let uri = self.currentFileURL?.absoluteString else { return }
                self.recordSuccessfulSave()
                self.lspClient.documentDidSave(uri: uri, text: content)
            },
            setHasUnsavedChanges: { [weak self] value in
                self?.hasUnsavedChanges = value
                if !value {
                    // 保存成功（或被清除）后取消待执行的自动保存
                    self?.autoSaveScheduler.cancel()
                }
            }
        )
    }

    func prepareSaveFormatting(_ text: String, tabSize: Int, insertSpaces: Bool) async -> String? {
        if projectLanguagePreflightError(operation: "保存时格式化") != nil {
            return nil
        }
        return await formattingController.prepareSaveFormatting(
            text: text,
            tabSize: tabSize,
            insertSpaces: insertSpaces
        ) { [weak self] tabSize, insertSpaces in
            guard let self else { return nil }
            return await self.lspClient.requestFormatting(
                tabSize: tabSize,
                insertSpaces: insertSpaces
            )
        }
    }

    func applyPreparedSaveText(_ text: String) {
        let before = captureUndoState()
        let replacePayload = documentReplaceController.replaceTextPayload(
            text,
            replaceText: documentController.replaceText,
            transactionController: transactionController
        )
        content = documentController.textStorage
        totalLines = replacePayload.commitPayload.totalLines
        lspClient.replaceDocument(
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
        let currentContent = synchronizedCurrentEditorTextForSave()
        await saveWorkflowController.prepareAndSaveNow(
            currentContent: currentContent,
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
                self?.synchronizedCurrentEditorTextForSave()
            },
            diagnostics: { [weak self] in
                self?.panelState.problemDiagnostics ?? []
            },
            requestCodeActions: { [weak self] range, diagnostics, triggerKinds in
                guard let self else { return [] }
                if self.projectLanguagePreflightError(operation: "保存时代码修复") != nil {
                    return []
                }
                return await self.lspClient.requestCodeAction(
                    range: range,
                    diagnostics: diagnostics,
                    triggerKinds: triggerKinds
                )
            },
            resolveCodeAction: { [weak self] action in
                guard let self else { return nil }
                return await self.lspClient.resolveCodeAction(action)
            },
            isCodeActionResolveSupported: lspClient.codeActionResolveSupported,
            applyWorkspaceEdit: { [weak self] edit in
                self?.applyCodeActionWorkspaceEdit(edit)
            },
            performSave: { [weak self] content, url in
                self?.performSave(content: content, to: url)
            }
        )
    }

    private func synchronizedCurrentEditorTextForSave() -> String? {
        guard let viewText = focusedTextView?.string else {
            return documentController.currentText ?? content?.string
        }

        guard documentController.currentText != viewText else {
            return viewText
        }

        let result = documentController.replaceText(viewText)
        content = documentController.textStorage
        totalLines = result.snapshot.text.filter { $0 == "\n" }.count + 1
        if viewportVisibleLineRange.isEmpty {
            resetViewportObservation(totalLines: totalLines)
        }
        return result.snapshot.text
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
                if Self.verbose {
                    logger.info("\(Self.t)\(message)")
                }
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
                logger.error("\(Self.t)读取外部文件失败：\(error)")
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
            replaceText: documentController.replaceText,
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

        lspClient.replaceDocument(
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
