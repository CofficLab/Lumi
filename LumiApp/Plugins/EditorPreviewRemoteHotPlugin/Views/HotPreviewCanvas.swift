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
        .padding(18)
    }

    @ViewBuilder
    private var canvasContent: some View {
        if viewModel.previews.isEmpty {
            HotPreviewMessageView(
                systemImage: "bolt.slash",
                message: String(localized: "No #Preview in the current Swift file", table: "EditorPreviewRemoteHotPlugin"),
                color: .secondary
            )
        } else if viewModel.hostState == .idle && viewModel.renderImage == nil && viewModel.failureMessage == nil {
            HotPreviewMessageView(
                systemImage: "play.rectangle",
                message: String(localized: "Start hot preview to render a frame", table: "EditorPreviewRemoteHotPlugin"),
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
                        message: String(localized: "Starting hot live preview", table: "EditorPreviewRemoteHotPlugin"),
                        color: .orange
                    )
                } else {
                    HotPreviewMessageView(
                        systemImage: "play.rectangle.fill",
                        message: String(localized: "Hot live preview active", table: "EditorPreviewRemoteHotPlugin"),
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
