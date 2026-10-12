import Foundation
import LanguageServerProtocol

// MARK: - LSP Action Provider Protocol

/// 协议抽象：LSP 操作能力（引用查找、跳转状态消息等）。
///
/// App 侧的 `EditorLSPActionController` 遵循此协议。
@MainActor
public protocol EditorLSPActionProviding {
    func referenceResults(
        from locations: [Location],
        currentFileURL: URL,
        relativeFilePath: String,
        projectRootPath: String?,
        previewLine: (URL, Int) -> String?
    ) -> [ReferenceResult]

    func jumpKindStatusMessage(_ kind: EditorLSPActionJumpKind) -> String
}

/// 跳转类型（独立于 App 侧的 EditorLSPActionController.JumpKind）。
public enum EditorLSPActionJumpKind {
    case definition
    case declaration
    case typeDefinition
    case implementation
}

// MARK: - Rename Prompt Provider Protocol

/// 协议抽象：重命名交互能力（弹窗提示、状态消息等）。
///
/// App 侧的 `EditorRenameController` 遵循此协议。
@MainActor
public protocol EditorRenamePrompting {
    func promptForNewName() -> String?
    func cancelledMessage() -> String
    func inProgressMessage() -> String
    func failedMessage() -> String
    func notAppliedMessage() -> String
    func completedMessage(changedFiles: Int) -> String
}

// MARK: - EditorLanguageActionFacade

/// 编辑器语言操作门面。
///
/// 协调 LSP 语言操作（格式化、引用查找、跳转、重命名、调用层级）的纯逻辑门面。
/// 所有 App 侧依赖通过闭包参数或协议注入，不直接依赖任何 UI 框架。
@MainActor
public final class EditorLanguageActionFacade {

    public init() {}

    public func formatDocument(
        formattingController: EditorFormattingController,
        canPreview: Bool,
        isEditable: Bool,
        tabSize: Int,
        insertSpaces: Bool,
        requestFormatting: @escaping (_ tabSize: Int, _ insertSpaces: Bool) async -> [TextEdit]?,
        applyTextEdits: @escaping (_ edits: [TextEdit], _ reason: String) -> Void,
        showStatus: @escaping (_ message: String, _ level: EditorStatusLevel, _ duration: TimeInterval) -> Void
    ) async {
        await formattingController.formatDocument(
            canPreview: canPreview,
            isEditable: isEditable,
            tabSize: tabSize,
            insertSpaces: insertSpaces,
            requestFormatting: requestFormatting,
            applyTextEdits: applyTextEdits,
            showStatus: showStatus
        )
    }

    public func showReferences(
        currentFileURL: URL?,
        relativeFilePath: String,
        projectRootPath: String?,
        requestGenerationNext: () -> UInt64,
        isRequestCurrent: (UInt64) -> Bool,
        currentPosition: () -> (line: Int, character: Int),
        requestReferences: @escaping (_ line: Int, _ character: Int) async -> [Location],
        lspActionProvider: any EditorLSPActionProviding,
        previewLine: @escaping (_ url: URL, _ line: Int) -> String?,
        clearReferences: () -> Void,
        setReferenceResults: ([ReferenceResult]) -> Void,
        updateReferenceVisibility: (Bool) -> Void,
        syncSession: () -> Void,
        showStatus: (_ message: String, _ level: EditorStatusLevel, _ duration: TimeInterval) -> Void
    ) async {
        guard let fileURL = currentFileURL else { return }
        let requestGeneration = requestGenerationNext()
        let requestFileURL = fileURL
        showStatus(
            String(localized: "Finding references...", bundle: .module),
            .info,
            1.2
        )
        let position = currentPosition()
        let references = await requestReferences(position.line, position.character)
        guard isRequestCurrent(requestGeneration),
              currentFileURL == requestFileURL else { return }
        guard !references.isEmpty else {
            clearReferences()
            syncSession()
            showStatus(
                String(localized: "No references found", bundle: .module),
                .warning,
                1.8
            )
            return
        }

        let sortedItems = lspActionProvider.referenceResults(
            from: references,
            currentFileURL: fileURL,
            relativeFilePath: relativeFilePath,
            projectRootPath: projectRootPath,
            previewLine: previewLine
        )
        guard isRequestCurrent(requestGeneration),
              currentFileURL == requestFileURL else { return }
        setReferenceResults(sortedItems)
        updateReferenceVisibility(!sortedItems.isEmpty)
        syncSession()
        showStatus(
            String(localized: "Found references:", bundle: .module) + " \(sortedItems.count)",
            .success,
            1.8
        )
    }

    public func jump(
        selection: NSRange,
        kind: EditorLSPActionJumpKind,
        lspActionProvider: any EditorLSPActionProviding,
        showStatus: (_ message: String, _ level: EditorStatusLevel, _ duration: TimeInterval) -> Void,
        perform: @escaping (_ range: NSRange) async -> Void
    ) async {
        guard selection.location != NSNotFound else { return }
        showStatus(lspActionProvider.jumpKindStatusMessage(kind), .info, 1.2)
        await perform(selection)
    }

    public func promptRenameSymbol(
        canPreview: Bool,
        isEditable: Bool,
        renamePrompting: any EditorRenamePrompting,
        showStatus: (_ message: String, _ level: EditorStatusLevel, _ duration: TimeInterval) -> Void,
        runRename: @escaping (_ newName: String) -> Void
    ) {
        guard canPreview, isEditable else { return }
        guard let newName = renamePrompting.promptForNewName() else {
            showStatus(renamePrompting.cancelledMessage(), .warning, 1.8)
            return
        }

        showStatus(renamePrompting.inProgressMessage(), .info, 1.2)
        runRename(newName)
    }

    public func rename(
        newName: String,
        currentURI: String?,
        currentPosition: () -> (line: Int, character: Int),
        requestRename: @escaping (_ line: Int, _ character: Int, _ newName: String) async -> WorkspaceEdit?,
        workspaceEditController: EditorWorkspaceEditController,
        renamePrompting: any EditorRenamePrompting,
        applyCurrentDocumentEdits: @escaping (_ edits: [TextEdit], _ reason: String) -> Void,
        applyExternalFileEdits: @escaping (_ edits: [TextEdit], _ url: URL) -> Bool,
        showStatus: (_ message: String, _ level: EditorStatusLevel, _ duration: TimeInterval) -> Void
    ) async {
        guard let currentURI else { return }
        let position = currentPosition()
        guard let edit = await requestRename(position.line, position.character, newName) else {
            showStatus(renamePrompting.failedMessage(), .error, 1.8)
            return
        }

        let changedFiles = workspaceEditController.apply(
            changes: edit.changes,
            documentChanges: edit.documentChanges,
            currentURI: currentURI,
            applyCurrentDocumentEdits: applyCurrentDocumentEdits,
            applyExternalFileEdits: applyExternalFileEdits,
            applyCreateFile: WorkspaceEditFileOperations.applyCreateFile,
            applyRenameFile: WorkspaceEditFileOperations.applyRenameFile,
            applyDeleteFile: WorkspaceEditFileOperations.applyDeleteFile
        )

        if changedFiles == 0 {
            showStatus(renamePrompting.notAppliedMessage(), .warning, 1.8)
            return
        }

        showStatus(renamePrompting.completedMessage(changedFiles: changedFiles), .success, 1.8)
    }

    public func openCallHierarchy(
        callHierarchyController: EditorCallHierarchyController,
        currentFileURL: URL?,
        cursorLine: Int,
        cursorColumn: Int,
        prepare: @escaping (_ uri: String, _ line: Int, _ character: Int) async -> Void,
        hasRootItem: @escaping () -> Bool,
        showWarning: @escaping (_ message: String) -> Void,
        openPanel: @escaping () -> Void
    ) async {
        await callHierarchyController.openCallHierarchy(
            currentFileURL: currentFileURL,
            cursorLine: cursorLine,
            cursorColumn: cursorColumn,
            prepare: prepare,
            hasRootItem: hasRootItem,
            showWarning: showWarning,
            openPanel: openPanel
        )
    }
}
