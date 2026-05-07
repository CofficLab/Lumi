import Foundation
import CodeEditSourceEditor
import CodeEditTextView

@MainActor
final class LSPRealtimeInteractionContributor: SuperEditorInteractionContributor {
    let id: String = "builtin.lsp.realtime-signals"

    func onTextDidChange(
        context: EditorInteractionContext,
        state: EditorState,
        controller: TextViewController
    ) async {
        state.scheduleInlayHintsRefreshIfNeeded(controller: controller)
        await maybeRequestSignatureHelp(context: context, state: state)
    }

    func onSelectionDidChange(
        context: EditorInteractionContext,
        state: EditorState,
        controller: TextViewController
    ) async {
        guard state.areDocumentHighlightsEnabled else {
            state.documentHighlightProvider.clear()
            state.scheduleInlayHintsRefreshIfNeeded(controller: controller)
            return
        }
        if let fileURL = state.currentFileURL, let content = state.content {
            if state.semanticCapability?.preflightError(
                uri: fileURL.absoluteString,
                operation: "文档高亮",
                symbolName: nil,
                strength: .soft
            ) != nil {
                state.documentHighlightProvider.clear()
                state.scheduleInlayHintsRefreshIfNeeded(controller: controller)
                return
            }
            await state.documentHighlightProvider.requestHighlight(
                uri: fileURL.absoluteString,
                line: context.line,
                character: context.character,
                content: content.string
            )
        }
        state.scheduleInlayHintsRefreshIfNeeded(controller: controller)
    }

    private func maybeRequestSignatureHelp(
        context: EditorInteractionContext,
        state: EditorState
    ) async {
        guard state.areSignatureHelpEnabled else {
            state.signatureHelpProvider.clear()
            return
        }

        guard let uri = state.currentFileURL?.absoluteString else {
            state.signatureHelpProvider.clear()
            return
        }
        if state.semanticCapability?.preflightError(
            uri: uri,
            operation: "签名帮助",
            symbolName: nil,
            strength: .soft
        ) != nil {
            state.signatureHelpProvider.clear()
            return
        }

        if context.typedCharacter == ")" {
            state.signatureHelpProvider.clear()
            return
        }

        guard let typed = context.typedCharacter,
              state.signatureHelpProvider.triggerCharacters.contains(typed) else {
            return
        }

        await state.signatureHelpProvider.requestSignatureHelp(
            uri: uri,
            line: context.line,
            character: context.character,
            preflight: { [weak state] in
                state?.semanticCapability?.preflightError(
                    uri: uri,
                    operation: "签名帮助",
                    symbolName: nil,
                    strength: .soft
                ) == nil
            }
        )
    }
}
