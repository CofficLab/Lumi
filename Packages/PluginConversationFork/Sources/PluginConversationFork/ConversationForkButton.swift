import ProviderConversation
import ProviderMessage
import ProviderMessageSender
import SwiftUI

/// 「一键续接到新对话」按钮。
///
/// 点击后**不再直接分叉**，而是弹出 `ConversationForkPopoverContent` 引导用户：
/// 先把将被带走的上下文摊开给用户看，确认后才真正执行
/// 摘要当前对话 → 建新对话 → 摘要作为首条 user 消息 → 自动续写。
///
/// 预览状态由 `ConversationForkPreviewModel` 持有：异步加载回来时按代次
/// 校验身份，旧请求不会把上一个对话的预览盖到当前弹窗上（#463）。
struct ConversationForkButton: View {
    let coordinator: ConversationForkCoordinator

    @StateObject private var previewModel: ConversationForkPreviewModel
    @State private var isPopoverPresented = false

    init(coordinator: ConversationForkCoordinator) {
        self.coordinator = coordinator
        _previewModel = StateObject(wrappedValue: ConversationForkPreviewModel(coordinator: coordinator))
    }

    var body: some View {
        Button {
            previewModel.open(for: coordinator.selectedConversationID)
            isPopoverPresented = true
        } label: {
            Image(systemName: "arrow.uturn.forward.circle")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)
                .padding(4)
        }
        .buttonStyle(.plain)
        .help(pluginLocalization.string("Summarize the current conversation and continue it in a new chat"))
        .popover(isPresented: $isPopoverPresented, arrowEdge: .bottom) {
            ConversationForkPopoverContent(
                conversationID: previewModel.target,
                preview: previewModel.preview,
                isPreviewLoading: previewModel.isLoading,
                coordinator: coordinator,
                isPresented: $isPopoverPresented
            )
        }
    }
}