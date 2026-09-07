#if os(iOS)
import SwiftUI

/// 拆分工具移动端页面：拆分计划与原稿阅读分段切换，
/// 底部为结果摘要与生成/取消操作。
struct PDFSplitMobileView: View {
    @ObservedObject var viewModel: BookletMakerViewModel
    let onExport: () -> Void

    @State private var readingSegment: ReadingSegment = .plan

    enum ReadingSegment: String, CaseIterable, Identifiable {
        case plan = "plan"
        case source = "source"

        var id: String { rawValue }

        var title: String {
            switch self {
            case .plan: BookletLocalization.string("Split Plan")
            case .source: BookletLocalization.string("Original PDF")
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker(BookletLocalization.string("View"), selection: $readingSegment) {
                ForEach(ReadingSegment.allCases) { segment in
                    Text(segment.title).tag(segment)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.top, 8)

            Divider()

            switch readingSegment {
            case .plan:
                PDFSplitPlanEditorView(viewModel: viewModel)
            case .source:
                SourcePDFReadingView(document: viewModel.currentDocument)
            }

            Divider()

            bottomBar
        }
        .navigationTitle(viewModel.currentDocument.baseFileName)
    }

    // MARK: - Bottom bar

    private var bottomBar: some View {
        VStack(spacing: 8) {
            if viewModel.isBusy {
                busyView
            } else {
                HStack(spacing: 12) {
                    summaryText
                    Spacer()
                    Button(action: onExport) {
                        Label(BookletLocalization.string("Split"), systemImage: "scissors")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(!viewModel.canExportSplit)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.bar)
    }

    @ViewBuilder
    private var summaryText: some View {
        if viewModel.splitSegments.isEmpty {
            Text(BookletLocalization.string("Add at least one split"))
                .font(.footnote)
                .foregroundStyle(.secondary)
        } else {
            Text(BookletLocalization.string(
                "%lld pages → %lld files",
                Int64(viewModel.currentDocument.pageCount),
                Int64(viewModel.splitSegments.count)
            ))
            .font(.footnote)
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
    }

    private var busyView: some View {
        VStack(spacing: 8) {
            ProgressView(value: viewModel.progress)
            HStack {
                Text(viewModel.isCancelling
                     ? BookletLocalization.string("Cancelling…")
                     : BookletLocalization.string("Generating…"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Spacer()
                if !viewModel.isCancelling {
                    Button(BookletLocalization.string("Cancel")) {
                        viewModel.cancel()
                    }
                    .font(.footnote)
                }
            }
        }
    }
}
#endif
