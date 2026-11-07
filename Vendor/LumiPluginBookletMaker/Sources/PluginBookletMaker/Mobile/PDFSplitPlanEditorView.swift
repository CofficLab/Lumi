#if os(iOS)
import BookletMakerCore
import SwiftUI

/// Swipe through adjacent pages and place a cut at the boundary between them.
struct PDFSplitPlanEditorView: View {
    @ObservedObject var viewModel: BookletMakerViewModel

    @State private var visiblePairStart = 1

    private var segments: [PDFSplitSegment] { viewModel.splitSegments }
    private var pageCount: Int { viewModel.currentDocument.pageCount }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 15) {
                if let message = viewModel.splitValidationMessage {
                    validationBanner(message)
                }

                pagePairCard
                splitSummary
            }
            .padding(16)
            .frame(maxWidth: 680)
            .frame(maxWidth: .infinity)
        }
        .onChange(of: pageCount) { newValue in
            visiblePairStart = min(visiblePairStart, max(newValue - 1, 1))
        }
    }

    private var pagePairCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(BookletLocalization.string("Swipe through pages, then tap the scissors between them to split."))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            pageNavigation
            pagePair(startingAt: visiblePairStart)
                .padding(.horizontal, 4)
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 28).onEnded { value in
                    guard abs(value.translation.width) > abs(value.translation.height) else { return }
                    navigatePair(by: value.translation.width < 0 ? 1 : -1)
                })

            HStack(spacing: 7) {
                Image(systemName: "scissors")
                    .foregroundStyle(BookletMobileStyle.accent)
                Text(BookletLocalization.string("%lld split points · %lld files",
                                               Int64(viewModel.splitCutPoints.count),
                                               Int64(viewModel.splitSegments.count)))
                    .font(.footnote.weight(.medium))
                    // 稳定锚点：切分点与文件数的变化必须被 UI 测试看得到，
                    // 否则「点了切分点但摘要没变」这类回归无从发现。
                    //
                    // 锚点挂在 Text 上而不是外层 HStack：SwiftUI 会把
                    // identifier 下推到子元素，挂在容器上会落到剪刀图标上，
                    // 读出来的是 "Cut" 而不是摘要文案。
                    .accessibilityIdentifier("split.summary")
                Spacer()
            }
            .padding(10)
            .background(BookletMobileStyle.softAccent, in: Capsule())
        }
        .padding(14)
        .background(BookletMobileStyle.card, in: RoundedRectangle(cornerRadius: 16))
    }

    private var pageNavigation: some View {
        HStack {
            Button {
                navigatePair(by: -1)
            } label: {
                Image(systemName: "chevron.left")
                    .frame(width: 34, height: 30)
            }
            .disabled(visiblePairStart <= 1)
            .accessibilityLabel(BookletLocalization.string("Previous"))
            .accessibilityIdentifier("split.pagePrevious")

            Spacer()
            Text(BookletLocalization.string("Pages %lld–%lld",
                                           Int64(visiblePairStart),
                                           Int64(min(visiblePairStart + 1, pageCount))))
                .font(.caption.weight(.medium).monospacedDigit())
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("split.pageRange")
            Spacer()

            Button {
                navigatePair(by: 1)
            } label: {
                Image(systemName: "chevron.right")
                    .frame(width: 34, height: 30)
            }
            .disabled(visiblePairStart >= max(pageCount - 1, 1))
            .accessibilityLabel(BookletLocalization.string("Next"))
            .accessibilityIdentifier("split.pageNext")
        }
        .buttonStyle(.plain)
        .foregroundStyle(BookletMobileStyle.accent)
    }

    private func navigatePair(by offset: Int) {
        let lastStart = max(pageCount - 1, 1)
        withAnimation(.easeInOut(duration: 0.18)) {
            visiblePairStart = min(max(visiblePairStart + offset, 1), lastStart)
        }
    }

    private func pagePair(startingAt page: Int) -> some View {
        HStack(spacing: 4) {
            pageCard(page)
            splitBoundaryButton(after: page)
            if page + 1 <= pageCount {
                pageCard(page + 1)
            } else {
                RoundedRectangle(cornerRadius: 7)
                    .fill(Color.secondary.opacity(0.08))
                    .overlay {
                        Text(BookletLocalization.string("End of PDF"))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 166)
            }
        }
    }

    private func pageCard(_ page: Int) -> some View {
        VStack(spacing: 6) {
            PDFDocumentPageView(documentURL: viewModel.currentDocument.url, pageNumber: page)
                .frame(maxWidth: .infinity)
                .frame(height: 166)
                .background(.white)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .shadow(color: .black.opacity(0.1), radius: 3, y: 1)
            Text(BookletLocalization.string("Page %lld", Int64(page)))
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func splitBoundaryButton(after page: Int) -> some View {
        let isSelected = viewModel.splitCutPoints.contains(page)
        return Button {
            guard page < pageCount else { return }
            withAnimation(.easeInOut(duration: 0.16)) {
                viewModel.toggleSplit(after: page)
            }
        } label: {
            VStack(spacing: 6) {
                Rectangle()
                    .fill(isSelected ? BookletMobileStyle.accent.opacity(0.55) : Color.secondary.opacity(0.28))
                    .frame(width: 1.5, height: 30)
                Image(systemName: isSelected ? "scissors.circle.fill" : "scissors")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(isSelected ? BookletMobileStyle.accent : .secondary)
                Rectangle()
                    .fill(isSelected ? BookletMobileStyle.accent.opacity(0.55) : Color.secondary.opacity(0.28))
                    .frame(width: 1.5, height: 30)
            }
            .frame(width: 36, height: 166)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(page >= pageCount)
        .accessibilityLabel(BookletLocalization.string(
            isSelected ? "Remove split after page %lld" : "Split after page %lld", Int64(page)
        ))
        .accessibilityIdentifier("split.boundary.\(page)")
    }

    private var splitSummary: some View {
        VStack(alignment: .leading, spacing: 9) {
            Label(BookletLocalization.string("Files to export"), systemImage: "doc.on.doc")
                .font(.subheadline.weight(.semibold))
            ForEach(segments, id: \.rangeKey) { segment in
                HStack(spacing: 10) {
                    Image(systemName: "doc.text")
                        .foregroundStyle(BookletMobileStyle.accent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(segment.rangeLabel)
                            .font(.footnote.weight(.medium))
                            .lineLimit(1)
                        Text(BookletLocalization.string("%lld pages", Int64(segment.pageCount)))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("#\(segment.index)")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(BookletMobileStyle.accent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(BookletMobileStyle.softAccent, in: Capsule())
                }
                if segment != segments.last { Divider() }
            }
        }
        .padding(14)
        .background(BookletMobileStyle.card, in: RoundedRectangle(cornerRadius: 14))
    }

    private func validationBanner(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
            Text(message).font(.footnote)
            Spacer(minLength: 0)
        }
        .foregroundStyle(.orange)
        .padding(11)
        .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 11))
    }

}
#endif
