#if os(iOS)
import LumiUI
import SwiftUI

struct PDFSplitMobileView: View {
    @LumiTheme private var theme

    @ObservedObject var viewModel: BookletMakerViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(BookletLocalization.string("Choose where to split"))
                        .font(DesignTokens.Typography.title2)
                    Text(BookletLocalization.string(
                        "Tap a gap between pages. Blue scissors mark a split point."
                    ))
                    .font(DesignTokens.Typography.subheadline)
                    .foregroundStyle(theme.textSecondary)
                }

                pageStrip

                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(BookletLocalization.string("Output"))
                            .font(DesignTokens.Typography.title3)
                        Text(BookletLocalization.string(
                            "%lld PDF files",
                            Int64(viewModel.splitSegments.count)
                        ))
                        .foregroundStyle(theme.textSecondary)
                    }
                    Spacer()
                    if viewModel.splitCutPoints.isEmpty {
                        Label(BookletLocalization.string("Add a split"), systemImage: "info.circle")
                            .font(DesignTokens.Typography.caption1)
                            .foregroundStyle(theme.textSecondary)
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
        .appSurface(style: .panel, cornerRadius: 0)
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
        .appSurface(style: .subtle, cornerRadius: DesignTokens.Radius.md)
    }

    private func pageCard(_ page: Int) -> some View {
        ZStack(alignment: .bottomLeading) {
            PDFDocumentPageView(documentURL: viewModel.currentDocument.url, pageNumber: page)
                .frame(width: 112, height: 166)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .shadow(color: .black.opacity(0.12), radius: 3, y: 2)

            Text("\(page)")
                .font(DesignTokens.Typography.caption2)
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
        AppCard(style: .subtle, cornerRadius: DesignTokens.Radius.md, showShadow: false) {
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
                    .font(DesignTokens.Typography.bodyEmphasized)
                    Spacer()
                    AppTag(BookletLocalization.string("%lld pages", Int64(segment.pageCount)))
                }

                HStack(spacing: 6) {
                    AppInputField(
                        LocalizedStringKey(BookletLocalization.string("File name")),
                        text: Binding(
                            get: { viewModel.splitFileNameStem(for: segment) },
                            set: { viewModel.renameSplitOutputStem(segment, to: $0) }
                        )
                    )
                    Text(LumiPluginLocalization.string(".pdf", bundle: .module))
                        .foregroundStyle(theme.textSecondary)
                }

                if let message = viewModel.splitFileNameValidationMessage(for: segment) {
                    AppErrorBanner(message: LocalizedStringKey(message))
                }
            }
        }
    }
}
#endif
