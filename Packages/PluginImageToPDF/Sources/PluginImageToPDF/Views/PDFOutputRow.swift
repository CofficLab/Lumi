import AppKit
import SwiftUI

/// Single row in the output PDF list with status, progress, and actions.
struct PDFOutputRow: View {
    let item: PDFOutputItem
    let onReveal: () -> Void
    let onOpen: () -> Void
    let onRemove: () -> Void

    /// 缩略图异步准备，首帧先显示占位图（#1189）。
    @State private var thumbnail: NSImage?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                thumbnailView
                    .frame(width: 40, height: 40)
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 6))

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.outputName)
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    statusLine
                }

                Spacer()

                actions
            }

            if item.showsProgress {
                ProgressView(value: item.progress)
                    .progressViewStyle(.linear)
            }
        }
        .padding(.vertical, 6)
        // 只在 outputURL 变化时重跑：转换进度的每次发布不再触发重新渲染。
        // 行消失时 .task 自动取消，写回前再校验一次。
        .task(id: item.status.outputURL) {
            var image: NSImage?
            if let outputURL = item.status.outputURL {
                image = await PDFThumbnailLoader.thumbnail(for: outputURL)
            }
            // PDF 尚未生成或渲染失败时退回源图片缩略图。
            if image == nil {
                image = await ImageThumbnailLoader.thumbnail(for: item.source.url)
            }
            guard !Task.isCancelled else { return }
            thumbnail = image
        }
    }

    private var statusLine: some View {
        HStack(spacing: 6) {
            statusBadge
            if case .failed(let message) = item.status {
                Text(message)
                    .font(.system(size: 11))
                    .foregroundStyle(.red)
                    .lineLimit(1)
            }
        }
    }

    private var statusBadgeColor: Color {
        switch item.status {
        case .pending:    return .secondary
        case .processing: return .blue
        case .done:       return .green
        case .failed:     return .red
        }
    }

    private var statusBadge: some View {
        Text(item.displayStatus)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(statusBadgeColor)
    }

    private var actions: some View {
        HStack(spacing: 6) {
            Button(action: onOpen) {
                Image(systemName: "eye")
            }
            .buttonStyle(.plain)
            .help(ImageToPDFLocalization.string("Open"))
            .disabled(item.status.outputURL == nil)

            Button(action: onReveal) {
                Image(systemName: "folder")
            }
            .buttonStyle(.plain)
            .help(ImageToPDFLocalization.string("Reveal in Finder"))
            .disabled(item.status.outputURL == nil)

            Button(action: onRemove) {
                Image(systemName: "trash")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help(ImageToPDFLocalization.string("Remove"))
        }
    }

    @ViewBuilder
    private var thumbnailView: some View {
        if let thumbnail {
            Image(nsImage: thumbnail)
                .resizable()
                .scaledToFill()
        } else {
            Image(systemName: "doc.richtext")
                .foregroundStyle(.secondary)
        }
    }
}