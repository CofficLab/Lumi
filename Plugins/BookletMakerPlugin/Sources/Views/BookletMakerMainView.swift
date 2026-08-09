import SwiftUI

/// 主界面视图
struct BookletMakerMainView: View {
    @ObservedObject var viewModel: BookletMakerViewModel

    var body: some View {
        Group {
            switch viewModel.selectedTool {
            case .booklet:
                BookletExplanationView(
                    document: viewModel.currentDocument,
                    settings: viewModel.settings
                )
                .padding()
            case .split:
                PDFSplitWorkspaceView(viewModel: viewModel)
            }
        }
            .frame(maxWidth: .infinity)
            .frame(maxHeight: .infinity)
    }
}

// MARK: - Preview

#Preview("Empty State") {
    BookletMakerMainView(viewModel: BookletMakerViewModel())
        .frame(width: 800, height: 600)
}
