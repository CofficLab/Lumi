import LumiUI
import SwiftUI

// MARK: - Booklet Preview Strip

/// Horizontal strip of preview thumbnails. Shown after a successful
/// export to help the user verify the order of the first few sheets.
struct BookletPreviewStrip: View {

    @ObservedObject var viewModel: BookletMakerViewModel
    @State private var selectedIndex: Int?

    var body: some View {
        if !viewModel.thumbnails.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text(BookletLocalization.string("Preview"))
                    .font(.headline)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 12) {
                        ForEach(viewModel.thumbnails, id: \.sheetIndex) { thumb in
                            ThumbnailCard(
                                thumbnail: thumb,
                                isSelected: selectedIndex == thumb.sheetIndex,
                                onTap: { selectedIndex = thumb.sheetIndex }
                            )
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }
}

// MARK: - Thumbnail Card

private struct ThumbnailCard: View {

    let thumbnail: BookletThumbnailer.Thumbnail
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        VStack(spacing: 4) {
            Group {
                if let image = LumiPlatformImage(lumiContentsOf: thumbnail.fileURL) {
                    Image(lumiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 160)
                        .background(Color.white)
                } else {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 200, height: 160)
                        .overlay(
                            Image(systemName: "photo")
                                .foregroundStyle(.secondary)
                        )
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isSelected ? Color.accentColor : Color.gray.opacity(0.3),
                            lineWidth: isSelected ? 2 : 1)
            )

            Text(BookletLocalization.string("Sheet %lld", thumbnail.sheetIndex + 1))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }
}
