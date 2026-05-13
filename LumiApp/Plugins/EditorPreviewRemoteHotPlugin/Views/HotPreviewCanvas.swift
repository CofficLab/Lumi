import LumiPreviewKit
import SwiftUI

struct HotPreviewCanvas: View {
    @EnvironmentObject private var themeVM: ThemeVM
    @ObservedObject var viewModel: EditorRemoteHotPreviewViewModel

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(themeVM.activeAppTheme.workspaceBackgroundColor())
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(themeVM.activeAppTheme.workspaceTertiaryTextColor().opacity(0.18), lineWidth: 1)
                )

            canvasContent
        }
        .overlay(alignment: .topLeading) {
            canvasStatus
                .padding(12)
        }
        .padding(18)
    }

    @ViewBuilder
    private var canvasContent: some View {
        if viewModel.previews.isEmpty {
            HotPreviewMessageView(
                systemImage: "bolt.slash",
                message: "No #Preview in the current Swift file",
                color: .secondary
            )
        } else if viewModel.hostState == .idle && viewModel.renderImage == nil && viewModel.failureMessage == nil {
            HotPreviewMessageView(
                systemImage: "play.rectangle",
                message: "Start hot preview to render a frame",
                color: .secondary
            )
        } else if let failureMessage = viewModel.failureMessage, viewModel.renderImage == nil {
            HotPreviewMessageView(
                systemImage: "exclamationmark.triangle",
                message: failureMessage,
                color: .orange
            )
        } else {
            liveCanvasSurface
                .padding(18)
        }
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

            Text("Active: \(viewModel.effectiveDisplayMode.rawValue)")
                .font(.system(size: 11))
                .foregroundColor(themeVM.activeAppTheme.workspaceSecondaryTextColor())

            Text("Transport: \(viewModel.transportSummary)")
                .font(.system(size: 11))
                .foregroundColor(themeVM.activeAppTheme.workspaceSecondaryTextColor())

            if let modeStatusMessage = viewModel.modeStatusMessage {
                Text(modeStatusMessage)
                    .font(.system(size: 11))
                    .foregroundColor(.orange)
                    .lineLimit(4)
            }

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

            Text(viewModel.diagnosticSummary)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(themeVM.activeAppTheme.workspaceSecondaryTextColor())
                .lineLimit(3)
        }
        .padding(10)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
    }

    private var liveCanvasSurface: some View {
        GeometryReader { geometry in
            let preferredSize = viewModel.renderImage?.size ?? CGSize(width: 900, height: 560)
            let canvasSize = Self.scaledCanvasSize(for: geometry.size, preferredSize: preferredSize)

            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(themeVM.activeAppTheme.workspaceBackgroundColor())

                if let renderImage = viewModel.renderImage {
                    Image(nsImage: renderImage)
                        .resizable()
                        .interpolation(.high)
                        .frame(width: canvasSize.width, height: canvasSize.height)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(themeVM.activeAppTheme.workspaceTertiaryTextColor().opacity(0.18), lineWidth: 1)
                        )
                } else if let failureMessage = viewModel.failureMessage {
                    HotPreviewMessageView(
                        systemImage: "exclamationmark.triangle",
                        message: failureMessage,
                        color: .orange
                    )
                } else if viewModel.isLiveLoading {
                    HotPreviewMessageView(
                        systemImage: "bolt.fill",
                        message: "Starting hot live preview",
                        color: .orange
                    )
                } else {
                    HotPreviewMessageView(
                        systemImage: "play.rectangle.fill",
                        message: "Hot live preview active",
                        color: .green
                    )
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
    }

    private static func scaledCanvasSize(for availableSize: CGSize, preferredSize: CGSize) -> CGSize {
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
