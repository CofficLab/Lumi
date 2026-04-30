import Foundation
import LanguageServerProtocol

@MainActor
final class EditorSaveController {
    private var successClearTask: Task<Void, Never>?
    private let successDisplayDuration: TimeInterval

    init(successDisplayDuration: TimeInterval = 2.0) {
        self.successDisplayDuration = successDisplayDuration
    }

    func pipelineOptions(
        trimTrailingWhitespace: Bool,
        insertFinalNewline: Bool,
        formatOnSave: Bool,
        organizeImportsOnSave: Bool,
        fixAllOnSave: Bool
    ) -> EditorSavePipelineOptions {
        EditorSavePipelineOptions(
            textParticipants: .init(
                trimTrailingWhitespace: trimTrailingWhitespace,
                insertFinalNewline: insertFinalNewline
            ),
            formatOnSave: formatOnSave,
            organizeImportsOnSave: organizeImportsOnSave,
            fixAllOnSave: fixAllOnSave
        )
    }

    func prepareAndSaveNow(
        currentContent: String,
        fileURL: URL,
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
        let requestFileURL = fileURL
        let prepared = await EditorSavePipelineController.prepare(
            text: currentContent,
            options: options,
            tabSize: tabSize,
            insertSpaces: insertSpaces,
            formatDocument: prepareFormatting
        )

        guard currentFileURL() == requestFileURL else { return }

        if prepared.changed {
            applyPreparedSaveText(prepared.text)
        }

        await applyDeferredSaveActions(
            prepared.deferredActions,
            currentText: currentText,
            diagnostics: diagnostics,
            requestCodeActions: requestCodeActions,
            resolveCodeAction: resolveCodeAction,
            isCodeActionResolveSupported: isCodeActionResolveSupported,
            applyWorkspaceEdit: applyWorkspaceEdit
        )

        let finalContent = currentText() ?? prepared.text
        performSave(finalContent, requestFileURL)
    }

    func performSave(
        content: String,
        url: URL,
        onMissingFile: @escaping @MainActor () -> Void,
        writeFile: @escaping @Sendable (_ content: String, _ url: URL) async throws -> Void,
        onSuccess: @escaping @MainActor () -> Void,
        onFailure: @escaping @MainActor (_ error: Error) -> Void
    ) {
        Task {
            do {
                guard FileManager.default.fileExists(atPath: url.path) else {
                    onMissingFile()
                    return
                }

                try await writeFile(content, url)
                onSuccess()
            } catch {
                onFailure(error)
            }
        }
    }

    func scheduleSuccessClear(
        isSavedState: @escaping @MainActor () -> Bool,
        clearState: @escaping @MainActor () -> Void
    ) {
        successClearTask?.cancel()
        successClearTask = Task {
            try? await Task.sleep(for: .seconds(successDisplayDuration))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                if isSavedState() {
                    clearState()
                }
            }
        }
    }

    func cancelSuccessClear() {
        successClearTask?.cancel()
        successClearTask = nil
    }

    private func fullDocumentRange(for text: String) -> LSPRange {
        let lines = text.components(separatedBy: .newlines)
        let endLine = max(lines.count - 1, 0)
        let endCharacter = lines.last?.utf16.count ?? 0
        return LSPRange(
            start: Position(line: 0, character: 0),
            end: Position(line: endLine, character: endCharacter)
        )
    }

    private func codeActionKinds(for actions: [EditorDeferredSaveAction]) -> [CodeActionKind] {
        actions.compactMap { action in
            switch action {
            case .organizeImports:
                return .SourceOrganizeImports
            case .fixAll:
                return .SourceFixAll
            }
        }
    }

    private func applyDeferredSaveActions(
        _ actions: [EditorDeferredSaveAction],
        currentText: @escaping @MainActor () -> String?,
        diagnostics: @escaping @MainActor () -> [Diagnostic],
        requestCodeActions: @escaping @MainActor (_ range: LSPRange, _ diagnostics: [Diagnostic], _ triggerKinds: [CodeActionKind]) async -> [CodeAction],
        resolveCodeAction: @escaping @MainActor (_ action: CodeAction) async -> CodeAction?,
        isCodeActionResolveSupported: Bool,
        applyWorkspaceEdit: @escaping @MainActor (_ edit: WorkspaceEdit) -> Void
    ) async {
        guard actions.isEmpty == false else { return }
        guard let currentText = currentText() else { return }
        let requestedKinds = codeActionKinds(for: actions)
        guard !requestedKinds.isEmpty else { return }

        let range = fullDocumentRange(for: currentText)
        let codeActions = await requestCodeActions(range, diagnostics(), requestedKinds)
        guard !codeActions.isEmpty else { return }

        for action in codeActions {
            var resolved = action
            if resolved.edit == nil, isCodeActionResolveSupported,
               let resolvedAction = await resolveCodeAction(resolved) {
                resolved = resolvedAction
            }
            guard let edit = resolved.edit else { continue }
            applyWorkspaceEdit(edit)
        }
    }
}
