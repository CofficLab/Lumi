import MagicKit
import SwiftUI

/// 聊天工具栏视图 - 包含模式选择器、模型选择器、图片上传和发送/停止按钮
struct ChatToolbarView: View, SuperLog {
    /// 日志标识 emoji
    nonisolated static let emoji = "🧰"
    /// 是否输出详细日志
    nonisolated static let verbose = false

    @EnvironmentObject var conversationTurnServices: ConversationTurnServices
    @EnvironmentObject var llmVM: LLMVM
    @EnvironmentObject var projectVM: ProjectVM
    @EnvironmentObject var conversationVM: ConversationVM
    @EnvironmentObject var agentTaskCancellationVM: TaskCancellationVM

    /// 待发送附件
    @EnvironmentObject private var agentAttachmentsVM: AttachmentsVM

    /// 入队器：只负责把输入入队到发送队列
    @EnvironmentObject private var inputQueueVM: InputQueueVM

    /// 消息队列状态（用于判断是否真的在处理）
    @EnvironmentObject private var messageQueueVM: MessageQueueVM

    /// 输入框本地状态 ViewModel
    @ObservedObject var inputViewModel: InputViewModel

    /// 模型选择器是否显示
    @Binding var isModelSelectorPresented: Bool

    var body: some View {
        VStack {
            HStack(alignment: .center, spacing: 8) {
                // 模式选择器
                modeSelector

                // 模型选择器
                modelSelector

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
                    agentTaskCancellationVM.requestCancel(conversationId: conversationId)
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
            .help(String(localized: "Stop Generating", table: "AgentInput"))
            .keyboardShortcut(.escape, modifiers: [])
            .accessibilityLabel(String(localized: "Stop Generating", table: "AgentInput"))
            .accessibilityHint(String(localized: "Stop Generating", table: "AgentInput"))
        } else {
            // 发送按钞 - 正常状态
            Button(action: {
                let text = inputViewModel.text
                inputViewModel.clear()
                inputQueueVM.enqueueText(text)
            }) {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.white)
                    .frame(width: 28, height: 28)
                    .background((inputViewModel.isEmpty && agentAttachmentsVM.pendingAttachments.isEmpty) || !projectVM.isProjectSelected ? Color.gray.opacity(0.5) : Color.accentColor)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled((inputViewModel.isEmpty && agentAttachmentsVM.pendingAttachments.isEmpty) || !projectVM.isProjectSelected)
            .help(String(localized: "Send Message", table: "AgentInput"))
            .keyboardShortcut(.return, modifiers: [.command])
            .accessibilityLabel(String(localized: "Send Message", table: "AgentInput"))
            .accessibilityHint(String(localized: "Send Message Hint", table: "AgentInput"))
        }
    }

    /// 模式选择器视图
    private var modeSelector: some View {
        Menu {
            ForEach(ChatMode.allCases) { mode in
                Button(action: {
                    withAnimation {
                        llmVM.setChatMode(mode)
                    }
                }) {
                    HStack {
                        Image(systemName: mode.iconName)
                        Text(mode.displayName)
                        Text("- \(mode.description)")
                            .foregroundColor(AppUI.Color.semantic.textSecondary)
                            .font(AppUI.Typography.caption1)
                        if llmVM.chatMode == mode {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: llmVM.chatMode.iconName)
                    .font(.system(size: 14))
                Text(llmVM.chatMode.displayName)
                    .font(.system(size: 12))
                    .fontWeight(.medium)
                Image(systemName: "chevron.up")
                    .font(.system(size: 10))
                    .foregroundColor(AppUI.Color.semantic.textSecondary)
            }
            .foregroundColor(modeForegroundColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(modeBackgroundColor)
            .cornerRadius(6)
        }
        .menuStyle(.borderlessButton)
        .frame(width: 80)
        .help(modeHelpText)
        .accessibilityLabel(String(localized: "Chat Mode", table: "AgentInput"))
        .accessibilityHint(String(localized: "Chat Mode Hint", table: "AgentInput"))
    }

    /// 根据当前模式返回前景色
    private var modeForegroundColor: Color {
        switch llmVM.chatMode {
        case .chat:
            return Color.orange
        case .build:
            return AppUI.Color.semantic.textSecondary
        }
    }

    /// 根据当前模式返回背景色
    private var modeBackgroundColor: Color {
        switch llmVM.chatMode {
        case .chat:
            return Color.orange.opacity(0.1)
        case .build:
            return Color.black.opacity(0.05)
        }
    }

    /// 根据当前模式返回帮助文本
    private var modeHelpText: String {
        switch llmVM.chatMode {
        case .chat:
            return String(localized: "Chat Mode Description", table: "AgentInput")
        case .build:
            return String(localized: "Build Mode Description", table: "AgentInput")
        }
    }

    /// 模型选择器视图
    private var modelSelector: some View {
        Button(action: {
            isModelSelectorPresented = true
        }) {
            HStack(spacing: 4) {
                Image(systemName: "globe")
                    .font(.system(size: 14))
                Text(currentModelDisplayText)
                    .font(.system(size: 12))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Image(systemName: "chevron.up")
                    .font(.system(size: 10))
                    .foregroundColor(AppUI.Color.semantic.textSecondary)
            }
            .foregroundColor(AppUI.Color.semantic.textSecondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.black.opacity(0.05))
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(String(localized: "Select Model", table: "AgentInput"))
        .accessibilityHint(String(localized: "Select Model Hint", table: "AgentInput"))
    }

    /// 当前显示的「供应商 + 模型」文案
    private var currentModelDisplayText: String {
        let model = llmVM.currentModel
        guard !model.isEmpty else {
            return String(localized: "No Model Selected", table: "AgentInput")
        }
        guard let providerType = llmVM.providerType(forId: llmVM.selectedProviderId) else {
            return model
        }
        let modelLabel: String
        if let localProvider = llmVM.createProvider(id: llmVM.selectedProviderId) as? any SuperLocalLLMProvider,
           let name = localProvider.displayName(forModelId: model) {
            modelLabel = name
        } else {
            modelLabel = model
        }
        return "\(providerType.displayName) · \(modelLabel)"
    }

    /// 图片上传按钮视图
    private var imageUploadButton: some View {
        Button(action: {
            selectImage()
        }) {
            Image(systemName: "photo")
                .font(.system(size: 14))
                .foregroundColor(AppUI.Color.semantic.textSecondary)
                .frame(width: 28, height: 28)
                .background(Color.black.opacity(0.05))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .help(String(localized: "Upload Image", table: "AgentInput"))
        .accessibilityLabel(String(localized: "Upload Image", table: "AgentInput"))
        .accessibilityHint(String(localized: "Upload Image Hint", table: "AgentInput"))
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
        inputViewModel: InputViewModel(),
        isModelSelectorPresented: .constant(false)
    )
    .inRootView()
}
