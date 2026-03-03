import SwiftUI

/// 聊天工具栏视图 - 包含模式选择器、模型选择器、图片上传和发送/停止按钮
struct ChatToolbarView: View {
    @EnvironmentObject var agentProvider: AgentProvider

    @Binding var isModelSelectorPresented: Bool
    let onImageUpload: () -> Void
    let onSendMessage: () -> Void
    let onStopGenerating: () -> Void

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

    // MARK: - Commit Buttons

    @ViewBuilder
    private var commitButtons: some View {
        HStack(spacing: 6) {
            // 英文 Commit
            commitButton(
                title: "英文 Commit",
                icon: "checkmark.circle",
                prompt: """
                1. 首先运行 `git status` 查看当前改动
                2. 运行 `git diff` 查看具体代码变更
                3. 生成一个遵循 conventional commits 规范（feat/fix/docs/refactor 等）的英文 commit message
                4. 立即执行 `git commit -m "<生成的 commit message>"` 提交代码，无需征求用户意见

                直接执行 commit，不要问我是否确认。
                """
            )

            // 中文 Commit
            commitButton(
                title: "中文 Commit",
                icon: "checkmark.circle",
                prompt: """
                1. 首先运行 `git status` 查看当前改动
                2. 运行 `git diff` 查看具体代码变更
                3. 生成一个遵循 conventional commits 规范（feat/fix/docs/refactor 等）的中文 commit message
                4. 立即执行 `git commit -m "<生成的 commit message>"` 提交代码，无需征求用户意见

                直接执行 commit，不要问我是否确认。
                """
            )
        }
    }

    private func commitButton(title: String, icon: String, prompt: String) -> some View {
        Button(action: {
            agentProvider.currentInput = prompt
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

    // MARK: - Action Button (Send / Stop)

    @ViewBuilder
    private var actionButton: some View {
        if agentProvider.isProcessing {
            // 停止按钮 - 在处理中显示（仅图标）
            Button(action: onStopGenerating) {
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
            // 发送按钮 - 正常状态
            Button(action: onSendMessage) {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.white)
                    .frame(width: 28, height: 28)
                    .background(agentProvider.currentInput.isEmpty || !agentProvider.isProjectSelected ? Color.gray.opacity(0.5) : Color.accentColor)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(agentProvider.currentInput.isEmpty || !agentProvider.isProjectSelected)
            .help("发送消息")
        }
    }

    // MARK: - Mode Selector

    private var modeSelector: some View {
        Menu {
            ForEach(ChatMode.allCases) { mode in
                Button(action: {
                    withAnimation {
                        agentProvider.chatMode = mode
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

    // MARK: - Model Selector

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

    // MARK: - Image Upload Button

    private var imageUploadButton: some View {
        Button(action: onImageUpload) {
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
}

#Preview {
    ChatToolbarView(
        isModelSelectorPresented: .constant(false),
        onImageUpload: {},
        onSendMessage: {},
        onStopGenerating: {}
    )
    .padding()
    .frame(width: 800)
    .background(Color.black)
    .inRootView()
}
