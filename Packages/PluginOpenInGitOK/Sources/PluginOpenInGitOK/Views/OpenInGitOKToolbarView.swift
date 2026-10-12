import OpenInKit
import ProviderProject
import SwiftUI

/// Open In GitOK 的标题栏按钮。
struct OpenInGitOKToolbarView: View {
    @StateObject private var model: OpenInGitOKToolbarViewModel

    init(tool: OpenInTool, project: (any ProjectProviding)?) {
        _model = StateObject(wrappedValue: OpenInGitOKToolbarViewModel(tool: tool, project: project))
    }

    var body: some View {
        Button {
            model.openProjectInGitOK()
        } label: {
            Image(systemName: OpenInTool.gitOK.systemImage)
                .frame(width: 26, height: 26)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(model.isOpening || model.currentProjectPath == nil)
        .help(OpenInGitOKLocalization.string("Open In GitOK"))
        .opacity(model.isOpening ? 0.5 : 1)
        .onDisappear {
            model.cancel()
        }
    }
}

// MARK: - 预览

#Preview("Open In GitOK Toolbar") {
    OpenInGitOKToolbarView(tool: OpenInTool(config: OpenInTool.gitOK, project: nil), project: nil)
        .padding()
}
