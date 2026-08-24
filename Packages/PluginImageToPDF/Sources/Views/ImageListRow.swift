import SwiftUI

/// Single row showing one input image with a remove button.
struct ImageListRow: View {
    let item: ImageItem
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            thumbnail
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
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let nsImage = NSImage(contentsOf: item.url) {
            Image(nsImage: nsImage)
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
