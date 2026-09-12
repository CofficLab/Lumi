import LumiUI
import SwiftUI

/// 新会话按钮视图组件。
///
/// 是否挂载由 ``ConversationNewPlugin`` 根据外部状态管理；视图本身只触发
/// `NewChatViewModel` 的用户意图，不直接访问 Kernel 或 Provider。
public struct NewChatButton: View {
    @ObservedObject private var viewModel: NewChatViewModel

    init(viewModel: NewChatViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        AppIconButton(systemImage: "plus") {
            viewModel.startNewChat()
        }
    }
}
