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
        } else if let failureMessage = viewModel.failureMessage {
            HotPreviewErrorOverlayView(
                title: String(localized: "Preview Failed", table: "EditorPreview"),
                message: failureMessage,
                viewModel: viewModel
            )
        } else {
            liveCanvasSurface
        }
    }

    private var liveCanvasSurface: some View {
        GeometryReader { geometry in
            ZStack {
                HotPreviewBoardGrid()

                RoundedRectangle(cornerRadius: 0)
                    .stroke(themeVM.activeAppTheme.workspaceTertiaryTextColor().opacity(0.18), lineWidth: 1)

                if viewModel.effectiveDisplayMode == .image, let renderImage = viewModel.renderImage {
                    Image(nsImage: renderImage)
                        .resizable()
                        .interpolation(.high)
                        .overlay(
                            RoundedRectangle(cornerRadius: 0)
                                .stroke(themeVM.activeAppTheme.workspaceTertiaryTextColor().opacity(0.18), lineWidth: 1)
                        )
                }

                if let liveFailureMessage {
                    HotPreviewErrorOverlayView(
                        title: String(localized: "Live Preview Error", table: "EditorPreview"),
                        message: liveFailureMessage,
                        isOverlayingStaleFrame: viewModel.renderImage != nil,
                        viewModel: viewModel
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
