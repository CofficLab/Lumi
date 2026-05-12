#if canImport(LumiPreviewKit)
import SwiftUI

struct EditorPreviewToolbarView: View {
    @EnvironmentObject private var themeVM: ThemeVM
    @ObservedObject var viewModel: EditorPreviewViewModel
    let currentFileURL: URL?

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "rectangle.on.rectangle")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(themeVM.activeAppTheme.workspaceSecondaryTextColor())

            Text(String(localized: "Editor Preview", table: "EditorPreview"))
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(themeVM.activeAppTheme.workspaceTextColor())

            if let currentFileURL {
                Text(currentFileURL.lastPathComponent)
                    .font(.system(size: 11))
                    .foregroundColor(themeVM.activeAppTheme.workspaceSecondaryTextColor())
            }

            Spacer(minLength: 0)

            EditorPreviewDisplayModePickerView(viewModel: viewModel)

            EditorPreviewStatusBadgeView(viewModel: viewModel)

            Button {
                viewModel.startSelectedPreview()
            } label: {
                Image(systemName: "play.fill")
                    .font(.system(size: 11, weight: .medium))
            }
            .buttonStyle(.plain)
            .disabled(!viewModel.canStart)
            .help(String(localized: "Start preview", table: "EditorPreview"))

            Button {
                viewModel.refreshPreview()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 11, weight: .medium))
            }
            .buttonStyle(.plain)
            .disabled(!viewModel.canRefresh)
            .help(String(localized: "Refresh preview", table: "EditorPreview"))

            Button {
                viewModel.stopPreview()
            } label: {
                Image(systemName: "stop.fill")
                    .font(.system(size: 11, weight: .medium))
            }
            .buttonStyle(.plain)
            .disabled(!viewModel.canStop)
            .help(String(localized: "Stop preview", table: "EditorPreview"))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(themeVM.activeAppTheme.workspaceTertiaryTextColor().opacity(0.05))
    }
}

struct EditorPreviewStatusBadgeView: View {
    @EnvironmentObject private var themeVM: ThemeVM
    @ObservedObject var viewModel: EditorPreviewViewModel

    var body: some View {
        Text(viewModel.runState.title)
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(statusColor)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(statusColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 5))
    }

    private var statusColor: Color {
        switch viewModel.runState {
        case .running:
            .green
        case .failed, .hostMissing:
            .red
        case .starting:
            .orange
        case .idle, .stopped:
            themeVM.activeAppTheme.workspaceSecondaryTextColor()
        }
    }
}
#endif
