import SwiftUI

/// Visual split editor for the shared current PDF.
struct PDFSplitWorkspaceView: View {
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
                    .font(.title2.weight(.semibold))
                Text(BookletLocalization.string(
                    "Click a gap between pages to add or remove a cut point."
                ))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
            Spacer()
            Text(BookletLocalization.string(
                "%lld pages",
                Int64(viewModel.currentDocument.pageCount)
            ))
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.secondary)
        }
    }

    private var pageStrip: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(BookletLocalization.string("Page Sequence"))
                .font(.headline)

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
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(nsColor: .controlBackgroundColor))
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
                .font(.caption2.weight(.semibold))
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
                    .font(.headline)
                Text(BookletLocalization.string(
                    "%lld PDF files will be generated",
                    Int64(viewModel.splitSegments.count)
                ))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
            Spacer()
            if viewModel.splitCutPoints.isEmpty {
                Label(
                    BookletLocalization.string("Add at least one cut point"),
                    systemImage: "info.circle"
                )
                .font(.caption)
                .foregroundStyle(.secondary)
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
                Text(segment.fileName(baseName: viewModel.currentDocument.baseFileName))
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Text(BookletLocalization.string(
                    "Split pages %lld–%lld",
                    Int64(segment.startPage),
                    Int64(segment.endPage)
                ))
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()

            Text(BookletLocalization.string(
                "%lld pages",
                Int64(segment.pageCount)
            ))
            .font(.caption.weight(.medium))
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(Color.secondary.opacity(0.12), in: Capsule())
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.secondary.opacity(0.15))
        )
    }
}

#Preview {
    PDFSplitWorkspaceView(viewModel: BookletMakerViewModel())
        .frame(width: 900, height: 700)
}
