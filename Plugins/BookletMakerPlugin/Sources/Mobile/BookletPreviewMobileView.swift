#if os(iOS)
import SwiftUI

struct BookletPreviewMobileView: View {
    enum Stage: String, CaseIterable, Identifiable {
        case original = "Original"
        case imposed = "Print Layout"

        var id: String { rawValue }

        /// rawValue 只作为稳定标识，展示文案必须走本地化目录。
        var title: String { BookletLocalization.string(rawValue) }
    }

    @ObservedObject var viewModel: BookletMakerViewModel
    @State private var stage: Stage = .imposed

    var body: some View {
        VStack(spacing: 0) {
            Picker(BookletLocalization.string("Preview"), selection: $stage) {
                ForEach(Stage.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)

            Group {
                switch stage {
                case .original: originalPages
                case .imposed: imposedSheets
                }
            }
        }
        .background(Color(uiColor: .systemGroupedBackground))
    }

    private var originalPages: some View {
        GeometryReader { proxy in
            let width = min(proxy.size.width - 40, 520)
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(1 ... viewModel.currentDocument.pageCount, id: \.self) { page in
                        PDFDocumentPageView(
                            documentURL: viewModel.currentDocument.url,
                            pageNumber: page
                        )
                        .frame(width: width, height: width / viewModel.currentDocument.pageAspectRatio)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .shadow(color: .black.opacity(0.12), radius: 5, y: 2)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(20)
            }
        }
    }

    private var imposedSheets: some View {
        VStack(spacing: 0) {
            HStack {
                Label(
                    BookletLocalization.string("%lld sheets", Int64(viewModel.expectedSheetCount)),
                    systemImage: "rectangle.stack"
                )
                Spacer()
                Text(BookletLocalization.string(
                    "%lld print sides",
                    Int64(viewModel.expectedOutputPageCount)
                ))
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 20)
            .padding(.bottom, 8)

            SheetPreviewView(
                document: viewModel.currentDocument,
                settings: viewModel.settings
            )
            .padding(20)
        }
    }
}
#endif
