import OpenInKit
import ProviderProject
import SwiftUI

/// Open In VS Code 的标题栏按钮。
struct OpenInVSCodeToolbarView: View {
    @StateObject private var model: OpenInVSCodeToolbarViewModel

    init(tool: OpenInTool, project: (any ProjectProviding)?) {
        _model = StateObject(wrappedValue: OpenInVSCodeToolbarViewModel(tool: tool, project: project))
    }

    var body: some View {
        Button {
            model.openProjectInVSCode()
        } label: {
            Image(systemName: OpenInTool.vscode.systemImage)
                .frame(width: 26, height: 26)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(model.isOpening || model.currentProjectPath == nil)
        .help(OpenInVSCodeLocalization.string("Open In VS Code"))
        .opacity(model.isOpening ? 0.5 : 1)
        .onDisappear {
            model.cancel()
        }
    }
}

// MARK: - 预览

#Preview("Open In VS Code Toolbar") {
    OpenInVSCodeToolbarView(tool: OpenInTool(config: OpenInTool.vscode, project: nil), project: nil)
        .padding()
}
