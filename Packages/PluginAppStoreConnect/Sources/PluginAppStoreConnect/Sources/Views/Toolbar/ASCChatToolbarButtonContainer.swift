import SwiftUI

/// 包装 ``ASCChatToolbarButton``：当前项目未绑定 ASC App 时渲染 `EmptyView`。
///
/// 用独立容器把「未绑定时不占位」的分支收敛在视图层，避免在
/// ``ASCChatToolbarButton`` 内判断 ViewModel 状态导致的布局抖动。
struct ASCChatToolbarButtonContainer: View {
    @ObservedObject var viewModel: ASCChatToolbarViewModel

    var body: some View {
        if viewModel.hasBinding {
            ASCChatToolbarButton(viewModel: viewModel)
        } else {
            EmptyView()
        }
    }
}
