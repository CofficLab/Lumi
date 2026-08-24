#if os(iOS)
import SwiftUI

struct PDFSplitMobileView: View {
    @ObservedObject var viewModel: BookletMakerViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(BookletLocalization.string("Choose where to split"))
                        .font(.title2.bold())
                    Text(BookletLocalization.string(
                        "Tap a gap between pages. Blue scissors mark a split point."
                    ))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }

                pageStrip

                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(BookletLocalization.string("Output"))
                            .font(.headline)
                        Text(BookletLocalization.string(
                            "%lld PDF files",
                            Int64(viewModel.splitSegments.count)
                        ))
                        .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if viewModel.splitCutPoints.isEmpty {
                        Label(BookletLocalization.string("Add a split"), systemImage: "info.circle")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                LazyVStack(spacing: 12) {
                    ForEach(viewModel.splitSegments) { segment in
                        resultCard(segment)
                    }
                }
            }
            .padding(20)
        }
        .background(Color(uiColor: .systemGroupedBackground))
    }

    private var pageStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 0) {
                ForEach(1 ... viewModel.currentDocument.pageCount, id: \.self) { page in
                    pageCard(page)
                    if page < viewModel.currentDocument.pageCount {
                        splitButton(after: page)
                    }
                }
            }
            .padding(14)
        }
        .frame(height: 230)
        .background(.background, in: RoundedRectangle(cornerRadius: 18))
    }

    private func pageCard(_ page: Int) -> some View {
        ZStack(alignment: .bottomLeading) {
            PDFDocumentPageView(documentURL: viewModel.currentDocument.url, pageNumber: page)
                .frame(width: 112, height: 166)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .shadow(color: .black.opacity(0.12), radius: 3, y: 2)

            Text("\(page)")
                .font(.caption2.bold())
                .foregroundStyle(.white)
                .padding(.horizontal, 7)
                .padding(.vertical, 4)
                .background(.black.opacity(0.7), in: Capsule())
                .padding(7)
        }
        .accessibilityLabel(BookletLocalization.string("Page %lld", Int64(page)))
    }

    private func splitButton(after page: Int) -> some View {
        let selected = viewModel.splitCutPoints.contains(page)
        return Button {
            withAnimation(.snappy) { viewModel.toggleSplit(after: page) }
        } label: {
            VStack(spacing: 7) {
                Rectangle()
                    .fill(selected ? Color.accentColor : .secondary.opacity(0.2))
                    .frame(width: selected ? 3 : 1, height: 52)
                Image(systemName: selected ? "scissors.circle.fill" : "plus.circle")
                    .font(.title3)
                    .foregroundStyle(selected ? Color.accentColor : .secondary)
                Rectangle()
                    .fill(selected ? Color.accentColor : .secondary.opacity(0.2))
                    .frame(width: selected ? 3 : 1, height: 52)
            }
            .frame(width: 48, height: 166)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(BookletLocalization.string("Split after page %lld", Int64(page)))
        .accessibilityValue(BookletLocalization.string(selected ? "Selected" : "Not selected"))
    }

    private func resultCard(_ segment: PDFSplitSegment) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(
                    BookletLocalization.string(
                        "Pages range %lld–%lld",
                        Int64(segment.startPage),
                        Int64(segment.endPage)
                    ),
                    systemImage: "doc.richtext"
                )
                .font(.headline)
                Spacer()
                Text(BookletLocalization.string("%lld pages", Int64(segment.pageCount)))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 6) {
                TextField(
                    BookletLocalization.string("File name"),
                    text: Binding(
                        get: { viewModel.splitFileNameStem(for: segment) },
                        set: { viewModel.renameSplitOutputStem(segment, to: $0) }
                    )
                )
                .textFieldStyle(.roundedBorder)
                Text(".pdf").foregroundStyle(.secondary)
            }

            if let message = viewModel.splitFileNameValidationMessage(for: segment) {
                Text(message).font(.footnote).foregroundStyle(.red)
            }
        }
        .padding(16)
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
    }
}
#endif
