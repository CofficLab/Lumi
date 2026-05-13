import SwiftUI

struct HotPreviewToolbar: View {
    @EnvironmentObject private var themeVM: ThemeVM
    @ObservedObject var viewModel: EditorRemoteHotPreviewViewModel

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "bolt.horizontal")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(themeVM.activeAppTheme.workspaceSecondaryTextColor())

            Text(String(localized: "Hot Preview", table: "EditorPreviewRemoteHotPlugin"))
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(themeVM.activeAppTheme.workspaceTextColor())

            Spacer(minLength: 0)

            if let updateTitle = viewModel.updatePhase.title {
                updateBadge(updateTitle)
            }

            statusBadge

            Button {
                viewModel.startHost()
            } label: {
                Image(systemName: "play.fill")
                    .font(.system(size: 11, weight: .medium))
            }
            .buttonStyle(.plain)
            .disabled(!viewModel.canStart)
            .help(String(localized: "Start hot preview", table: "EditorPreviewRemoteHotPlugin"))

            Button {
                viewModel.renderFrame()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 11, weight: .medium))
            }
            .buttonStyle(.plain)
            .disabled(viewModel.hostState == .idle)
            .help(String(localized: "Refresh hot preview", table: "EditorPreviewRemoteHotPlugin"))

            Button {
                viewModel.stopHost()
            } label: {
                Image(systemName: "stop.fill")
                    .font(.system(size: 11, weight: .medium))
            }
            .buttonStyle(.plain)
            .disabled(!viewModel.canStop)
            .help(String(localized: "Stop hot preview", table: "EditorPreviewRemoteHotPlugin"))
        }
        .frame(maxWidth: .infinity, minHeight: 38, maxHeight: 38, alignment: .leading)
        .padding(.horizontal, 12)
        .background(themeVM.activeAppTheme.workspaceTertiaryTextColor().opacity(0.05))
    }

    private var statusBadge: some View {
        let statusColor = Self.statusColor(for: viewModel.hostState, theme: themeVM.activeAppTheme)
        return HStack(spacing: 5) {
            Circle()
                .fill(statusColor)
                .frame(width: 7, height: 7)
            Text(viewModel.hostState.title)
                .lineLimit(1)
        }
        .font(.system(size: 11, weight: .medium))
        .foregroundColor(statusColor)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(statusColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 5))
    }

    private func updateBadge(_ title: String) -> some View {
        HStack(spacing: 5) {
            ProgressView()
                .controlSize(.small)
                .scaleEffect(0.55)
                .frame(width: 10, height: 10)
            Text(title)
                .lineLimit(1)
        }
        .font(.system(size: 11, weight: .medium))
        .foregroundColor(.orange)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(Color.orange.opacity(0.14), in: RoundedRectangle(cornerRadius: 5))
    }

    private static func statusColor(
        for hostState: EditorRemoteHotPreviewHostState,
        theme: any SuperTheme
    ) -> Color {
        switch hostState {
        case .idle:
            return theme.workspaceSecondaryTextColor().opacity(0.7)
        case .launching, .rendering:
            return .orange
        case .connected:
            return .green
        case .failed:
            return .red
        }
    }
}
