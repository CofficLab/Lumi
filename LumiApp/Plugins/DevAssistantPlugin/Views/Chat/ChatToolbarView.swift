import SwiftUI

/// 聊天工具栏视图 - 包含模式选择器、模型选择器、图片上传和发送按钮
struct ChatToolbarView: View {
    @ObservedObject var viewModel: AssistantViewModel
    @Binding var isModelSelectorPresented: Bool
    let onImageUpload: () -> Void
    let onSendMessage: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            // 模式选择器
            modeSelector

            // 模型选择器
            modelSelector

            // 图片上传按钮
            imageUploadButton

            Spacer()

            // 发送按钮
            sendButton
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
    }

    // MARK: - Mode Selector

    private var modeSelector: some View {
        Menu {
            ForEach(ChatMode.allCases) { mode in
                Button(action: {
                    withAnimation {
                        viewModel.chatMode = mode
                    }
                }) {
                    HStack {
                        Image(systemName: mode.iconName)
                        Text(mode.displayName)
                        Text("- \(mode.description)")
                            .foregroundColor(.secondary)
                            .font(.caption)
                        if viewModel.chatMode == mode {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: viewModel.chatMode.iconName)
                    .font(.system(size: 14))
                Text(viewModel.chatMode.displayName)
                    .font(.system(size: 12))
                    .fontWeight(.medium)
                Image(systemName: "chevron.up")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            .foregroundColor(viewModel.chatMode == .build ? DesignTokens.Color.semantic.textSecondary : Color.orange)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(viewModel.chatMode == .build ? Color.black.opacity(0.05) : Color.orange.opacity(0.1))
            .cornerRadius(6)
        }
        .menuStyle(.borderlessButton)
        .frame(width: 80)
        .help(viewModel.chatMode == .build ? "构建模式：可执行工具和修改代码" : "对话模式：只聊天，不执行任何操作")
    }

    // MARK: - Model Selector

    private var modelSelector: some View {
        Button(action: {
            isModelSelectorPresented = true
        }) {
            HStack(spacing: 4) {
                Image(systemName: "globe")
                    .font(.system(size: 14))
                Text(viewModel.currentModel)
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
        .help("Upload Image")
    }

    // MARK: - Send Button

    private var sendButton: some View {
        Group {
            if viewModel.isProcessing {
                ProgressView()
                    .controlSize(.small)
                    .frame(width: 28, height: 28)
            } else {
                Button(action: onSendMessage) {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.white)
                        .frame(width: 28, height: 28)
                        .background(viewModel.currentInput.isEmpty || !viewModel.isProjectSelected ? Color.gray.opacity(0.5) : Color.accentColor)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .disabled(viewModel.currentInput.isEmpty || !viewModel.isProjectSelected)
            }
        }
    }
}

#Preview {
    ChatToolbarView(
        viewModel: AssistantViewModel(),
        isModelSelectorPresented: .constant(false),
        onImageUpload: {},
        onSendMessage: {}
    )
    .padding()
    .frame(width: 800)
    .background(Color.black)
}
