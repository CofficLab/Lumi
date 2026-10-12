import Foundation
import LanguageServerProtocol

@MainActor
public final class EditorSaveWorkflowController {
    public init() {}

    public func saveNowIfNeeded(
        hasUnsavedChanges: Bool,
        reason: String,
        fileName: String?,
        verbose: Bool,
        log: (String) -> Void,
        runSave: () -> Void
    ) {
        guard EditorSaveWorkflowPolicy.shouldSaveNowIfNeeded(hasUnsavedChanges: hasUnsavedChanges) else { return }
        if verbose {
            log("触发立即保存: 原因=\(reason), 文件=\(fileName ?? "nil")")
        }
        runSave()
    }

    public func saveNow(
        saveState: EditorSaveState,
        runSaveTask: () -> Void
    ) {
        let isSaving: Bool
        if case .saving = saveState {
            isSaving = true
        } else {
            isSaving = false
        }
        guard EditorSaveWorkflowPolicy.shouldRunSaveTask(isSaving: isSaving) else {
            return
        }
        runSaveTask()
    }

    public func prepareAndSaveNow(
        currentContent: String?,
        fileURL: URL?,
        saveController: EditorSaveController,
        options: EditorSavePipelineOptions,
        tabSize: Int,
        insertSpaces: Bool,
        currentFileURL: @escaping @MainActor () -> URL?,
        prepareFormatting: @escaping @MainActor (_ text: String, _ tabSize: Int, _ insertSpaces: Bool) async -> String?,
        applyPreparedSaveText: @escaping @MainActor (_ text: String) -> Void,
        currentText: @escaping @MainActor () -> String?,
        diagnostics: @escaping @MainActor () -> [Diagnostic],
        requestCodeActions: @escaping @MainActor (_ range: LSPRange, _ diagnostics: [Diagnostic], _ triggerKinds: [CodeActionKind]) async -> [CodeAction],
        resolveCodeAction: @escaping @MainActor (_ action: CodeAction) async -> CodeAction?,
        isCodeActionResolveSupported: Bool,
        applyWorkspaceEdit: @escaping @MainActor (_ edit: WorkspaceEdit) -> Void,
        performSave: @escaping @MainActor (_ content: String, _ url: URL) -> Void
    ) async {
        guard let currentContent,
              let fileURL else { return }
        await saveController.prepareAndSaveNow(
            currentContent: currentContent,
            fileURL: fileURL,
            options: options,
            tabSize: tabSize,
            insertSpaces: insertSpaces,
            currentFileURL: currentFileURL,
            prepareFormatting: prepareFormatting,
            applyPreparedSaveText: applyPreparedSaveText,
            currentText: currentText,
            diagnostics: diagnostics,
            requestCodeActions: requestCodeActions,
            resolveCodeAction: resolveCodeAction,
            isCodeActionResolveSupported: isCodeActionResolveSupported,
            applyWorkspaceEdit: applyWorkspaceEdit,
            performSave: performSave
        )
    }

    public func performSave(
        content: String,
        url: URL?,
        verbose: Bool,
        logInfo: @escaping (String) -> Void,
        logError: @escaping (String) -> Void,
        setSaveState: @escaping (EditorSaveState) -> Void,
        saveController: EditorSaveController,
        saveStateController: EditorSaveStateController,
        markPersistedText: @escaping (String) -> Void,
        clearConflict: @escaping () -> Void,
        syncSession: @escaping () -> Void,
        scheduleSuccessClear: @escaping () -> Void,
        notifyDidSave: @escaping (_ content: String) -> Void,
        setHasUnsavedChanges: @escaping (Bool) -> Void
    ) {
        guard let url else {
            if verbose {
                logInfo("保存失败: url 为 nil")
            }
            return
        }

        if verbose {
            logInfo("执行保存: 路径=\(url.path), 内容长度=\(content.count)")
        }
        setSaveState(.saving)

        saveController.performSave(
            content: content,
            url: url,
            onMissingFile: {
                logError("保存失败: 文件不存在 at \(url.path)")
                saveStateController.applyMissingFileFailure(
                    scheduleSuccessClear: scheduleSuccessClear,
                    setSaveState: setSaveState
                )
            },
            writeFile: { content, url in
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                    DispatchQueue.global(qos: .userInitiated).async {
                        do {
                            try content.write(to: url, atomically: true, encoding: .utf8)
                            continuation.resume()
                        } catch {
                            continuation.resume(throwing: error)
                        }
                    }
                }
            },
            onSuccess: {
                if verbose {
                    logInfo("保存成功")
                }
                saveStateController.applySaveSuccess(
                    content: content,
                    markPersistedText: markPersistedText,
                    clearConflict: clearConflict,
                    syncSession: syncSession,
                    scheduleSuccessClear: scheduleSuccessClear,
                    notifyDidSave: notifyDidSave,
                    setHasUnsavedChanges: setHasUnsavedChanges,
                    setSaveState: setSaveState
                )
            },
            onFailure: { error in
                logError("保存失败: \(error)")
                saveStateController.applySaveFailure(
                    error: error,
                    syncSession: syncSession,
                    scheduleSuccessClear: scheduleSuccessClear,
                    setSaveState: setSaveState
                )
            }
        )
    }
}
