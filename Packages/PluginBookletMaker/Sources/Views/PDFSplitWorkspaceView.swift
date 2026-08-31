import LumiUI
import SwiftUI

/// Visual split editor for the shared current PDF.
struct PDFSplitWorkspaceView: View {
    @LumiTheme private var theme

    @ObservedObject var viewModel: BookletMakerViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
            pageStrip
            resultHeader
            resultList
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 3) {
                Text(BookletLocalization.string("Split PDF"))
                    .font(DesignTokens.Typography.title2)
                Text(BookletLocalization.string(
                    "Click a gap between pages to add or remove a cut point."
                ))
                .font(DesignTokens.Typography.subheadline)
                .foregroundStyle(theme.textSecondary)
            }
            Spacer()
            Text(BookletLocalization.string(
                "%lld pages",
                Int64(viewModel.currentDocument.pageCount)
            ))
            .font(DesignTokens.Typography.subheadline)
            .foregroundStyle(theme.textSecondary)
        }
    }

    private var pageStrip: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(BookletLocalization.string("Page Sequence"))
                .font(DesignTokens.Typography.title3)

            ScrollView(.horizontal) {
                LazyHStack(spacing: 0) {
                    ForEach(1 ... viewModel.currentDocument.pageCount, id: \.self) { page in
                        pageThumbnail(page)
                        if page < viewModel.currentDocument.pageCount {
                            cutPointButton(after: page)
                        }
                    }
                }
                .padding(12)
            }
            .frame(height: 205)
            .appSurface(
                style: .subtle,
                cornerRadius: DesignTokens.Radius.md,
                borderColor: theme.appSubtleBorder
            )
        }
    }

    private func pageThumbnail(_ page: Int) -> some View {
        ZStack(alignment: .bottomLeading) {
            PDFDocumentPageView(
                documentURL: viewModel.currentDocument.url,
                pageNumber: page
            )
            .frame(width: 105, height: 155)

            Text("\(page)")
                .font(DesignTokens.Typography.caption2)
                .padding(.horizontal, 5)
                .padding(.vertical, 3)
                .foregroundStyle(.white)
                .background(.black.opacity(0.7), in: Capsule())
                .padding(6)
        }
        .accessibilityLabel(BookletLocalization.string("Page %lld", Int64(page)))
    }

    private func cutPointButton(after page: Int) -> some View {
        let isSelected = viewModel.splitCutPoints.contains(page)
        return Button {
            viewModel.toggleSplit(after: page)
        } label: {
            VStack(spacing: 5) {
                Rectangle()
                    .fill(isSelected ? Color.accentColor : Color.secondary.opacity(0.22))
                    .frame(width: isSelected ? 3 : 1, height: 56)
                Image(systemName: isSelected ? "scissors.circle.fill" : "plus.circle")
                    .font(.system(size: isSelected ? 18 : 15))
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                Rectangle()
                    .fill(isSelected ? Color.accentColor : Color.secondary.opacity(0.22))
                    .frame(width: isSelected ? 3 : 1, height: 56)
            }
            .frame(width: 30, height: 155)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(BookletLocalization.string("Split after page %lld", Int64(page)))
        .accessibilityLabel(BookletLocalization.string("Split after page %lld", Int64(page)))
    }

    private var resultHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(BookletLocalization.string("Split Result"))
                    .font(DesignTokens.Typography.title3)
                Text(BookletLocalization.string(
                    "%lld PDF files will be generated",
                    Int64(viewModel.splitSegments.count)
                ))
                .font(DesignTokens.Typography.subheadline)
                .foregroundStyle(theme.textSecondary)
            }
            Spacer()
            if viewModel.splitCutPoints.isEmpty {
                Label(
                    BookletLocalization.string("Add at least one cut point"),
                    systemImage: "info.circle"
                )
                .font(DesignTokens.Typography.caption1)
                .foregroundStyle(theme.textSecondary)
            }
        }
    }

    private var resultList: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(viewModel.splitSegments) { segment in
                    segmentRow(segment)
                }
            }
        }
    }

    private func segmentRow(_ segment: PDFSplitSegment) -> some View {
        HStack(spacing: 14) {
            Image(systemName: "doc.richtext")
                .font(.system(size: 22))
                .foregroundStyle(Color.accentColor)
                .frame(width: 34)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: "pencil")
                        .font(DesignTokens.Typography.caption1)
                        .foregroundStyle(theme.textSecondary)
                    AppInputField(
                        LocalizedStringKey(BookletLocalization.string("Output file name")),
                        text: Binding(
                            get: { viewModel.splitFileNameStem(for: segment) },
                            set: { viewModel.renameSplitOutputStem(segment, to: $0) }
                        )
                    )
                    .accessibilityLabel(BookletLocalization.string(
                        "Rename output PDF %lld",
                        Int64(segment.index)
                    ))
                    Text(BookletLocalization.string(".pdf"))
                        .font(DesignTokens.Typography.subheadline)
                        .foregroundStyle(theme.textSecondary)
                }

                if let message = viewModel.splitFileNameValidationMessage(for: segment) {
                    Text(message)
                        .font(DesignTokens.Typography.caption2)
                        .foregroundStyle(theme.error)
                }

                Text(BookletLocalization.string(
                    "Split pages %lld–%lld",
                    Int64(segment.startPage),
                    Int64(segment.endPage)
                ))
                .font(DesignTokens.Typography.caption1)
                .foregroundStyle(theme.textSecondary)
            }

            Spacer()

            AppTag(BookletLocalization.string(
                "%lld pages",
                Int64(segment.pageCount)
            ))
        }
        .padding(12)
        .appSurface(
            style: .listRow,
            cornerRadius: DesignTokens.Radius.md,
            borderColor: theme.appSubtleBorder
        )
    }
}

#Preview {
    PDFSplitWorkspaceView(viewModel: BookletMakerViewModel())
        .frame(width: 900, height: 700)
}
