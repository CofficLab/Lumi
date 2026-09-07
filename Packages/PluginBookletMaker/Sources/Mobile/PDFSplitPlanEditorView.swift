#if os(iOS)
import SwiftUI

/// 拆分计划编辑器：页序原样展示（不重排），可点击页面间分隔点
/// 拆分/合并，支持批量分隔输入与逐段命名，命名冲突即时校验。
struct PDFSplitPlanEditorView: View {
    @ObservedObject var viewModel: BookletMakerViewModel

    private var segments: [PDFSplitSegment] { viewModel.splitSegments }
    private var pageCount: Int { viewModel.currentDocument.pageCount }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if viewModel.splitValidationMessage != nil || viewModel.splitFileNameValidationMessage != nil {
                    validationBanner
                }

                batchInputCard

                pageOrderCard

                namingCard
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    // MARK: - Validation

    @ViewBuilder
    private var validationBanner: some View {
        let message = viewModel.splitValidationMessage
            ?? viewModel.splitFileNameValidationMessage
        if let message {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                Text(message)
                    .font(.footnote)
                Spacer()
            }
            .padding(10)
            .background(.yellow.opacity(0.16), in: RoundedRectangle(cornerRadius: 10))
        }
    }

    // MARK: - Batch cut-point input

    private var batchInputCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(BookletLocalization.string("Split after pages"), systemImage: "scissors")
                .font(.subheadline.weight(.semibold))
            TextField(
                BookletLocalization.string("e.g. 2, 5 or 3 8"),
                text: $viewModel.splitCutPointsText
            )
            .textInputAutocapitalization(.never)
            .keyboardType(.numbersAndPunctuation)
            .textFieldStyle(.roundedBorder)
            .accessibilityLabel(BookletLocalization.string("Split after pages"))
            Text(BookletLocalization.string("Comma- or space-separated page numbers"))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(12)
        .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Page order

    private var pageOrderCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(BookletLocalization.string("Page order"), systemImage: "list.number")
                .font(.subheadline.weight(.semibold))

            if pageCount <= 10 {
                pageGrid
            } else {
                pageRows
            }
        }
        .padding(12)
        .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
    }

    private var pageGrid: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3),
            spacing: 10
        ) {
            ForEach(1...pageCount, id: \.self) { page in
                pageCell(page)
            }
        }
    }

    private func pageCell(_ page: Int) -> some View {
        let splitAfter = viewModel.splitCutPoints.contains(page)
        return VStack(spacing: 3) {
            PDFDocumentPageView(
                documentURL: viewModel.currentDocument.url,
                pageNumber: page
            )
            .frame(height: 92)
            .overlay(alignment: .bottom) {
                splitDot(page, splitAfter: splitAfter)
            }
            Text(BookletLocalization.string("Page %lld", Int64(page)))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.15)) {
                viewModel.toggleSplit(after: page)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(BookletLocalization.string(
            "Page %lld, %@",
            Int64(page),
            splitAfter
                ? BookletLocalization.string("split after this page")
                : BookletLocalization.string("no split after this page")
        ))
        .accessibilityAddTraits(.isButton)
    }

    private var pageRows: some View {
        VStack(spacing: 4) {
            ForEach(1...pageCount, id: \.self) { page in
                let splitAfter = viewModel.splitCutPoints.contains(page)
                HStack(spacing: 10) {
                    PDFDocumentPageView(
                        documentURL: viewModel.currentDocument.url,
                        pageNumber: page
                    )
                    .frame(width: 34, height: 46)
                    Text(BookletLocalization.string("Page %lld", Int64(page)))
                        .font(.footnote)
                    Spacer()
                    Image(systemName: splitAfter ? "scissors" : "circle.dashed")
                        .foregroundStyle(splitAfter ? Color.accentColor : Color.secondary)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        viewModel.toggleSplit(after: page)
                    }
                }
                .accessibilityAddTraits(.isButton)
                .accessibilityLabel(BookletLocalization.string(
                    "Page %lld, %@",
                    Int64(page),
                    splitAfter
                        ? BookletLocalization.string("split after this page")
                        : BookletLocalization.string("no split after this page")
                ))
            }
        }
    }

    @ViewBuilder
    private func splitDot(_ page: Int, splitAfter: Bool) -> some View {
        if splitAfter {
            Image(systemName: "scissors")
                .font(.caption2)
                .padding(3)
                .background(Color.accentColor, in: Circle())
                .foregroundStyle(.white)
        }
    }

    // MARK: - Naming

    private var namingCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(BookletLocalization.string("File names"), systemImage: "pencil")
                .font(.subheadline.weight(.semibold))

            ForEach(segments, id: \.rangeKey) { segment in
                HStack(spacing: 10) {
                    Text(segment.rangeLabel)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(width: 86, alignment: .leading)
                    TextField(
                        BookletLocalization.string("Name"),
                        text: Binding(
                            get: { viewModel.splitFileNameStem(for: segment) },
                            set: { viewModel.renameSplitOutputStem(segment, to: $0) }
                        )
                    )
                    .textInputAutocapitalization(.never)
                    .textFieldStyle(.roundedBorder)
                    .font(.footnote)
                    .accessibilityLabel(
                        BookletLocalization.string("File name for %@", segment.rangeLabel)
                    )
                }
            }

            if let message = viewModel.splitFileNameValidationMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .padding(12)
        .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
    }
}
#endif
