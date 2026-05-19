import LumiUI
import SwiftUI
import MagicKit
import os

/// 图片显示插件的 RootView 覆盖层
///
/// 职责：监听 `ShowImageState` 的变化，在图片被触发时显示图片预览面板。
/// 此 overlay 不依赖 `RootViewContainer.shared`，通过 SwiftUI 环境变量获取必要依赖。
@MainActor
struct ShowImageOverlay<Content: View>: View, SuperLog {
    nonisolated static var emoji: String { "🖼️" }
    nonisolated static var verbose: Bool { ShowImagePlugin.verbose }
    nonisolated static var logger: Logger {
        ShowImagePlugin.logger
    }

    let content: Content

    @StateObject private var state = ShowImageState.shared

    var body: some View {
        content
            .overlay {
                if let item = state.displayItem {
                    ShowImagePreviewPanel(
                        displayItem: item,
                        onDismiss: {
                            state.clear()
                        }
                    )
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(1000)
                }
            }
    }
}

// MARK: - Preview Panel

/// 图片预览面板
///
/// 以 overlay 形式显示在应用顶部，可关闭。
struct ShowImagePreviewPanel: View {
    let displayItem: ShowImageState.DisplayItem
    let onDismiss: () -> Void

    @State private var loadedImage: NSImage?
    @State private var isLoading: Bool = false
    @State private var errorText: String?
    @State private var isPresentingFullscreen: Bool = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 0) {
                // 标题
                if let title = displayItem.title {
                    HStack {
                        Text(title)
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(Color.adaptive(light: "1C1C1E", dark: "FFFFFF"))
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                }

                // 图片区域
                ZStack {
                    if isLoading {
                        VStack(spacing: 12) {
                            ProgressView()
                                .controlSize(.regular)
                            Text(String(localized: "加载中…", table: "ShowImage"))
                                .font(.system(size: 12, weight: .regular))
                                .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
                        }
                        .frame(height: 200)
                    } else if let image = loadedImage {
                        Button {
                            isPresentingFullscreen = true
                        } label: {
                            Image(nsImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxWidth: CGFloat(displayItem.maxWidth))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                        .help(String(localized: "点击放大预览", table: "ShowImage"))
                    } else if let errorText {
                        VStack(spacing: 8) {
                            Image(systemName: "photo.badge.exclamationmark")
                                .font(.system(size: 32))
                                .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
                            Text(errorText)
                                .font(.system(size: 12, weight: .regular))
                                .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
                                .multilineTextAlignment(.center)
                        }
                        .frame(height: 150)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                // 说明文字
                if let caption = displayItem.caption {
                    Text(caption)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
                        .padding(.horizontal, 16)
                        .padding(.bottom, 12)
                }
            }
            .background(
                Color(hex: "0D0D12")
                    .shadow(color: .black.opacity(0.15), radius: 12, y: 4)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
            )
            .padding(16)

            // 关闭按钮
            AppIconButton(
                systemImage: "xmark",
                tint: Color.adaptive(light: "6B6B7B", dark: "EBEBF5"),
                size: .regular
            ) {
                onDismiss()
            }
            .padding(20)
        }
        .frame(maxWidth: 500, alignment: .topTrailing)
        .animation(.spring(response: 0.3), value: displayItem)
        .task {
            await loadImage()
        }
        .sheet(isPresented: $isPresentingFullscreen) {
            if let image = loadedImage {
                ShowImageFullscreenSheet(image: image)
            }
        }
    }

    // MARK: - Image Loading

    private func loadImage() async {
        isLoading = true
        errorText = nil
        loadedImage = nil

        do {
            switch displayItem.source {
            case .local(let path):
                let fileURL = URL(fileURLWithPath: path)
                guard let data = try? Data(contentsOf: fileURL),
                      let image = NSImage(data: data) else {
                    errorText = "无法加载图片：\(path.components(separatedBy: "/").last ?? path)"
                    isLoading = false
                    return
                }
                loadedImage = image

            case .remote(let urlString):
                guard let url = URL(string: urlString) else {
                    errorText = "无效的 URL: \(urlString)"
                    isLoading = false
                    return
                }
                let (data, _) = try await URLSession.shared.data(from: url)
                guard let image = NSImage(data: data) else {
                    errorText = "无法解析图片数据"
                    isLoading = false
                    return
                }
                loadedImage = image
            }
        } catch {
            errorText = "加载失败：\(error.localizedDescription)"
        }

        isLoading = false
    }
}

// MARK: - Fullscreen Sheet

/// 全屏查看图片
struct ShowImageFullscreenSheet: View {
    let image: NSImage
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button(String(localized: "关闭", table: "ShowImage")) { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            GeometryReader { geometry in
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: geometry.size.width, maxHeight: geometry.size.height)
                    .padding(20)
            }
        }
        .frame(minWidth: 640, minHeight: 480)
    }
}
