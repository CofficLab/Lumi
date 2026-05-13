import AppKit
import LumiPreviewKit
import SwiftUI

struct EditorPreviewRemoteDetailView: View {
    @EnvironmentObject private var editorVM: EditorVM
    @EnvironmentObject private var themeVM: ThemeVM
    @StateObject private var viewModel = EditorPreviewRemoteViewModel()

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
        .onDisappear {
            viewModel.viewDidDisappear()
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
            Image(systemName: "rectangle.inset.filled")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(themeVM.activeAppTheme.workspaceSecondaryTextColor())

            Text(String(localized: "Remote Preview", table: EditorPreviewRemoteConstants.localizationTable))
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
            .help(String(localized: "Start preview host", table: EditorPreviewRemoteConstants.localizationTable))

            Button {
                viewModel.renderFrame()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 11, weight: .medium))
            }
            .buttonStyle(.plain)
            .disabled(viewModel.hostState == .idle)
            .help(String(localized: "Render frame", table: EditorPreviewRemoteConstants.localizationTable))

            Button {
                viewModel.stopHost()
            } label: {
                Image(systemName: "stop.fill")
                    .font(.system(size: 11, weight: .medium))
            }
            .buttonStyle(.plain)
            .disabled(!viewModel.canStop)
            .help(String(localized: "Stop preview host", table: EditorPreviewRemoteConstants.localizationTable))
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
                liveCanvasSurface

                if let diagnostics = visibleDiagnostics {
                    errorView(diagnostics)
                        .padding(28)
                } else if viewModel.previews.isEmpty {
                    emptyState
                }
            }
            .overlay(alignment: .topLeading) {
                canvasStatus
                    .padding(12)
            }
        }
    }

    private var previewList: some View {
        VStack(alignment: .leading, spacing: 8) {
            if viewModel.previews.isEmpty {
                Text(String(localized: "No Preview", table: EditorPreviewRemoteConstants.localizationTable))
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
                            Text(
                                String(
                                    format: String(localized: "Line %lld-%lld", table: EditorPreviewRemoteConstants.localizationTable),
                                    Int64(preview.lineNumber),
                                    Int64(preview.endLineNumber)
                                )
                            )
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

    private var liveCanvasSurface: some View {
        GeometryReader { geometry in
            let canvasSize = scaledCanvasSize(
                for: geometry.size,
                preferredSize: viewModel.lastFrameSize ?? CGSize(width: 900, height: 560)
            )

            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(themeVM.activeAppTheme.workspaceBackgroundColor())
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(themeVM.activeAppTheme.workspaceTertiaryTextColor().opacity(0.18), lineWidth: 1)
                    )

                if let surfaceFrame = viewModel.renderSurfaceFrame {
                    surfacePreview(surfaceFrame, availableSize: geometry.size)
                } else if let renderImage = viewModel.renderImage {
                    imagePreview(renderImage, availableSize: geometry.size)
                } else if viewModel.isLiveLoading {
                    loadingState(String(localized: "Starting Live Preview", table: EditorPreviewRemoteConstants.localizationTable))
                } else if let staleMessage = viewModel.staleLivePreviewMessage {
                    VStack(spacing: 8) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 20, weight: .light))
                            .foregroundColor(.orange)
                        Text(staleMessage)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(themeVM.activeAppTheme.workspaceSecondaryTextColor())
                    }
                } else if viewModel.hostState == .connected {
                    VStack(spacing: 8) {
                        Image(systemName: "play.rectangle.fill")
                            .font(.system(size: 20, weight: .light))
                            .foregroundColor(.green.opacity(0.7))
                        Text(String(localized: "Live Preview Active", table: EditorPreviewRemoteConstants.localizationTable))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(themeVM.activeAppTheme.workspaceSecondaryTextColor())
                    }
                    .opacity(0.65)
                }
            }
            .frame(width: canvasSize.width, height: canvasSize.height)
            .background(
                EditorPreviewLiveCanvasFrameReporter { screenFrame, scale in
                    viewModel.updateLiveCanvasRect(screenFrame, scale: scale)
                } onFrameUnavailable: {
                    viewModel.liveCanvasFrameUnavailable()
                }
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onAppear {
                viewModel.liveCanvasDidAppear()
            }
            .onDisappear {
                viewModel.liveCanvasDidDisappear()
            }
            .onChange(of: geometry.size) { _, _ in
                EditorPreviewLiveCanvasFrameReporter.scheduleFrameUpdate()
            }
        }
        .background(themeVM.activeAppTheme.workspaceTertiaryTextColor().opacity(0.05))
    }

    private var canvasStatus: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(String(localized: "Live", table: EditorPreviewRemoteConstants.localizationTable))
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(themeVM.activeAppTheme.workspaceTextColor())
            Text(viewModel.failureMessage ?? viewModel.lastFrameSummary)
                .font(.system(size: 11))
                .foregroundColor(themeVM.activeAppTheme.workspaceSecondaryTextColor())
                .lineLimit(2)
            if let performanceSummary = viewModel.performanceSummary {
                Text(performanceSummary)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(themeVM.activeAppTheme.workspaceTertiaryTextColor())
            }
            Text(viewModel.diagnosticSummary)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(themeVM.activeAppTheme.workspaceTertiaryTextColor())
                .lineLimit(2)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .background(
            themeVM.activeAppTheme.workspaceBackgroundColor().opacity(0.92),
            in: RoundedRectangle(cornerRadius: 6)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(themeVM.activeAppTheme.workspaceTertiaryTextColor().opacity(0.18), lineWidth: 1)
        )
    }

    private var statusColor: Color {
        switch viewModel.hostState {
        case .idle:
            themeVM.activeAppTheme.workspaceSecondaryTextColor()
        case .launching, .rendering:
            .orange
        case .connected:
            .green
        case .failed:
            .red
        }
    }

    private var visibleDiagnostics: String? {
        guard viewModel.renderImage == nil && viewModel.renderSurfaceFrame == nil else { return nil }
        return viewModel.diagnostics ?? viewModel.renderMessage
    }

    private func imagePreview(_ image: NSImage, availableSize: CGSize) -> some View {
        let canvasSize = scaledCanvasSize(for: availableSize, preferredSize: image.size)
        return Image(nsImage: image)
            .resizable()
            .interpolation(.high)
            .aspectRatio(contentMode: .fit)
            .frame(width: canvasSize.width, height: canvasSize.height)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(themeVM.activeAppTheme.workspaceTertiaryTextColor().opacity(0.18), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.08), radius: 18, y: 4)
    }

    private func surfacePreview(
        _ surfaceFrame: LumiPreviewPackage.PreviewSurfaceFrame,
        availableSize: CGSize
    ) -> some View {
        let preferredSize = CGSize(
            width: Double(surfaceFrame.width) / max(surfaceFrame.scale, 1),
            height: Double(surfaceFrame.height) / max(surfaceFrame.scale, 1)
        )
        let canvasSize = scaledCanvasSize(for: availableSize, preferredSize: preferredSize)
        return EditorPreviewRemoteSurfaceView(surfaceFrame: surfaceFrame)
            .frame(width: canvasSize.width, height: canvasSize.height)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(themeVM.activeAppTheme.workspaceTertiaryTextColor().opacity(0.18), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.08), radius: 18, y: 4)
    }

    private func loadingState(_ title: String) -> some View {
        VStack(spacing: 10) {
            ProgressView()
                .scaleEffect(0.8)
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(themeVM.activeAppTheme.workspaceSecondaryTextColor())
        }
    }

    private func errorView(_ message: String) -> some View {
        ScrollView {
            Text(message)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.red)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(themeVM.activeAppTheme.workspaceBackgroundColor().opacity(0.96))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "rectangle.dashed")
                .font(.system(size: 24, weight: .light))
                .foregroundColor(themeVM.activeAppTheme.workspaceSecondaryTextColor())
            Text(String(localized: "No #Preview in the current Swift file", table: EditorPreviewRemoteConstants.localizationTable))
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(themeVM.activeAppTheme.workspaceSecondaryTextColor())
        }
    }

    private func scaledCanvasSize(for availableSize: CGSize, preferredSize: CGSize) -> CGSize {
        let availableCanvasSize = CGSize(
            width: max(availableSize.width - 84, 120),
            height: max(availableSize.height - 84, 120)
        )
        guard preferredSize.width > 0, preferredSize.height > 0 else {
            return availableCanvasSize
        }

        let scale = min(
            availableCanvasSize.width / preferredSize.width,
            availableCanvasSize.height / preferredSize.height,
            1
        )
        return CGSize(width: preferredSize.width * scale, height: preferredSize.height * scale)
    }

    private func refreshScanAndStartIfNeeded() {
        viewModel.update(sourceText: sourceText, fileURL: currentFileURL)
        if viewModel.canStart {
            viewModel.startHost()
        }
    }

    private func refreshScanAndReloadIfNeeded() {
        viewModel.update(sourceText: sourceText, fileURL: currentFileURL)
        if viewModel.hostState == .connected {
            viewModel.scheduleRenderFrame(reason: "editor content changed")
        } else if viewModel.canStart {
            viewModel.startHost()
        }
    }
}

private extension EditorPreviewRemoteViewModel {
    var lastFrameSize: CGSize? {
        service.lastFrame?.size
    }
}
