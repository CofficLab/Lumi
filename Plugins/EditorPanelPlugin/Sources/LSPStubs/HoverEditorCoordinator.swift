import Foundation
import EditorService
import SuperLogKit
import os

/// Local stub for `HoverEditorCoordinator`.
///
/// The original implementation lived in `LSPRealtimeSignalsPlugin/HoverCoordinator.swift`
/// (≈900 lines) and was deleted in `5d4b41b23 chore: remove 23 unregistered plugins`
/// without a follow-up to migrate the protocol-level LSP hover implementation into
/// `EditorService`. `EditorPanelPlugin` still references this type to coordinate
/// hover lifecycle, so a placeholder keeps the editor building.
///
/// Behavior:
/// - Construction is a no-op.
/// - `cancelHover()` is a no-op.
/// - The coordinator does not register any LSP protocol handlers.
///
/// See `LSPStubs/README.md` (if added) for the migration plan.
public final class HoverEditorCoordinator: TextViewCoordinator, SuperLog {
    public nonisolated static let emoji = "🟪"
    public nonisolated static let verbose: Bool = false
    public nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi",
        category: "editor-panel.stub.hover-coordinator"
    )

    public init(state: EditorState) {
        // Intentional no-op: see file header.
    }

    public func cancelHover() {
        // Intentional no-op: see file header.
    }

    // MARK: - TextViewCoordinator

    public func prepareCoordinator(controller: TextViewController) {
        // Intentional no-op: see file header.
    }
}
