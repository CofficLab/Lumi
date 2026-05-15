import SwiftUI

struct HotPreviewDiagnosticsPanel: View {
    @EnvironmentObject private var themeVM: ThemeVM
    @ObservedObject var viewModel: EditorRemoteHotPreviewViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: "Diagnostics", table: "EditorPreview"))
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(themeVM.activeAppTheme.workspaceTextColor())

            Divider()

            infoRow(label: "Frame", value: viewModel.lastFrameSummary)

            if let performanceSummary = viewModel.performanceSummary {
                infoRow(label: "Performance", value: performanceSummary)
            }

            infoRow(label: "Live", value: viewModel.livePreviewInfo.state.rawValue)
            infoRow(label: "Display", value: viewModel.effectiveDisplayMode.rawValue)
            infoRow(label: "Transport", value: viewModel.transportSummary)

            if let modeStatusMessage = viewModel.modeStatusMessage {
                infoRow(label: "Mode", value: modeStatusMessage, color: .orange, lineLimit: 4)
            }

            if let renderMessage = viewModel.renderMessage {
                infoRow(label: "Render", value: renderMessage)
            }

            if let liveReason = viewModel.livePreviewInfo.unavailableReason, !liveReason.isEmpty {
                infoRow(label: "Live Error", value: liveReason, color: .orange, lineLimit: 4)
            }

            if let diagnostics = viewModel.diagnostics, !diagnostics.isEmpty {
                infoRow(label: "Diagnostics", value: diagnostics, color: .orange, lineLimit: 6)
            }

            if let failureMessage = viewModel.failureMessage {
                infoRow(label: "Failure", value: failureMessage, color: .red, lineLimit: 6)
            }

            Divider()

            Text(viewModel.diagnosticSummary)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(themeVM.activeAppTheme.workspaceSecondaryTextColor())
                .lineLimit(5)
                .textSelection(.enabled)
        }
        .padding(14)
        .frame(width: 340)
    }

    private func infoRow(
        label: String,
        value: String,
        color: Color? = nil,
        lineLimit: Int? = 2
    ) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(themeVM.activeAppTheme.workspaceSecondaryTextColor())
            Text(value)
                .font(.system(size: 11))
                .foregroundColor(color ?? themeVM.activeAppTheme.workspaceSecondaryTextColor())
                .lineLimit(lineLimit ?? 2)
                .textSelection(.enabled)
        }
    }
}
