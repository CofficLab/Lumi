import SwiftUI
import EditorService

/// Local stub for `SignatureHelpView`.
///
/// The original implementation lived in `LSPSignatureHelpEditorPlugin/Views/SignatureHelpView.swift`
/// and was deleted in `5d4b41b23 chore: remove 23 unregistered plugins`
/// without a follow-up to migrate the LSP signature-help overlay into
/// `EditorService`. `EditorPanelPlugin` still references this view in
/// `signatureHelpOverlay`, so a placeholder keeps the editor building.
///
/// Behavior:
/// - Always renders an empty view.
/// - Will never be reached at runtime today: `state.currentSignatureHelpOverlayItem`
///   is fed by `SignatureHelpProvider`, which was deleted in the same commit; the
///   overlay branch is therefore a dead path. Keep this stub until signature-help
///   is reintroduced through a non-LSP plugin or the LSP provider is restored.
public struct SignatureHelpView: View {
    public let item: SignatureHelpItem

    public init(item: SignatureHelpItem) {
        self.item = item
    }

    public var body: some View {
        // Empty view: the original signature-help overlay no longer has a
        // backing provider. See file header for context.
        EmptyView()
    }
}
