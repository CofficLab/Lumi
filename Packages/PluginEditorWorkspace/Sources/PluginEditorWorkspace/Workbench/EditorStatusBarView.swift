import SwiftUI

struct EditorStatusBarView: View {
    @ObservedObject var controller: EditorWorkspaceController

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
            Text("Ln \(controller.editor.editing.cursorLine), Col \(controller.editor.editing.cursorColumn)")
            Text(controller.editor.state.useSpaces ? "Spaces: \(controller.editor.state.tabWidth)" : "Tab Size: \(controller.editor.state.tabWidth)")
            Text("UTF-8")
            Text(controller.editor.state.detectedLanguage?.descriptor.displayName ?? "Plain Text")
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
