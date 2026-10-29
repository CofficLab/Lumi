import SwiftUI

/// Open In Remote 的标题栏按钮。
struct OpenInRemoteToolbarView: View {
    @StateObject private var model: OpenInRemoteToolbarViewModel

    init(
        projectCapability: OpenInRemoteProjectCapability,
        resolver: RemoteRepositoryResolver,
        toastCapability: OpenInRemoteToastCapability
    ) {
        _model = StateObject(
            wrappedValue: OpenInRemoteToolbarViewModel(
                projectCapability: projectCapability,
                resolver: resolver,
                toastCapability: toastCapability
            )
        )
    }

    var body: some View {
        Button {
            model.openRemoteRepository()
        } label: {
            Image(systemName: OpenInRemoteConstants.systemImage)
                .frame(width: 26, height: 26)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(model.isOpening || model.currentProjectPath == nil)
        .help(OpenInRemoteLocalization.string("Open In Remote"))
        .opacity(model.isOpening ? 0.5 : 1)
        .onDisappear {
            model.cancel()
        }
    }
}

// MARK: - 预览

#Preview("Open In Remote Toolbar") {
    OpenInRemoteToolbarView(
        projectCapability: OpenInRemoteProjectCapabilityAdapter(project: nil),
        resolver: RemoteRepositoryResolver(
            gitCapability: OpenInRemoteGitCapabilityAdapter(provider: nil)
        ),
        toastCapability: OpenInRemoteToastCapabilityAdapter(toast: nil)
    )
    .padding()
}
