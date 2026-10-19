import OpenInKit
import SwiftUI

/// Open In Finder 的标题栏按钮。
struct OpenInFinderToolbarView: View {
    @StateObject private var model: OpenInFinderToolbarViewModel

    init(tool: OpenInTool, projectCapability: OpenInProjectCapability) {
        _model = StateObject(wrappedValue: OpenInFinderToolbarViewModel(tool: tool, projectCapability: projectCapability))
    }

    var body: some View {
        Button {
            model.openProjectInFinder()
        } label: {
            Image(systemName: OpenInTool.finder.systemImage)
                .frame(width: 26, height: 26)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(model.isOpening || model.currentProjectPath == nil)
        .help(OpenInFinderLocalization.string("Open In Finder"))
        .opacity(model.isOpening ? 0.5 : 1)
        .onDisappear {
            model.cancel()
        }
    }
}

// MARK: - 预览

#Preview("Open In Finder Toolbar") {
    OpenInFinderToolbarView(tool: OpenInTool(config: OpenInTool.finder, project: nil), projectCapability: OpenInProjectCapabilityAdapter(project: nil))
        .padding()
}
