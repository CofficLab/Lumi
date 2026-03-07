import MagicKit
import OSLog
import SwiftUI

/// 聊天工具栏视图 - 包含模式选择器、模型选择器、图片上传和发送/停止按钮
struct ChatToolbarView: View, SuperLog {
    /// 日志标识 emoji
    nonisolated static let emoji = "🧰"
    /// 是否输出详细日志
    nonisolated static let verbose = false

    /// 智能体提供者
    @EnvironmentObject var agentProvider: AgentProvider
    @EnvironmentObject var projectViewModel: ProjectViewModel

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
            if agentProvider.isProjectSelected {
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
    /// Commit 按钮组视图
    @ViewBuilder
    private var commitButtons: some View {
        HStack(spacing: 6) {
            // 从 PromptService 获取快捷短语
            let phrases = agentProvider.promptService.getQuickPhrases(
                projectName: projectViewModel.currentProjectName,
                projectPath: projectViewModel.currentProjectPath
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
        if agentProvider.isProcessing {
            // 停止按钮 - 在处理中显示（仅图标）
            Button(action: {
                agentProvider.cancelCurrentTask()
            }) {
                Image(systemName: "stop.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.white)
                    .frame(width: 28, height: 28)
                    .background(Color.red)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .help("停止生成")
        } else {
            // 发送按钞 - 正常状态
            Button(action: {
                let text = inputViewModel.text
                inputViewModel.clear()
                agentProvider.sendMessage(input: text)
            }) {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.white)
                    .frame(width: 28, height: 28)
                    .background(inputViewModel.isEmpty || !agentProvider.isProjectSelected ? Color.gray.opacity(0.5) : Color.accentColor)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(inputViewModel.isEmpty || !agentProvider.isProjectSelected)
            .help("发送消息")
        }
    }

    /// 模式选择器视图
    private var modeSelector: some View {
        Menu {
            ForEach(ChatMode.allCases) { mode in
                Button(action: {
                    withAnimation {
                        projectViewModel.setChatMode(mode)
                    }
                }) {
                    HStack {
                        Image(systemName: mode.iconName)
                        Text(mode.displayName)
                        Text("- \(mode.description)")
                            .foregroundColor(.secondary)
                            .font(.caption)
                        if agentProvider.chatMode == mode {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: agentProvider.chatMode.iconName)
                    .font(.system(size: 14))
                Text(agentProvider.chatMode.displayName)
                    .font(.system(size: 12))
                    .fontWeight(.medium)
                Image(systemName: "chevron.up")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            .foregroundColor(agentProvider.chatMode == .build ? DesignTokens.Color.semantic.textSecondary : Color.orange)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(agentProvider.chatMode == .build ? Color.black.opacity(0.05) : Color.orange.opacity(0.1))
            .cornerRadius(6)
        }
        .menuStyle(.borderlessButton)
        .frame(width: 80)
        .help(agentProvider.chatMode == .build ? "构建模式：可执行工具和修改代码" : "对话模式：只聊天，不执行任何操作")
    }

    /// 模型选择器视图
    private var modelSelector: some View {
        Button(action: {
            isModelSelectorPresented = true
        }) {
            HStack(spacing: 4) {
                Image(systemName: "globe")
                    .font(.system(size: 14))
                Text(agentProvider.currentModel)
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
        .help("上传图片")
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
                agentProvider.handleImageUpload(url: url)
            }
        }
    }
}

// MARK: - Preview

