import KitOpenIn
import SwiftUI

/// Open In Antigravity 的标题栏按钮。
struct OpenInAntigravityToolbarView: View {
    @StateObject private var model: OpenInAntigravityToolbarViewModel

    init(tool: OpenInTool, projectCapability: OpenInProjectCapability) {
        _model = StateObject(wrappedValue: OpenInAntigravityToolbarViewModel(tool: tool, projectCapability: projectCapability))
    }

    var body: some View {
        Button {
            model.openProjectInAntigravity()
        } label: {
            Image(systemName: OpenInTool.antigravity.systemImage)
                .frame(width: 26, height: 26)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(model.isOpening || model.currentProjectPath == nil)
        .help(OpenInAntigravityLocalization.string("Open In Antigravity"))
        .opacity(model.isOpening ? 0.5 : 1)
        .onDisappear {
            model.cancel()
        }
    }
}

// MARK: - 预览

#Preview("Open In Antigravity Toolbar") {
    OpenInAntigravityToolbarView(tool: OpenInTool(config: OpenInTool.antigravity, project: nil), projectCapability: OpenInProjectCapabilityAdapter(project: nil))
        .padding()
}
