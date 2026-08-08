import SwiftUI

/// 主界面视图
struct BookletMakerMainView: View {
    @ObservedObject var viewModel: BookletMakerViewModel

    var body: some View {
        BookletExplanationView(settings: viewModel.settings)
            .frame(maxWidth: .infinity)
            .frame(maxHeight: .infinity)
            .padding()
    }
}

// MARK: - Preview

#Preview("Empty State") {
    BookletMakerMainView(viewModel: BookletMakerViewModel())
        .frame(width: 800, height: 600)
}
