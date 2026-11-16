import SwiftUI

/// Single row showing one input image with a remove button.
struct ImageListRow: View {
    let item: ImageItem
    let onRemove: () -> Void

    /// 缩略图异步加载，首帧先显示占位图（#1196）。
    @State private var thumbnail: NSImage?

    var body: some View {
        HStack(spacing: 12) {
            thumbnailView
                .frame(width: 36, height: 36)
                .background(Color.secondary.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 2) {
                Text(item.lastPathComponent)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(formattedSize)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                onRemove()
            } label: {
                Image(systemName: "trash.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help(ImageToPDFLocalization.string("Remove"))
        }
        .padding(.vertical, 6)
        // 行消失或换条目时 .task 自动取消；写回前再校验一次，避免旧结果覆盖。
        .task(id: item.id) {
            let image = await ImageThumbnailLoader.thumbnail(for: item.url)
            guard !Task.isCancelled else { return }
            thumbnail = image
        }
    }

    @ViewBuilder
    private var thumbnailView: some View {
        if let thumbnail {
            Image(nsImage: thumbnail)
                .resizable()
                .scaledToFill()
        } else {
            Image(systemName: "photo")
                .foregroundStyle(.secondary)
        }
    }

    private var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: Int64(item.fileSize), countStyle: .file)
    }
}
