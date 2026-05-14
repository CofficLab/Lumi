import SwiftUI

/// 图片文件预览视图。
///
/// 支持常见格式：PNG, JPEG, GIF, TIFF, BMP, WebP, SVG, ICNS, ICO。
/// 使用 macOS 原生 `NSImage(contentsOf:)` 加载，
/// 支持透明背景棋盘格、自适应缩放、以及显示图片元信息。
struct EditorPreviewImageView: View {
    @EnvironmentObject private var themeVM: ThemeVM

    /// 图片文件的 URL
    let fileURL: URL

    @State private var image: NSImage?
    @State private var loadError: String?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(themeVM.activeAppTheme.workspaceBackgroundColor())

            if let image {
                imageContent(image)
            } else if let loadError {
                errorView(loadError)
            } else {
                loadingView
            }
        }
        .padding(18)
        .task(id: fileURL) {
            loadImage()
        }
    }

    @ViewBuilder
    private func imageContent(_ image: NSImage) -> some View {
        GeometryReader { geometry in
            let canvasSize = fittedSize(
                original: image.size,
                container: CGSize(
                    width: geometry.size.width - 36,
                    height: geometry.size.height - 36
                )
            )

            VStack(spacing: 16) {
                Spacer(minLength: 0)

                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: canvasSize.width, height: canvasSize.height)
                    .background(
                        checkerboardBackground
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(themeVM.activeAppTheme.workspaceTertiaryTextColor().opacity(0.18), lineWidth: 1)
                    )

                imageInfo(image)

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func imageInfo(_ image: NSImage) -> some View {
        HStack(spacing: 16) {
            Label(
                String(format: String(localized: "%g × %g pt", table: "EditorPreview"), image.size.width, image.size.height),
                systemImage: "arrow.up.left.and.arrow.down.right"
            )

            if let fileSize = fileSizeString {
                Label(fileSize, systemImage: "doc")
            }
        }
        .font(.system(size: 11))
        .foregroundColor(themeVM.activeAppTheme.workspaceSecondaryTextColor())
    }

    private var loadingView: some View {
        VStack(spacing: 10) {
            ProgressView()
                .scaleEffect(0.8)
            Text(String(localized: "Loading image…", table: "EditorPreview"))
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(themeVM.activeAppTheme.workspaceSecondaryTextColor())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 22, weight: .light))
                .foregroundColor(.orange)
            Text(message)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(themeVM.activeAppTheme.workspaceSecondaryTextColor())
                .multilineTextAlignment(.center)
                .lineLimit(3)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(24)
    }

    private var checkerboardBackground: some View {
        GeometryReader { geometry in
            let tileSize: CGFloat = 12
            let cols = Int(ceil(geometry.size.width / tileSize))
            let rows = Int(ceil(geometry.size.height / tileSize))

            ZStack {
                themeVM.activeAppTheme.workspaceBackgroundColor()

                ForEach(0..<rows, id: \.self) { row in
                    ForEach(0..<cols, id: \.self) { col in
                        if (row + col) % 2 == 0 {
                            RoundedRectangle(cornerRadius: 1)
                                .fill(themeVM.activeAppTheme.workspaceTertiaryTextColor().opacity(0.06))
                                .frame(width: tileSize, height: tileSize)
                                .position(
                                    x: CGFloat(col) * tileSize + tileSize / 2,
                                    y: CGFloat(row) * tileSize + tileSize / 2
                                )
                        }
                    }
                }
            }
        }
    }

    private func loadImage() {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: fileURL.path) else {
            loadError = String(
                format: String(localized: "File not found: %@", table: "EditorPreview"),
                fileURL.lastPathComponent
            )
            return
        }

        guard let loadedImage = NSImage(contentsOf: fileURL) else {
            loadError = String(
                format: String(localized: "Failed to load image: %@", table: "EditorPreview"),
                fileURL.lastPathComponent
            )
            return
        }

        image = loadedImage
        loadError = nil
    }

    private var fileSizeString: String? {
        let fileManager = FileManager.default
        guard let attributes = try? fileManager.attributesOfItem(atPath: fileURL.path),
              let fileSize = attributes[.size] as? UInt64 else {
            return nil
        }
        return ByteCountFormatter.string(fromByteCount: Int64(fileSize), countStyle: .file)
    }

    private func fittedSize(original: CGSize, container: CGSize) -> CGSize {
        guard original.width > 0, original.height > 0,
              container.width > 0, container.height > 0 else {
            return .zero
        }
        let scale = min(container.width / original.width, container.height / original.height, 1)
        return CGSize(width: original.width * scale, height: original.height * scale)
    }
}
