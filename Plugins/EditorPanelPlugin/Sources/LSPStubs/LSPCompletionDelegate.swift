import Foundation
import EditorService
import EditorSource
import SuperLogKit
import os

/// Local stub for `LSPCompletionDelegate`.
///
/// The original implementation lived in `LSPRealtimeSignalsPlugin/Completion/LSPCompletionDelegate.swift`
/// (≈900 lines) and was deleted in `5d4b41b23 chore: remove 23 unregistered plugins`
/// without a follow-up to migrate the LSP completion flow into `EditorService`.
/// `EditorPanelPlugin` still needs a `CodeSuggestionDelegate` to drive the
/// in-editor completion UI, so this placeholder keeps the editor building and
/// returns no suggestions.
///
/// Behavior:
/// - No LSP `textDocument/completion` request is issued.
/// - `configure(...)` records the latest `lspClient`, `editorExtensionRegistry`,
///   and `editorState` so future migrations can pick them up without changing the
///   bridge wire-up signature.
public final class LSPCompletionDelegate: NSObject, CodeSuggestionDelegate, SuperLog {
    public nonisolated static let emoji = "💡"
    public nonisolated static let verbose: Bool = false
    public nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi",
        category: "editor-panel.stub.completion-delegate"
    )

    weak var lspClient: (any SuperEditorLSPClient)?
    weak var editorExtensionRegistry: EditorExtensionRegistry?
    weak var editorState: EditorState?

    public func configure(
        lspClient: (any SuperEditorLSPClient)?,
        editorExtensionRegistry: EditorExtensionRegistry?,
        editorState: EditorState?
    ) {
        self.lspClient = lspClient
        self.editorExtensionRegistry = editorExtensionRegistry
        self.editorState = editorState
    }

    // MARK: - CodeSuggestionDelegate

    public func completionSuggestionsRequested(
        textView: TextViewController,
        cursorPosition: CursorPosition
    ) async -> (windowPosition: CursorPosition, items: [CodeSuggestionEntry])? {
        nil
    }

    public func completionOnCursorMove(
        textView: TextViewController,
        cursorPosition: CursorPosition
    ) -> [CodeSuggestionEntry]? {
        nil
    }

    public func completionWindowApplyCompletion(
        item: CodeSuggestionEntry,
        textView: TextViewController,
        cursorPosition: CursorPosition?
    ) {
        // Intentional no-op: see file header.
    }
}
