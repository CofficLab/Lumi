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
            case .split:
                PDFSplitWorkspaceView(viewModel: viewModel)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(maxHeight: .infinity)
    }
}
