import Foundation
import CodeEditSourceEditor
import CodeEditTextView

@objc(LumiLSPRealtimeSignalsEditorPlugin)
@MainActor
final class LSPRealtimeSignalsEditorPlugin: NSObject, EditorFeaturePlugin {
    let id: String = "builtin.lsp.realtime-signals"
    let displayName: String = "LSP Realtime Signals"
    let order: Int = 18

    func register(into registry: EditorExtensionRegistry) {
        registry.registerInteractionContributor(LSPRealtimeInteractionContributor())
    }
}

@MainActor
final class LSPRealtimeInteractionContributor: EditorInteractionContributor {
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
        if let fileURL = state.currentFileURL, let content = state.content {
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
        guard let uri = state.currentFileURL?.absoluteString else {
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
            character: context.character
        )
    }
}
