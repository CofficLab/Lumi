import OpenInKit
import ProviderProject
import SwiftUI

/// Open In Cursor 的标题栏按钮。
struct OpenInCursorToolbarView: View {
    @StateObject private var model: OpenInCursorToolbarViewModel

    init(tool: OpenInTool, project: (any ProjectProviding)?) {
        _model = StateObject(wrappedValue: OpenInCursorToolbarViewModel(tool: tool, project: project))
    }

    var body: some View {
        Button {
            model.openProjectInCursor()
        } label: {
            Image(systemName: OpenInTool.cursor.systemImage)
                .frame(width: 26, height: 26)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(model.isOpening || model.currentProjectPath == nil)
        .help(OpenInCursorLocalization.string("Open In Cursor"))
        .opacity(model.isOpening ? 0.5 : 1)
        .onDisappear {
            model.cancel()
        }
    }
}

// MARK: - 预览

#Preview("Open In Cursor Toolbar") {
    OpenInCursorToolbarView(tool: OpenInTool(config: OpenInTool.cursor, project: nil), project: nil)
        .padding()
}
