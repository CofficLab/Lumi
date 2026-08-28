import EditorService
import SwiftUI

struct EditorStatusBarView: View {
    @ObservedObject private var state: EditorState
    private let controller: EditorWorkspaceController

    init(controller: EditorWorkspaceController) {
        self.controller = controller
        _state = ObservedObject(wrappedValue: controller.editor.state)
    }

    var body: some View {
        HStack(spacing: 14) {
            if controller.editor.files.hasExternalFileConflict {
                Label("File changed on disk", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
            } else if controller.editor.files.hasUnsavedChanges {
                Label("Modified", systemImage: "circle.fill")
            } else {
                Label("Saved", systemImage: "checkmark")
            }

            Spacer()
            Text("Ln \(state.cursorLine), Col \(state.cursorColumn)")
            Text(state.useSpaces ? "Spaces: \(state.tabWidth)" : "Tab Size: \(state.tabWidth)")
            Text("UTF-8")
            Text(state.detectedLanguage?.descriptor.displayName ?? "Plain Text")
            if !controller.editor.files.isEditable {
                Label("Read Only", systemImage: "lock")
            }
        }
        .font(.caption2)
        .padding(.horizontal, 10)
        .frame(height: 24)
        .background(Color(nsColor: .controlBackgroundColor))
    }
}
