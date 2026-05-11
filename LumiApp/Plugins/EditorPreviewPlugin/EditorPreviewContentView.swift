#if canImport(LumiPreviewKit)
import LumiPreviewKit
import SwiftUI

struct EditorPreviewContentView: View {
    @EnvironmentObject private var editorVM: EditorVM
    @EnvironmentObject private var themeVM: ThemeVM
    @StateObject private var viewModel = EditorPreviewViewModel()

    private var sourceText: String? {
        editorVM.service.content?.string
    }

    private var currentFileURL: URL? {
        editorVM.service.currentFileURL
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            content
        }
        .background(themeVM.activeAppTheme.workspaceBackgroundColor())
        .onAppear {
            refreshScanAndStartIfNeeded()
        }
        .onChange(of: currentFileURL) { _, _ in
            viewModel.stopPreview()
            refreshScanAndStartIfNeeded()
        }
        .onChange(of: sourceText ?? "") { _, _ in
            refreshScanAndStartIfNeeded(allowsStopped: false)
        }
    }

    private var toolbar: some View {
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

            statusBadge

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

    private var statusBadge: some View {
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

    @ViewBuilder
    private var content: some View {
        if viewModel.previews.isEmpty {
            emptyState
        } else {
            HStack(spacing: 0) {
                previewList
                    .frame(width: 240)
                Divider()
                previewDetail
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "number")
                .font(.system(size: 24, weight: .thin))
                .foregroundColor(themeVM.activeAppTheme.workspaceTertiaryTextColor())
            Text(String(localized: "No #Preview macros found", table: "EditorPreview"))
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(themeVM.activeAppTheme.workspaceSecondaryTextColor())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 24)
    }

    private var previewList: some View {
        List(selection: $viewModel.selectedPreviewID) {
            ForEach(viewModel.previews, id: \.id) { preview in
                VStack(alignment: .leading, spacing: 4) {
                    Text(preview.title)
                        .font(.system(size: 12, weight: .semibold))
                    Text(String(format: String(localized: "Lines %lld-%lld", table: "EditorPreview"), preview.lineNumber, preview.endLineNumber))
                        .font(.system(size: 11))
                        .foregroundColor(themeVM.activeAppTheme.workspaceSecondaryTextColor())
                }
                .tag(preview.id)
                .padding(.vertical, 3)
            }
        }
        .listStyle(.sidebar)
    }

    private var previewDetail: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let preview = viewModel.selectedPreview {
                previewHeader(preview)

                if case .failed(let message) = viewModel.runState {
                    Text(message)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.red)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else if viewModel.runState == .hostMissing {
                    Text(String(localized: "Set LUMI_PREVIEW_HOST_EXECUTABLE or embed LumiPreviewHostApp in Contents/Helpers.", table: "EditorPreview"))
                        .font(.system(size: 11))
                        .foregroundColor(.red)
                        .textSelection(.enabled)
                } else if let diagnostics = viewModel.diagnostics {
                    diagnosticsView(diagnostics)
                } else {
                    previewSurface(preview)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func diagnosticsView(_ diagnostics: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(String(localized: "Preview build failed", table: "EditorPreview"), systemImage: "exclamationmark.triangle")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.red)

            ScrollView {
                Text(diagnostics)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(themeVM.activeAppTheme.workspaceTextColor())
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .padding(12)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.red.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.red.opacity(0.22), lineWidth: 1)
        )
    }

    private func previewHeader(_ preview: PreviewDiscovery) -> some View {
        HStack(spacing: 8) {
            Text(preview.title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(themeVM.activeAppTheme.workspaceTextColor())

            if let primaryTypeName = preview.primaryTypeName {
                Label(primaryTypeName, systemImage: "swift")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(themeVM.activeAppTheme.workspaceSecondaryTextColor())
            }

            Spacer(minLength: 0)
        }
    }

    private func previewSurface(_ preview: PreviewDiscovery) -> some View {
        VStack(spacing: 14) {
            Spacer(minLength: 0)

            if let renderImage = viewModel.renderImage {
                Image(nsImage: renderImage)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 420, maxHeight: 260)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(themeVM.activeAppTheme.workspaceTertiaryTextColor().opacity(0.18), lineWidth: 1)
                    )
            } else {
                Image(systemName: surfaceIconName)
                    .font(.system(size: 28, weight: .light))
                    .foregroundColor(statusColor)
            }

            VStack(spacing: 5) {
                Text(surfaceTitle(for: preview))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(themeVM.activeAppTheme.workspaceTextColor())
                    .multilineTextAlignment(.center)

                if let renderMessage = viewModel.renderMessage {
                    Text(renderMessage)
                        .font(.system(size: 11))
                        .foregroundColor(themeVM.activeAppTheme.workspaceSecondaryTextColor())
                        .multilineTextAlignment(.center)
                }

                if let performanceSummary = viewModel.performanceSummary {
                    Text(performanceSummary)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(themeVM.activeAppTheme.workspaceTertiaryTextColor())
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: 360)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(themeVM.activeAppTheme.workspaceTertiaryTextColor().opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var surfaceIconName: String {
        switch viewModel.runState {
        case .running:
            "play.rectangle.fill"
        case .starting:
            "hourglass"
        case .stopped:
            "stop.circle"
        case .idle:
            "play.rectangle"
        case .failed:
            "exclamationmark.triangle"
        case .hostMissing:
            "xmark.octagon"
        }
    }

    private func surfaceTitle(for preview: PreviewDiscovery) -> String {
        switch viewModel.runState {
        case .running:
            String(format: String(localized: "Preview host rendered %@", table: "EditorPreview"), preview.title)
        case .starting:
            String(localized: "Building preview", table: "EditorPreview")
        case .stopped:
            String(localized: "Preview stopped", table: "EditorPreview")
        case .idle:
            String(localized: "Ready to start preview", table: "EditorPreview")
        case .failed:
            String(localized: "Preview failed", table: "EditorPreview")
        case .hostMissing:
            String(localized: "Preview host missing", table: "EditorPreview")
        }
    }

    private func refreshScan() {
        viewModel.update(sourceText: sourceText, fileURL: currentFileURL)
    }

    private func refreshScanAndStartIfNeeded(allowsStopped: Bool = true) {
        refreshScan()
        viewModel.startSelectedPreviewIfNeeded(allowsStopped: allowsStopped)
    }
}
#else
import SwiftUI

struct EditorPreviewContentView: View {
    var body: some View {
        EmptyView()
    }
}
#endif
