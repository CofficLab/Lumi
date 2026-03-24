import MagicKit
import SwiftUI

/// 聊天工具栏视图 - 包含模式选择器、模型选择器、图片上传和发送/停止按钮
struct ChatToolbarView: View, SuperLog {
    /// 日志标识 emoji
    nonisolated static let emoji = "🧰"
    /// 是否输出详细日志
    nonisolated static let verbose = false

    @EnvironmentObject var conversationTurnServices: ConversationTurnServices
    @EnvironmentObject var agentSessionConfig: AgentSessionVM
    @EnvironmentObject var ProjectVM: ProjectVM
    @EnvironmentObject var ConversationVM: ConversationVM
    @EnvironmentObject var agentTaskCancellationVM: TaskCancellationVM

    /// 待发送附件
    @EnvironmentObject private var agentAttachmentsVM: AttachmentsVM

    /// 入队器：只负责把输入入队到发送队列
    @EnvironmentObject private var inputQueueVM: InputQueueVM

    /// 发送链路瞬时状态（有状态文案时表示正在处理，显示「停止」）
    @EnvironmentObject private var conversationSendStatusVM: ConversationStatusVM

    /// 输入框本地状态 ViewModel
    @ObservedObject var inputViewModel: InputViewModel

    /// 模型选择器是否显示
    @Binding var isModelSelectorPresented: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            // 模式选择器
            modeSelector

            // 模型选择器
            modelSelector

            // 图片上传按钮
            imageUploadButton

            // Commit 按钮组（仅在选择项目时显示）
            if ProjectVM.isProjectSelected {
                commitButtons
            }

            Spacer()

            // 发送/停止按钮
            actionButton
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
    }
}

// MARK: - View

extension ChatToolbarView {
    /// 当前会话是否处于 `SendController` 等写入的发送状态中（用于发送/停止切换）。
    private var isSendPipelineActive: Bool {
        guard let id = ConversationVM.selectedConversationId else { return false }
        return conversationSendStatusVM.statusMessage(for: id) != nil
    }

    /// Commit 按钮组视图
    @ViewBuilder
    private var commitButtons: some View {
        HStack(spacing: 6) {
            // 从 PromptService 获取快捷短语
            let phrases = conversationTurnServices.promptService.getQuickPhrases(
                projectName: ProjectVM.currentProjectName,
                projectPath: ProjectVM.currentProjectPath
            )

            // 英文 Commit
            if let englishPhrase = phrases.first(where: { $0.title == "英文 Commit" }) {
                commitButton(
                    title: englishPhrase.title,
                    icon: englishPhrase.icon,
                    prompt: englishPhrase.prompt
                )
            }

            // 中文 Commit
            if let chinesePhrase = phrases.first(where: { $0.title == "中文 Commit" }) {
                commitButton(
                    title: chinesePhrase.title,
                    icon: chinesePhrase.icon,
                    prompt: chinesePhrase.prompt
                )
            }
        }
    }

    /// 发送/停止按钮视图
    @ViewBuilder
    private var actionButton: some View {
        if isSendPipelineActive {
            // 停止按钮 - 在处理中显示（仅图标）
            Button(action: {
                if let conversationId = ConversationVM.selectedConversationId {
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
                    .background((inputViewModel.isEmpty && agentAttachmentsVM.pendingAttachments.isEmpty) || !ProjectVM.isProjectSelected ? Color.gray.opacity(0.5) : Color.accentColor)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled((inputViewModel.isEmpty && agentAttachmentsVM.pendingAttachments.isEmpty) || !ProjectVM.isProjectSelected)
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
                        ProjectVM.setChatMode(mode)
                    }
                }) {
                    HStack {
                        Image(systemName: mode.iconName)
                        Text(mode.displayName)
                        Text("- \(mode.description)")
                            .foregroundColor(.secondary)
                            .font(.caption)
                        if ProjectVM.chatMode == mode {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: ProjectVM.chatMode.iconName)
                    .font(.system(size: 14))
                Text(ProjectVM.chatMode.displayName)
                    .font(.system(size: 12))
                    .fontWeight(.medium)
                Image(systemName: "chevron.up")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
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
        switch ProjectVM.chatMode {
        case .chat:
            return Color.orange
        case .build:
            return DesignTokens.Color.semantic.textSecondary
        }
    }

    /// 根据当前模式返回背景色
    private var modeBackgroundColor: Color {
        switch ProjectVM.chatMode {
        case .chat:
            return Color.orange.opacity(0.1)
        case .build:
            return Color.black.opacity(0.05)
        }
    }

    /// 根据当前模式返回帮助文本
    private var modeHelpText: String {
        switch ProjectVM.chatMode {
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
                    .foregroundColor(.secondary)
            }
            .foregroundColor(DesignTokens.Color.semantic.textSecondary)
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
        let model = agentSessionConfig.currentModel
        guard !model.isEmpty else {
            return String(localized: "No Model Selected", table: "AgentInput")
        }
        guard let providerType = agentSessionConfig.registry.providerType(forId: agentSessionConfig.selectedProviderId) else {
            return model
        }
        let modelLabel: String
        if let localProvider = agentSessionConfig.registry.createProvider(id: agentSessionConfig.selectedProviderId) as? any SuperLocalLLMProvider,
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
                .foregroundColor(DesignTokens.Color.semantic.textSecondary)
                .frame(width: 28, height: 28)
                .background(Color.black.opacity(0.05))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .help(String(localized: "Upload Image", table: "AgentInput"))
        .accessibilityLabel(String(localized: "Upload Image", table: "AgentInput"))
        .accessibilityHint(String(localized: "Upload Image Hint", table: "AgentInput"))
    }

    /// Commit 按钮
    /// - Parameters:
    ///   - title: 按钮标题
    ///   - icon: SF Symbols 图标名称
    ///   - prompt: 点击后填入的提示词
    private func commitButton(title: String, icon: String, prompt: String) -> some View {
        Button(action: {
            inputViewModel.set(prompt)
        }) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                    .foregroundColor(.accentColor)
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.primary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(nsColor: .controlBackgroundColor))
                    .shadow(color: .black.opacity(0.05), radius: 1, x: 0, y: 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.black.opacity(0.05), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityHint(String(localized: "Fill Prompt Hint", table: "AgentInput"))
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
