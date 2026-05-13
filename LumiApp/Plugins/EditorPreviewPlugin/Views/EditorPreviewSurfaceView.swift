import LumiPreviewKit
import SwiftUI

/// 编辑器预览渲染表面。
///
/// 核心展示区域，根据 displayMode 切换 Image / Live 渲染方式：
/// - Image 模式：显示预览渲染结果图片，附带状态图标和性能信息
/// - Live 模式：通过独立宿主进程实时渲染 SwiftUI 视图
/// 包含状态颜色、图标等视觉反馈
struct EditorPreviewSurfaceView: View {
    @EnvironmentObject private var themeVM: ThemeVM
    @ObservedObject var viewModel: EditorPreviewViewModel
    let preview: LumiPreviewPackage.PreviewDiscovery

    var body: some View {
        ZStack {
            if viewModel.displayMode == .live {
                liveCanvasSurface
            } else {
                imageCanvasSurface
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(themeVM.activeAppTheme.workspaceTertiaryTextColor().opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var imageCanvasSurface: some View {
        GeometryReader { geometry in
            VStack(spacing: 14) {
                Spacer(minLength: 0)

                if let renderImage = viewModel.renderImage {
                    imagePreview(renderImage, availableSize: geometry.size)
                } else {
                    Image(systemName: surfaceIconName)
                        .font(.system(size: 28, weight: .light))
                        .foregroundColor(statusColor)
                }

                surfaceInfo

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var liveCanvasSurface: some View {
        GeometryReader { geometry in
            let canvasSize = scaledCanvasSize(for: geometry.size)
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(themeVM.activeAppTheme.workspaceBackgroundColor())

                if viewModel.isLiveLoading {
                    VStack(spacing: 10) {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text(String(localized: "Starting Live Preview…", table: "EditorPreview"))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(themeVM.activeAppTheme.workspaceSecondaryTextColor())
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                if !viewModel.isLiveLoading {
                    VStack(spacing: 8) {
                        Image(systemName: viewModel.isShowingStaleLivePreview ? "clock.arrow.circlepath" : "play.rectangle.fill")
                            .font(.system(size: 20, weight: .light))
                            .foregroundColor((viewModel.isShowingStaleLivePreview ? Color.orange : Color.green).opacity(0.6))

                        Text(viewModel.staleLivePreviewMessage ?? String(localized: "Live Preview Active", table: "EditorPreview"))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(themeVM.activeAppTheme.workspaceSecondaryTextColor())

                        if viewModel.isShowingStaleLivePreview, let renderMessage = viewModel.renderMessage {
                            Text(renderMessage)
                                .font(.system(size: 11))
                                .foregroundColor(themeVM.activeAppTheme.workspaceTertiaryTextColor())
                                .lineLimit(2)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: 360)
                        }

                        if let performanceSummary = viewModel.performanceSummary {
                            Text(performanceSummary)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(themeVM.activeAppTheme.workspaceTertiaryTextColor())
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
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

    private func imagePreview(_ image: NSImage, availableSize: CGSize) -> some View {
        let canvasSize = scaledCanvasSize(for: availableSize)
        return Image(nsImage: image)
            .resizable()
            .interpolation(.high)
            .aspectRatio(contentMode: .fit)
            .frame(width: canvasSize.width, height: canvasSize.height)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(themeVM.activeAppTheme.workspaceTertiaryTextColor().opacity(0.18), lineWidth: 1)
            )
    }

    private func scaledCanvasSize(for availableSize: CGSize) -> CGSize {
        let availableCanvasSize = CGSize(
            width: max(availableSize.width - 48, 120),
            height: max(availableSize.height - 120, 120)
        )
        let baseSize = baseCanvasSize(for: availableCanvasSize)
        guard !viewModel.isCanvasScaleToFit else {
            return fittedSize(baseSize, inside: availableCanvasSize)
        }
        let scaledSize = CGSize(
            width: baseSize.width * viewModel.canvasScale,
            height: baseSize.height * viewModel.canvasScale
        )
        return fittedSize(scaledSize, inside: availableCanvasSize)
    }

    private func baseCanvasSize(for availableCanvasSize: CGSize) -> CGSize {
        if let fixedSize = viewModel.canvasSizePreset.fixedSize {
            return fixedSize
        }
        return CGSize(
            width: min(max(availableCanvasSize.width, 180), 420),
            height: min(max(availableCanvasSize.height, 120), 260)
        )
    }

    private func fittedSize(_ size: CGSize, inside availableSize: CGSize) -> CGSize {
        guard size.width > 0, size.height > 0 else { return size }
        let scale = min(availableSize.width / size.width, availableSize.height / size.height, 1)
        return CGSize(width: size.width * scale, height: size.height * scale)
    }

    private var surfaceInfo: some View {
        VStack(spacing: 5) {
            Text(surfaceTitle)
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

    private var surfaceTitle: String {
        switch viewModel.runState {
        case .running:
            if viewModel.displayMode == .live {
                return String(format: String(localized: "Live preview of %@", table: "EditorPreview"), preview.title)
            }
            return String(format: String(localized: "Preview host rendered %@", table: "EditorPreview"), preview.title)
        case .starting:
            return String(localized: "Building preview", table: "EditorPreview")
        case .stopped:
            return String(localized: "Preview stopped", table: "EditorPreview")
        case .idle:
            return String(localized: "Ready to start preview", table: "EditorPreview")
        case .failed:
            return String(localized: "Preview failed", table: "EditorPreview")
        case .hostMissing:
            return String(localized: "Preview host missing", table: "EditorPreview")
        }
    }
}
