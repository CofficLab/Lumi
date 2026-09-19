import AppKit
import LumiUI
import SwiftUI

/// 截图大图预览 modal，双击缩略图后弹出。
///
/// 支持放大缩小按钮、拖动查看、Esc 关闭。
struct ScreenshotPreviewModal: View {
    let url: URL
    let screenshotID: String

    @Environment(\.dismiss) private var dismiss
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero

    private let minScale: CGFloat = 0.2
    private let maxScale: CGFloat = 5.0

    var body: some View {
        ZStack {
            Color.black.opacity(0.85)
                .ignoresSafeArea()
                .onTapGesture { dismiss() }

            previewImage
                .scaleEffect(scale)
                .offset(offset)
                .gesture(dragGesture)
                .gesture(magnificationGesture)

            topBar
        }
        .frame(minWidth: 600, minHeight: 400)
        .onExitCommand { dismiss() }
    }

    // MARK: - Preview Image

    private var previewImage: some View {
        CachedScreenshotThumbnail(
            url: url,
            screenshotID: screenshotID,
            contentMode: .fit
        ) {
            ProgressView()
                .controlSize(.large)
                .tint(.white)
        } failure: {
            Image(systemName: "photo")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        VStack {
            HStack {
                Spacer()

                HStack(spacing: 12) {
                    zoomButton(.minus, action: zoomOut)
                    Text("\(Int(scale * 100))%")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.white.opacity(0.8))
                        .frame(minWidth: 44)
                    zoomButton(.plus, action: zoomIn)
                    zoomButton("arrow.clockwise", action: resetZoom)

                    Divider()
                        .frame(height: 16)
                        .overlay(Color.white.opacity(0.3))

                    zoomButton("xmark", action: { dismiss() })
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial, in: Capsule())
            }
            .padding(16)

            Spacer()
        }
    }

    private func zoomButton(_ systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func zoomButton(_ symbol: ZoomSymbol, action: @escaping () -> Void) -> some View {
        zoomButton(symbol.rawValue, action: action)
    }

    // MARK: - Zoom

    private func zoomIn() {
        withAnimation(.easeInOut(duration: 0.15)) {
            scale = min(maxScale, scale + 0.25)
        }
    }

    private func zoomOut() {
        withAnimation(.easeInOut(duration: 0.15)) {
            scale = max(minScale, scale - 0.25)
            if scale <= 1.0 { offset = .zero }
        }
    }

    private func resetZoom() {
        withAnimation(.easeInOut(duration: 0.2)) {
            scale = 1.0
            offset = .zero
        }
    }

    // MARK: - Gestures

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                offset = value.translation
            }
    }

    private var magnificationGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                scale = min(maxScale, max(minScale, lastScale * value.magnification))
            }
            .onEnded { _ in
                lastScale = scale
            }
    }

    private enum ZoomSymbol: String {
        case plus = "plus"
        case minus = "minus"
    }
}
