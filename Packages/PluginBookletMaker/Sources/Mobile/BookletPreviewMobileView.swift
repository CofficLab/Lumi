#if os(iOS)
import LumiUI
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
    @LumiTheme private var theme

    var body: some View {
        VStack(spacing: 0) {
            AppSegmentedControl(
                Stage.allCases.map(\.title),
                selection: stageSelection
            )
            .padding(.horizontal, 20)
            .padding(.vertical, 12)

            Group {
                switch stage {
                case .original: originalPages
                case .imposed: imposedSheets
                }
            }
        }
        .appSurface(style: .panel, cornerRadius: 0)
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
            AppCard(style: .subtle, cornerRadius: DesignTokens.Radius.sm, showShadow: false) {
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
                .font(DesignTokens.Typography.subheadline)
                .foregroundStyle(theme.textSecondary)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 8)

            SheetPreviewView(
                document: viewModel.currentDocument,
                settings: viewModel.settings
            )
            .padding(20)
        }
    }

    private var stageSelection: Binding<Int> {
        Binding(
            get: { Stage.allCases.firstIndex(of: stage) ?? 0 },
            set: { index in
                guard Stage.allCases.indices.contains(index) else { return }
                stage = Stage.allCases[index]
            }
        )
    }
}
#endif
