import ProviderConversation
import ProviderMessage
import ProviderMessageSender
import SwiftUI

/// 「一键续接到新对话」按钮。
///
/// 点击后**不再直接分叉**，而是弹出 `ConversationForkPopoverContent` 引导用户：
/// 先把将被带走的上下文摊开给用户看，确认后才真正执行
/// 摘要当前对话 → 建新对话 → 摘要作为首条 user 消息 → 自动续写。
struct ConversationForkButton: View {
    let coordinator: ConversationForkCoordinator

    @State private var isPopoverPresented = false
    /// 打开弹窗时锁定的源对话 ID，保证「用户看到的」与「实际分叉的」是同一份上下文。
    @State private var targetConversationID: UUID?
    @State private var preview: ConversationForkPreview?
    @State private var isPreviewLoading = false
    /// 每次打开弹窗自增，驱动预览重新加载（预览在弹窗弹出动画期间并行拉取）。
    @State private var previewRevision = 0

    var body: some View {
        Button {
            targetConversationID = coordinator.selectedConversationID
            preview = nil
            isPreviewLoading = true
            previewRevision += 1
            isPopoverPresented = true
        } label: {
            Image(systemName: "arrow.uturn.forward.circle")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)
                .padding(4)
        }
        .buttonStyle(.plain)
        .help(pluginLocalization.string("Summarize the current conversation and continue it in a new chat"))
        .task(id: previewRevision) {
            await loadPreview()
        }
        .popover(isPresented: $isPopoverPresented, arrowEdge: .bottom) {
            ConversationForkPopoverContent(
                conversationID: targetConversationID,
                preview: preview,
                isPreviewLoading: isPreviewLoading,
                coordinator: coordinator,
                isPresented: $isPopoverPresented
            )
        }
    }

    /// 拉取「将被带走的上下文」预览。
    private func loadPreview() async {
        guard let targetConversationID else {
            preview = nil
            isPreviewLoading = false
            return
        }
        isPreviewLoading = true
        preview = await coordinator.preview(for: targetConversationID)
        isPreviewLoading = false
    }
}
