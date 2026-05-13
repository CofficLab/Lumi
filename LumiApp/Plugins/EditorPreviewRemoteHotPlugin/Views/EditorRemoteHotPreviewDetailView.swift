import AppKit
import LumiPreviewKit
import SwiftUI

struct EditorRemoteHotPreviewDetailView: View {
    @EnvironmentObject private var editorVM: EditorVM
    @EnvironmentObject private var themeVM: ThemeVM
    @StateObject private var viewModel = EditorRemoteHotPreviewViewModel()

    private var sourceText: String? {
        editorVM.service.content?.string
    }

    private var currentFileURL: URL? {
        editorVM.service.currentFileURL
    }

    private var refreshSignal: LumiPreviewPackage.EditorPreviewRefreshSignal {
        LumiPreviewPackage.EditorPreviewRefreshSignal(
            fileURL: currentFileURL,
            contentRevision: editorVM.service.contentRevision,
            saveRevision: editorVM.service.saveRevision
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            content
        }
        .background(themeVM.activeAppTheme.workspaceBackgroundColor())
        .onAppear {
            refreshScanAndStartIfNeeded()
        }
        .onChange(of: currentFileURL) { _, _ in
            refreshScanAndStartIfNeeded()
        }
        .onChange(of: refreshSignal) { _, _ in
            refreshScanAndReloadIfNeeded()
        }
    }

    private var toolbar: some View {
        HStack(spacing: 8) {
            Image(systemName: "bolt.rectangle")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(themeVM.activeAppTheme.workspaceSecondaryTextColor())

            Text("Hot Preview")
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
            .help("Start hot preview")

            Button {
                viewModel.renderFrame()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 11, weight: .medium))
            }
            .buttonStyle(.plain)
            .disabled(viewModel.hostState == .idle)
            .help("Refresh hot preview")

            Button {
                if viewModel.livePreviewInfo.state == .running || viewModel.livePreviewInfo.state == .launching {
                    viewModel.stopLivePreview()
                } else {
                    viewModel.startLivePreview()
                }
            } label: {
                Image(systemName: viewModel.livePreviewInfo.state == .running ? "bolt.slash" : "bolt.fill")
                    .font(.system(size: 11, weight: .medium))
            }
            .buttonStyle(.plain)
            .disabled(!(viewModel.canStartLive || viewModel.canStopLive))
            .help(viewModel.livePreviewInfo.state == .running ? "Stop hot live preview" : "Start hot live preview")

            Button {
                viewModel.stopHost()
            } label: {
                Image(systemName: "stop.fill")
                    .font(.system(size: 11, weight: .medium))
            }
            .buttonStyle(.plain)
            .disabled(!viewModel.canStop)
            .help("Stop hot preview")
        }
        .frame(maxWidth: .infinity, minHeight: 38, maxHeight: 38, alignment: .leading)
        .padding(.horizontal, 12)
        .background(themeVM.activeAppTheme.workspaceTertiaryTextColor().opacity(0.05))
    }

    private var statusBadge: some View {
        HStack(spacing: 5) {
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

    private var content: some View {
        HStack(spacing: 0) {
            previewList
                .frame(width: 230)

            Divider()

            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(themeVM.activeAppTheme.workspaceBackgroundColor())
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(themeVM.activeAppTheme.workspaceTertiaryTextColor().opacity(0.18), lineWidth: 1)
                    )

                if let renderImage = viewModel.renderImage {
                    GeometryReader { geometry in
                        let canvasSize = scaledCanvasSize(
                            for: geometry.size,
                            preferredSize: renderImage.size
                        )
                        Image(nsImage: renderImage)
                            .resizable()
                            .interpolation(.high)
                            .frame(width: canvasSize.width, height: canvasSize.height)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .padding(18)
                } else if let failureMessage = visibleFailureMessage {
                    messageView(systemImage: "exclamationmark.triangle", message: failureMessage, color: .orange)
                } else if viewModel.previews.isEmpty {
                    messageView(systemImage: "bolt.slash", message: "No #Preview in the current Swift file", color: .secondary)
                } else {
                    messageView(systemImage: "photo", message: "Start hot preview to render a frame", color: .secondary)
                }
            }
            .overlay(alignment: .topLeading) {
                canvasStatus
                    .padding(12)
            }
            .padding(18)
        }
    }

    private var previewList: some View {
        VStack(alignment: .leading, spacing: 8) {
            if viewModel.previews.isEmpty {
                Text("No Preview")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(themeVM.activeAppTheme.workspaceSecondaryTextColor())
                    .padding(14)
            } else {
                ForEach(viewModel.previews) { preview in
                    Button {
                        viewModel.selectedPreviewID = preview.id
                    } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(preview.title)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(themeVM.activeAppTheme.workspaceTextColor())
                                .lineLimit(1)
                            Text("Line \(preview.lineNumber)-\(preview.endLineNumber)")
                                .font(.system(size: 11))
                                .foregroundColor(themeVM.activeAppTheme.workspaceSecondaryTextColor())
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(
                            preview.id == viewModel.selectedPreviewID
                                ? themeVM.activeAppTheme.workspaceTertiaryTextColor().opacity(0.16)
                                : Color.clear,
                            in: RoundedRectangle(cornerRadius: 6)
                        )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 8)
                .padding(.top, 8)
            }

            Spacer(minLength: 0)
        }
        .background(themeVM.activeAppTheme.workspaceTertiaryTextColor().opacity(0.04))
    }

    private var canvasStatus: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(viewModel.lastFrameSummary)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(themeVM.activeAppTheme.workspaceTextColor())

            if let performanceSummary = viewModel.performanceSummary {
                Text(performanceSummary)
                    .font(.system(size: 11))
                    .foregroundColor(themeVM.activeAppTheme.workspaceSecondaryTextColor())
            }

            Text("Live: \(viewModel.livePreviewInfo.state.rawValue)")
                .font(.system(size: 11))
                .foregroundColor(themeVM.activeAppTheme.workspaceSecondaryTextColor())

            Text("Transport: \(viewModel.transportSummary)")
                .font(.system(size: 11))
                .foregroundColor(themeVM.activeAppTheme.workspaceSecondaryTextColor())

            if let renderMessage = viewModel.renderMessage {
                Text(renderMessage)
                    .font(.system(size: 11))
                    .foregroundColor(themeVM.activeAppTheme.workspaceSecondaryTextColor())
            }

            if let liveReason = viewModel.livePreviewInfo.unavailableReason, !liveReason.isEmpty {
                Text(liveReason)
                    .font(.system(size: 11))
                    .foregroundColor(.orange)
                    .lineLimit(4)
            }

            if let diagnostics = viewModel.diagnostics, !diagnostics.isEmpty {
                Text(diagnostics)
                    .font(.system(size: 11))
                    .foregroundColor(.orange)
                    .lineLimit(6)
            }
        }
        .padding(10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
    }

    private var visibleFailureMessage: String? {
        if let failureMessage = viewModel.failureMessage {
            return failureMessage
        }
        return nil
    }

    private var statusColor: Color {
        switch viewModel.hostState {
        case .idle:
            return themeVM.activeAppTheme.workspaceSecondaryTextColor().opacity(0.7)
        case .launching, .rendering:
            return .orange
        case .connected:
            return .green
        case .failed:
            return .red
        }
    }

    private func refreshScanAndStartIfNeeded() {
        viewModel.update(sourceText: sourceText, fileURL: currentFileURL)
        if viewModel.hostState == .connected || viewModel.hostState == .launching {
            viewModel.startHost()
        }
    }

    private func refreshScanAndReloadIfNeeded() {
        viewModel.update(sourceText: sourceText, fileURL: currentFileURL)
        if viewModel.hostState == .connected || viewModel.hostState == .rendering {
            viewModel.scheduleRenderFrame(reason: "editor refresh signal changed")
        }
    }

    private func messageView(systemImage: String, message: String, color: Color) -> some View {
        VStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 22, weight: .light))
                .foregroundColor(color)
            Text(message)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(themeVM.activeAppTheme.workspaceSecondaryTextColor())
        }
    }

    private func scaledCanvasSize(for availableSize: CGSize, preferredSize: CGSize) -> CGSize {
        guard availableSize.width > 0, availableSize.height > 0 else {
            return .zero
        }

        let widthScale = availableSize.width / max(preferredSize.width, 1)
        let heightScale = availableSize.height / max(preferredSize.height, 1)
        let scale = min(widthScale, heightScale, 1)

        return CGSize(
            width: preferredSize.width * scale,
            height: preferredSize.height * scale
        )
    }
}
