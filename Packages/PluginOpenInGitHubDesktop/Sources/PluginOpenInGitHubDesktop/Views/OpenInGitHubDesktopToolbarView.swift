import OpenInKit
import ProviderProject
import SwiftUI

/// Open In GitHub Desktop 的标题栏按钮。
struct OpenInGitHubDesktopToolbarView: View {
    @StateObject private var model: OpenInGitHubDesktopToolbarViewModel

    init(tool: OpenInTool, project: (any ProjectProviding)?) {
        _model = StateObject(wrappedValue: OpenInGitHubDesktopToolbarViewModel(tool: tool, project: project))
    }

    var body: some View {
        Button {
            model.openProjectInGitHubDesktop()
        } label: {
            Image(systemName: OpenInTool.gitHubDesktop.systemImage)
                .frame(width: 26, height: 26)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(model.isOpening || model.currentProjectPath == nil)
        .help(OpenInGitHubDesktopLocalization.string("Open In GitHub Desktop"))
        .opacity(model.isOpening ? 0.5 : 1)
        .onDisappear {
            model.cancel()
        }
    }
}

// MARK: - 预览

#Preview("Open In GitHub Desktop Toolbar") {
    OpenInGitHubDesktopToolbarView(tool: OpenInTool(config: OpenInTool.gitHubDesktop, project: nil), project: nil)
        .padding()
}
