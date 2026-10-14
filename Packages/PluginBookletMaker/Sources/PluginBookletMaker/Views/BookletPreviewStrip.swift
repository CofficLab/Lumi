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
                AppSectionLabel(BookletLocalization.string("Preview"))
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
    @LumiTheme private var theme

    let thumbnail: BookletThumbnailer.Thumbnail
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        AppCard(
            style: .subtle,
            cornerRadius: DesignTokens.Radius.sm,
            padding: DesignTokens.Spacing.compactPadding,
            showShadow: false
        ) {
            VStack(spacing: 4) {
                Group {
                    if let image = LumiPlatformImage(lumiContentsOf: thumbnail.fileURL) {
                        Image(lumiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxHeight: 160)
                            .background(Color.white)
                    } else {
                        RoundedRectangle(cornerRadius: DesignTokens.Radius.sm)
                            .fill(theme.textSecondary.opacity(0.12))
                            .frame(width: 200, height: 160)
                            .overlay(
                                Image(systemName: "photo")
                                    .foregroundStyle(theme.textSecondary)
                            )
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: DesignTokens.Radius.sm)
                        .stroke(
                            isSelected ? theme.primary : theme.appSubtleBorder,
                            lineWidth: isSelected ? 2 : 1
                        )
                )

                Text(BookletLocalization.string("Sheet number %lld", thumbnail.sheetIndex + 1))
                    .font(DesignTokens.Typography.caption1)
                    .foregroundStyle(theme.textSecondary)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }
}
