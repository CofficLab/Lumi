import SwiftUI

/// 对话列表侧栏视图：组合 HeaderBarView 与 ListView。
///
/// View 只依赖 `ConversationListViewModel`。
struct RailView: View {
    @ObservedObject private var viewModel: ConversationListViewModel

    init(viewModel: ConversationListViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        VStack(spacing: 0) {
            HeaderBarView(viewModel: viewModel)

            ListView(viewModel: viewModel)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
