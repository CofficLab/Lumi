import Combine
import LumiUI
import LumiLoggingKit
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
            // 这里原本还有一条 `AppDivider()`：输入框做成悬浮卡片后，卡片自身
            // 的投影已经承担了「与上方内容分开」的职责，再留一条通栏细线，
            // 读起来是「细线 + 浮起来的卡片」两层分隔线叠在一起。
            // 宿主在消息列表与底部固定区之间画的区域分隔线不受影响。

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
