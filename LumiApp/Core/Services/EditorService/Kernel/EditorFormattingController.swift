import Foundation
import LanguageServerProtocol

@MainActor
final class EditorFormattingController {
    func formatDocument(
        canPreview: Bool,
        isEditable: Bool,
        tabSize: Int,
        insertSpaces: Bool,
        requestFormatting: @escaping (_ tabSize: Int, _ insertSpaces: Bool) async -> [TextEdit]?,
        applyTextEdits: (_ edits: [TextEdit], _ reason: String) -> Void,
        showStatus: (_ message: String, _ level: EditorStatusLevel, _ duration: TimeInterval) -> Void
    ) async {
        guard canPreview, isEditable else { return }
        showStatus(
            String(localized: "Formatting document...", table: "LumiEditor"),
            .info,
            1.2
        )

        let perfToken = EditorPerformance.shared.begin(.editFormat)
        guard let edits = await requestFormatting(tabSize, insertSpaces),
              !edits.isEmpty else {
            EditorPerformance.shared.cancel(perfToken)
            showStatus(
                String(localized: "No formatting changes", table: "LumiEditor"),
                .warning,
                1.8
            )
            return
        }

        applyTextEdits(edits, "lsp_format_document")
        EditorPerformance.shared.end(perfToken)
        showStatus(
            String(localized: "Document formatted", table: "LumiEditor"),
            .success,
            1.8
        )
    }

    func prepareSaveFormatting(
        text: String,
        tabSize: Int,
        insertSpaces: Bool,
        requestFormatting: @escaping (_ tabSize: Int, _ insertSpaces: Bool) async -> [TextEdit]?
    ) async -> String? {
        guard let edits = await requestFormatting(tabSize, insertSpaces),
              edits.isEmpty == false else {
            return nil
        }
        return TextEditApplier.apply(edits: edits, to: text)
    }
}
