#if os(iOS)
import SwiftUI

struct BookletPreviewMobileView: View {
    enum Stage: String, CaseIterable, Identifiable {
        case original = "Original"
        case imposed = "Print Layout"

        var id: String { rawValue }
    }

    @ObservedObject var viewModel: BookletMakerViewModel
    @State private var stage: Stage = .imposed

    var body: some View {
        VStack(spacing: 0) {
            Picker("Preview", selection: $stage) {
                ForEach(Stage.allCases) { Text($0.rawValue).tag($0) }
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
                Label("\(viewModel.expectedSheetCount) sheets", systemImage: "rectangle.stack")
                Spacer()
                Text("\(viewModel.expectedOutputPageCount) print sides")
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
