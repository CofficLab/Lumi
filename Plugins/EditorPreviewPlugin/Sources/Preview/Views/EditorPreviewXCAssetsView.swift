import Foundation
import HTMLPreviewKit
import LumiKernel
import LumiUI
import os
import SuperLogKit
import SwiftUI

/// xcassets 资源目录预览视图。
///
/// 解析 `.xcassets` 目录结构，展示颜色集和图片集的可视化预览。
public struct EditorPreviewXCAssetsView: View, SuperLog {
    public nonisolated static let logger = Logger(
        subsystem: "com.coffic.lumi",
        category: "plugin.editor-inline-preview.xcassets-view"
    )
    public nonisolated static let emoji = "🎨"
    public nonisolated static let verbose: Bool = true

    @EnvironmentObject private var themeVM: AppThemeVM

    let xcassetsURL: URL

    @State private var content: XCAssetsParser.XCAssetsContent?
    @State private var loadError: String?

    public var body: some View {
        ZStack {
            PreviewBoardGrid()

            if let content {
                if content.isEmpty {
                    emptyView
                } else {
                    contentView(content)
                }
            } else if let loadError {
                errorView(loadError)
            } else {
                ProgressView()
            }
        }
        .task(id: xcassetsURL) {
            loadContent()
        }
    }

    // MARK: - Content View

    private func contentView(_ content: XCAssetsParser.XCAssetsContent) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if !content.colors.isEmpty {
                    sectionHeader(LumiPluginLocalization.string("Colors", bundle: .module), systemImage: "paintpalette", count: content.colors.count)
                    colorGrid(content.colors)
                }

                if !content.images.isEmpty {
                    sectionHeader(LumiPluginLocalization.string("Images & Icons", bundle: .module), systemImage: "photo.on.rectangle", count: content.images.count)
                    imageGrid(content.images)
                }
            }
            .padding(20)
        }
    }

    // MARK: - Color Section

    private func sectionHeader(_ title: String, systemImage: String, count: Int) -> some View {
        Label {
            HStack(spacing: 6) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text("(\(count))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } icon: {
            Image(systemName: systemImage)
        }
        .padding(.bottom, 4)
    }

    private func colorGrid(_ colors: [XCAssetsParser.ColorSet]) -> some View {
        LazyVGrid(columns: [
            GridItem(.adaptive(minimum: 80, maximum: 120), spacing: 12)
        ], spacing: 12) {
            ForEach(colors) { colorSet in
                colorSwatchCard(colorSet)
            }
        }
    }

    private func colorSwatchCard(_ colorSet: XCAssetsParser.ColorSet) -> some View {
        VStack(spacing: 6) {
            // 色块区域：左侧 light，右侧 dark（如有）
            ZStack {
                // Light mode 色块
                Rectangle()
                    .fill(Color(
                        red: colorSet.lightColor.red,
                        green: colorSet.lightColor.green,
                        blue: colorSet.lightColor.blue,
                        opacity: colorSet.lightColor.alpha
                    ))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(.secondary.opacity(0.2), lineWidth: 1)
                    )

                // Dark mode 色块（右上角）
                if let darkColor = colorSet.darkColor {
                    HStack {
                        Spacer()
                        VStack {
                            Rectangle()
                                .fill(Color(
                                    red: darkColor.red,
                                    green: darkColor.green,
                                    blue: darkColor.blue,
                                    opacity: darkColor.alpha
                                ))
                                .frame(width: 24, height: 24)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4)
                                        .stroke(.secondary.opacity(0.3), lineWidth: 0.5)
                                )
                                .padding(4)
                            Spacer()
                        }
                    }
                }
            }
            .aspectRatio(1, contentMode: .fit)
            .frame(minHeight: 60)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            Text(colorSet.displayName)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(maxWidth: .infinity)
        }
        .help(colorHelpText(colorSet))
    }

    private func colorHelpText(_ colorSet: XCAssetsParser.ColorSet) -> String {
        var text = "\(colorSet.displayName)\n"
        text += "Light: #\(hexString(colorSet.lightColor))\n"
        if let darkColor = colorSet.darkColor {
            text += "Dark: #\(hexString(darkColor))"
        }
        return text
    }

    private func hexString(_ color: XCAssetsParser.RGBAColor) -> String {
        String(
            format: "%02lX%02lX%02lX",
            lround(color.red * 255),
            lround(color.green * 255),
            lround(color.blue * 255)
        )
    }

    // MARK: - Image Section

    private func imageGrid(_ images: [XCAssetsParser.ImageSet]) -> some View {
        LazyVGrid(columns: [
            GridItem(.adaptive(minimum: 80, maximum: 120), spacing: 12)
        ], spacing: 12) {
            ForEach(images) { imageSet in
                imageCard(imageSet)
            }
        }
    }

    private func imageCard(_ imageSet: XCAssetsParser.ImageSet) -> some View {
        VStack(spacing: 6) {
            if let previewFile = imageSet.previewImageFile {
                AsyncImage(url: previewFile.fileURL) { phase in
                    switch phase {
                    case let .success(image):
                        image
                            .resizable()
                            .interpolation(.high)
                            .scaledToFit()
                            .frame(maxWidth: 64, maxHeight: 64)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    case .failure:
                        placeholderIcon(imageSet.type)
                    case .empty:
                        ProgressView()
                            .controlSize(.small)
                    @unknown default:
                        placeholderIcon(imageSet.type)
                    }
                }
                .aspectRatio(1, contentMode: .fit)
                .frame(minHeight: 60)
                .background(checkerboardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                placeholderIcon(imageSet.type)
                    .aspectRatio(1, contentMode: .fit)
                    .frame(minHeight: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            Text(imageSet.displayName)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(maxWidth: .infinity)
        }
        .help(imageHelpText(imageSet))
    }

    private func placeholderIcon(_ type: XCAssetsParser.ImageSetType) -> some View {
        Image(systemName: type == .appIcon ? "app.fill" : "photo")
            .font(.system(size: 28))
            .foregroundStyle(.secondary)
    }

    private func imageHelpText(_ imageSet: XCAssetsParser.ImageSet) -> String {
        let typeName = imageSet.type == .appIcon
            ? LumiPluginLocalization.string("App Icon", bundle: .module)
            : LumiPluginLocalization.string("Image", bundle: .module)
        return "\(typeName) · \(imageSet.imageFiles.count) \(LumiPluginLocalization.string("variants", bundle: .module))"
    }

    // MARK: - Background

    private var checkerboardBackground: some View {
        GeometryReader { geometry in
            let tileSize: CGFloat = 10
            let cols = max(1, Int(ceil(geometry.size.width / tileSize)))
            let rows = max(1, Int(ceil(geometry.size.height / tileSize)))

            ZStack {
                Color(nsColor: .windowBackgroundColor)
                ForEach(0..<rows, id: \.self) { row in
                    ForEach(0..<cols, id: \.self) { col in
                        if (row + col) % 2 == 0 {
                            Rectangle()
                                .fill(.secondary.opacity(0.06))
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

    // MARK: - Empty & Error Views

    private var emptyView: some View {
        VStack(spacing: 10) {
            Image(systemName: "folder")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)
            Text(LumiPluginLocalization.string("No color sets or image sets found in this asset catalog.", bundle: .module))
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
    }

    private func errorView(_ error: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 28))
                .foregroundStyle(.orange)
            Text(LumiPluginLocalization.string("Failed to parse asset catalog", bundle: .module))
                .font(.headline)
                .foregroundStyle(.primary)
            Text(error)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
    }

    // MARK: - Load

    private func loadContent() {
        content = nil
        loadError = nil

        guard FileManager.default.fileExists(atPath: xcassetsURL.path) else {
            loadError = String(format: LumiPluginLocalization.string("Directory not found: %@", bundle: .module), xcassetsURL.lastPathComponent)
            return
        }

        switch XCAssetsParser.parse(xcassetsURL: xcassetsURL) {
        case let .success(parsedContent):
            content = parsedContent
        case let .failure(error):
            loadError = error.localizedDescription
        }
    }
}
