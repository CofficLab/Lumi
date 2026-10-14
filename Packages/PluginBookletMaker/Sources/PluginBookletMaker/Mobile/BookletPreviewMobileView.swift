#if os(iOS)
import SwiftUI

/// Booklet 工具移动端页面：拼版预览与原稿阅读分段切换，
/// 底部为参数摘要与生成/取消操作。
struct BookletPreviewMobileView: View {
    @ObservedObject var viewModel: BookletMakerViewModel
    let onExport: () -> Void

    @State private var readingSegment: ReadingSegment = .layout

    enum ReadingSegment: String, CaseIterable, Identifiable {
        case layout = "layout"
        case source = "source"

        var id: String { rawValue }

        var title: String {
            switch self {
            case .layout: BookletLocalization.string("Print Layout")
            case .source: BookletLocalization.string("Original PDF")
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            segmentPicker
                .padding(.horizontal, 16)
                .padding(.top, 8)

            Divider()

            switch readingSegment {
            case .layout:
                BookletPreviewStageView(
                    viewModel: viewModel,
                    onExport: onExport
                )
            case .source:
                SourcePDFReadingView(document: viewModel.currentDocument)
            }

            Divider()

            bottomBar
        }
        .navigationTitle(viewModel.currentDocument.baseFileName)
    }

    // MARK: - Segments

    private var segmentPicker: some View {
        Picker(BookletLocalization.string("View"), selection: $readingSegment) {
            ForEach(ReadingSegment.allCases) { segment in
                Text(segment.title).tag(segment)
            }
        }
        .pickerStyle(.segmented)
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
                        Label(BookletLocalization.string("Make Booklet"), systemImage: "book.closed")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(!viewModel.canExportBooklet)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.bar)
    }

    private var summaryText: some View {
        Text(BookletLocalization.string(
            "%lld pages · %lld sheets · %@",
            Int64(viewModel.currentDocument.pageCount),
            Int64(viewModel.expectedSheetCount),
            viewModel.settings.outputPaper.displayName
        ))
        .font(.footnote)
        .foregroundStyle(.secondary)
        .lineLimit(1)
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
