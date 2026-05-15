import LumiPreviewKit
import SwiftUI

struct HotPreviewCanvas: View {
    @EnvironmentObject private var themeVM: ThemeVM
    @ObservedObject var viewModel: EditorRemoteHotPreviewViewModel

    var body: some View {
        canvasContent
            .frame(maxHeight: .infinity)
    }

    @ViewBuilder
    private var canvasContent: some View {
        if viewModel.previews.isEmpty {
            HotPreviewMessageView(
                systemImage: "bolt.slash",
                message: String(localized: "No #Preview in the current Swift file", table: "EditorPreview"),
                color: .secondary
            )
        } else if viewModel.hostState == .idle && viewModel.renderImage == nil && viewModel.failureMessage == nil {
            HotPreviewMessageView(
                systemImage: "play.rectangle",
                message: String(localized: "Start hot preview to render a frame", table: "EditorPreview"),
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
        }
    }

    private var liveCanvasSurface: some View {
        GeometryReader { geometry in
            let shouldShowFallbackImage = viewModel.effectiveDisplayMode == .image && viewModel.renderImage != nil

            ZStack {
                HotPreviewBoardGrid()

                RoundedRectangle(cornerRadius: 0)
                    .stroke(themeVM.activeAppTheme.workspaceTertiaryTextColor().opacity(0.18), lineWidth: 1)

                if let liveFailureMessage {
                    HotPreviewMessageView(
                        systemImage: "exclamationmark.triangle",
                        message: liveFailureMessage,
                        color: .orange
                    )
                } else if shouldShowFallbackImage, let renderImage = viewModel.renderImage {
                    Image(nsImage: renderImage)
                        .resizable()
                        .interpolation(.high)
                        .overlay(
                            RoundedRectangle(cornerRadius: 0)
                                .stroke(themeVM.activeAppTheme.workspaceTertiaryTextColor().opacity(0.18), lineWidth: 1)
                        )
                } else if let failureMessage = viewModel.failureMessage, viewModel.effectiveDisplayMode == .image {
                    HotPreviewMessageView(
                        systemImage: "exclamationmark.triangle",
                        message: failureMessage,
                        color: .orange
                    )
                } else if viewModel.isLiveLoading {
                    HotPreviewMessageView(
                        systemImage: "bolt.fill",
                        message: String(localized: "Starting hot live preview", table: "EditorPreview"),
                        color: .orange
                    )
                } else if viewModel.effectiveDisplayMode == .live {
                    EmptyView()
                } else if viewModel.renderImage == nil {
                    // Refreshing or waiting for the first frame — show only the
                    // grid background without any placeholder text.
                    EmptyView()
                }
            }
            .background(
                EditorPreviewLiveCanvasFrameReporter { screenFrame, scale in
                    viewModel.updateLiveCanvasRect(screenFrame, scale: scale)
                } onFrameUnavailable: {
                    viewModel.liveCanvasFrameUnavailable()
                }
            )
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

    private var liveFailureMessage: String? {
        guard viewModel.preferredDisplayMode == .live,
              viewModel.livePreviewInfo.state == .failed else {
            return nil
        }

        return viewModel.livePreviewInfo.unavailableReason
            ?? String(localized: "Live preview failed", table: "EditorPreview")
    }
}

private struct HotPreviewBoardGrid: View {
    private let spacing: CGFloat = 24

    var body: some View {
        Canvas { context, size in
            drawGrid(
                context: &context,
                size: size,
                spacing: spacing,
                color: NSColor.separatorColor.withAlphaComponent(0.04),
                lineWidth: 1
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: 0))
        .allowsHitTesting(false)
    }

    private func drawGrid(
        context: inout GraphicsContext,
        size: CGSize,
        spacing: CGFloat,
        color: NSColor,
        lineWidth: CGFloat
    ) {
        guard spacing > 0 else { return }

        var path = Path()
        var x: CGFloat = 0
        while x <= size.width {
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: size.height))
            x += spacing
        }

        var y: CGFloat = 0
        while y <= size.height {
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: size.width, y: y))
            y += spacing
        }

        context.stroke(path, with: .color(Color(nsColor: color)), lineWidth: lineWidth)
    }
}
