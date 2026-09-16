import Combine
import LumiUI
import KitSuperLog
import SwiftUI
import os

/// 输入框视图
///
/// View 只依赖 `ConversationInputViewModel`；发送、清空、附件操作均为
/// ViewModel 意图，不再直接访问输入/发送/性能 Provider。
struct ConversationInputView: View {
    private static let logger = Logger(
        subsystem: "com.coffic.lumi.plugin.conversation-input",
        category: "Send"
    )

    @LumiTheme private var theme
    @ObservedObject private var viewModel: ConversationInputViewModel

    init(viewModel: ConversationInputViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        let _ = viewModel.revision

        VStack(spacing: 0) {
            AppDivider()

            if let errorMessage = viewModel.errorMessage {
                InputErrorView(message: errorMessage, onDismiss: {
                    viewModel.dismissError()
                })
                .padding(.bottom, 4)
            }

            ComposerView(
                viewModel: viewModel,
                onSend: { viewModel.send() }
            )
        }
        .background(theme.background)
    }
}
