import MagicKit
import SwiftUI

/// 聊天工具栏视图 - 包含图片上传和发送/停止按钮
///
/// 模式切换（ChatModePlugin）、模型选择器（ModelSelectorPlugin）和截图（ScreenshotPlugin）
/// 已拆分为独立插件，通过右侧栏底部工具栏注入。
/// 本视图仅保留发送/停止和图片上传按钮。
struct ChatToolbarView: View, SuperLog {
    /// 日志标识 emoji
    nonisolated static let emoji = "🧰"
    /// 是否输出详细日志
    nonisolated static let verbose: Bool = false
    @EnvironmentObject var projectVM: WindowProjectVM
    @EnvironmentObject var conversationVM: WindowConversationVM
    @EnvironmentObject var agentWindowTaskCancellationVM: WindowTaskCancellationVM

    /// 待发送附件
    @EnvironmentObject private var agentAttachmentsVM: WindowAttachmentsVM

    /// 入队器：只负责把输入入队到发送队列
    @EnvironmentObject private var inputQueueVM: WindowInputQueueVM

    /// 当前窗口作用域。发送输入时优先使用 scope 持有的队列，避免多窗口环境对象错位。
    @Environment(\.windowScope) private var windowScope

    /// 主题管理器
    @EnvironmentObject private var themeVM: AppThemeVM

    /// 消息队列状态（用于判断是否真的在处理）
    @EnvironmentObject private var messageQueueVM: WindowMessageQueueVM

    /// 窗口级聊天草稿
    @ObservedObject var chatDraftVM: WindowChatDraftVM

    private var activeInputQueueVM: WindowInputQueueVM {
        windowScope?.inputQueueVM ?? inputQueueVM
    }

    var body: some View {
        VStack {
            HStack(alignment: .center, spacing: 8) {
                // 图片上传按钮
                imageUploadButton

                Spacer()

                // 发送/停止按钮
                actionButton
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 8)
        }
    }
}

// MARK: - View

extension ChatToolbarView {
    /// 当前会话是否处于 `SendController` 等写入的发送状态中（用于发送/停止切换）。
    private var isSendPipelineActive: Bool {
        guard let id = conversationVM.selectedConversationId else { return false }
        return messageQueueVM.isProcessing(for: id)
    }

    /// 发送/停止按钮视图
    @ViewBuilder
    private var actionButton: some View {
        if isSendPipelineActive {
            // 停止按钮 - 在处理中显示（仅图标）
            Button(action: {
                if let conversationId = conversationVM.selectedConversationId {
                    agentWindowTaskCancellationVM.requestCancel(conversationId: conversationId)
                }
            }) {
                Image(systemName: "stop.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.white)
                    .frame(width: 28, height: 28)
                    .background(Color.red)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .help(String(localized: "Stop Generating", table: "AgentChat"))
            .keyboardShortcut(.escape, modifiers: [])
            .accessibilityLabel(String(localized: "Stop Generating", table: "AgentChat"))
            .accessibilityHint(String(localized: "Stop Generating", table: "AgentChat"))
        } else {
            // 发送按钮 - 正常状态
            Button(action: {
                let text = chatDraftVM.text
                chatDraftVM.clear()
                activeInputQueueVM.enqueueText(text)
            }) {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.white)
                    .frame(width: 28, height: 28)
                    .background((chatDraftVM.isEmpty && agentAttachmentsVM.pendingAttachments.isEmpty) || !projectVM.isProjectSelected ? Color.gray.opacity(0.5) : Color.accentColor)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled((chatDraftVM.isEmpty && agentAttachmentsVM.pendingAttachments.isEmpty) || !projectVM.isProjectSelected)
            .help(String(localized: "Send Message", table: "AgentChat"))
            .keyboardShortcut(.return, modifiers: [.command])
            .accessibilityLabel(String(localized: "Send Message", table: "AgentChat"))
            .accessibilityHint(String(localized: "Send Message Hint", table: "AgentChat"))
        }
    }

    /// 图片上传按钮视图
    private var imageUploadButton: some View {
        Button(action: {
            selectImage()
        }) {
            Image(systemName: "photo")
                .font(.system(size: 14))
                .foregroundColor(themeVM.activeAppTheme.workspaceSecondaryTextColor())
                .frame(width: 28, height: 28)
                .background(themeVM.activeAppTheme.workspaceTextColor().opacity(0.06))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .help(String(localized: "Upload Image", table: "AgentChat"))
        .accessibilityLabel(String(localized: "Upload Image", table: "AgentChat"))
        .accessibilityHint(String(localized: "Upload Image Hint", table: "AgentChat"))
    }

    /// 选择图片文件
    private func selectImage() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.image]

        panel.begin { response in
            if response == .OK, let url = panel.url {
                agentAttachmentsVM.handleImageUpload(url: url)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ChatToolbarView(
        chatDraftVM: WindowChatDraftVM()
    )
    .inRootView()
}
