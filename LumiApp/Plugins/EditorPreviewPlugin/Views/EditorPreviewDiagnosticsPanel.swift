import LumiPreviewKit
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

            infoRow(label: String(localized: "Frame", table: "EditorPreview"), value: viewModel.lastFrameSummary)

            if let performanceSummary = viewModel.performanceSummary {
                infoRow(label: String(localized: "Performance", table: "EditorPreview"), value: performanceSummary)
            }

            infoRow(label: String(localized: "Live", table: "EditorPreview"), value: localizedLiveState(viewModel.livePreviewInfo.state))
            infoRow(label: String(localized: "Display", table: "EditorPreview"), value: localizedDisplayMode(viewModel.effectiveDisplayMode))
            infoRow(label: String(localized: "Transport", table: "EditorPreview"), value: viewModel.transportSummary)

            if let modeStatusMessage = viewModel.modeStatusMessage {
                infoRow(label: String(localized: "Mode", table: "EditorPreview"), value: modeStatusMessage, color: .orange, lineLimit: 4)
            }

            if let renderMessage = viewModel.renderMessage {
                infoRow(label: String(localized: "Render", table: "EditorPreview"), value: renderMessage)
            }

            if let liveReason = viewModel.livePreviewInfo.unavailableReason, !liveReason.isEmpty {
                infoRow(label: String(localized: "Live Error", table: "EditorPreview"), value: liveReason, color: .orange, lineLimit: 4)
            }

            if let diagnostics = viewModel.diagnostics, !diagnostics.isEmpty {
                infoRow(label: String(localized: "Diagnostics", table: "EditorPreview"), value: diagnostics, color: .orange, lineLimit: 6)
            }

            if let failureMessage = viewModel.failureMessage {
                infoRow(label: String(localized: "Failure", table: "EditorPreview"), value: failureMessage, color: .red, lineLimit: 6)
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

    private func localizedLiveState(_ state: LumiPreviewFacade.LivePreviewState) -> String {
        switch state {
        case .unavailable:
            String(localized: "Unavailable", table: "EditorPreview")
        case .available:
            String(localized: "Available", table: "EditorPreview")
        case .launching:
            String(localized: "Launching", table: "EditorPreview")
        case .running:
            String(localized: "Running", table: "EditorPreview")
        case .failed:
            String(localized: "Failed", table: "EditorPreview")
        case .stopped:
            String(localized: "Stopped", table: "EditorPreview")
        }
    }

    private func localizedDisplayMode(_ mode: LumiPreviewFacade.PreviewDisplayMode) -> String {
        switch mode {
        case .image:
            String(localized: "Image", table: "EditorPreview")
        case .live:
            String(localized: "Live", table: "EditorPreview")
        }
    }
}
