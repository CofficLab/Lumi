import MagicKit
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Input Events

/// 输入区域视图 - 包含附件预览、编辑器、工具栏
///
/// ## 注意
/// 此视图不包含 `PendingMessagesView`，后者已移到外层视图 (`InputView`) 中。
/// 这样设计是为了避免待发送消息队列的变化导致输入框重新渲染而丢失焦点。
struct InputAreaView: View, SuperLog {
    /// 日志标识 emoji
    nonisolated static let emoji = "💬"
    /// 是否输出详细日志
    nonisolated static let verbose: Bool = true
    /// 待发送附件
    @EnvironmentObject private var agentAttachmentsVM: AttachmentsVM

    /// 入队器：只负责把输入入队
    @EnvironmentObject private var inputQueueVM: InputQueueVM

    /// 会话管理 ViewModel
    @EnvironmentObject var ConversationVM: ConversationVM

    /// 命令建议 ViewModel
    @EnvironmentObject var commandSuggestionViewModel: CommandSuggestionVM

    /// 输入框本地状态 ViewModel（与 agentProvider 解耦，避免击键触发全局重庆染）
    @ObservedObject var inputViewModel: InputViewModel

    /// 输入框是否处于聚焦状态
    @Binding var isInputFocused: Bool

    /// 模型选择器是否显示
    @Binding var isModelSelectorPresented: Bool

    /// 编辑器动态高度
    @State private var editorHeight: CGFloat = MacEditorView.minHeight

    /// 是否允许输入/发送（必须先选中会话）
    private var canChat: Bool {
        ConversationVM.selectedConversationId != nil
    }

    var body: some View {
        VStack(spacing: 8) {
            // 附件预览区域
            if !agentAttachmentsVM.pendingAttachments.isEmpty {
                AttachmentPreviewView(
                    attachments: agentAttachmentsVM.pendingAttachments,
                    onRemove: { id in
                        agentAttachmentsVM.removeAttachment(id: id)
                    }
                )
            }

            // 编辑器 - 使用动态高度
            macEditorView
                .frame(height: editorHeight)
                .padding(.horizontal, 4)
                .padding(.top, 8)
                .allowsHitTesting(canChat)
                .opacity(canChat ? 1 : 0.6)
                .accessibilityLabel(String(localized: "Message Input", table: "AgentInput"))
                .accessibilityHint(String(localized: "Message Input Hint", table: "AgentInput"))

            // 工具栏
            ChatToolbarView(
                inputViewModel: inputViewModel,
                isModelSelectorPresented: $isModelSelectorPresented
            )
            .allowsHitTesting(canChat)
            .opacity(canChat ? 1 : 0.6)
            .accessibilityLabel(String(localized: "Chat Toolbar", table: "AgentInput"))
            .accessibilityHint(String(localized: "Chat Toolbar Hint", table: "AgentInput"))
        }
        .background(.background)
        .overlay(RoundedRectangle(cornerRadius: 0)
            .stroke(Color.black.opacity(0.1), lineWidth: 1))
        .overlay {
            if !canChat {
                noConversationOverlay
            }
        }
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
        .overlay(alignment: .bottomLeading) {
            commandSuggestionOverlay
        }
        // 监听文件拖放通知（由 MacEditorView 发送）
        .onFileDroppedToChat { fileURL in
            handleFileDrop(fileURL: fileURL)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(String(localized: "Input Area", table: "AgentInput"))
    }
}

// MARK: - View

extension InputAreaView {
    /// 无会话时的遮罩层
    private var noConversationOverlay: some View {
        ZStack {
            // 半透明背景，盖住输入区域，防止误操作
            RoundedRectangle(cornerRadius: 12)
                .fill(.background.opacity(0.9))

            VStack(spacing: 8) {
                Image(systemName: "bubble.left.and.bubble.right")
                    .font(.system(size: 18))
                    .foregroundStyle(.secondary)

                Text(String(localized: "Please create or select a conversation first", table: "AgentInput"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }
            .padding(.horizontal, 16)
        }
    }

    /// 命令建议浮层
    private var commandSuggestionOverlay: some View {
        CommandSuggestionView { suggestion in
            inputViewModel.set(suggestion.command + " ")
            commandSuggestionViewModel.setIsVisible(false)
            isInputFocused = true
        }
        .offset(x: 16, y: -60)
    }
}

// MARK: - Editor View

extension InputAreaView {
    /// 编辑器视图（提取以避免类型检查超时）
    private var macEditorView: some View {
        MacEditorView(
            text: $inputViewModel.text,
            height: $editorHeight,
            onSubmit: handleSubmit,
            onArrowUp: handleArrowUp,
            onArrowDown: handleArrowDown,
            onEnter: handleEnter,
            isFocused: $isInputFocused,
            cursorPosition: $inputViewModel.cursorPosition
        )
        // 添加高度变化动画
        .animation(.easeInOut(duration: 0.15), value: editorHeight)
        // 监听文本变化以触发命令建议
        .onChange(of: inputViewModel.text) { newValue in
            commandSuggestionViewModel.updateSuggestions(for: newValue)
        }
    }
}

// MARK: - Editor Actions

extension InputAreaView {
    /// 提交输入
    private func handleSubmit() {
        guard canChat else { return }
        let text = inputViewModel.text
        inputViewModel.clear()
        inputQueueVM.enqueueText(text)
        // 发送后重置高度
        editorHeight = MacEditorView.minHeight
    }

    /// 处理上箭头键
    private func handleArrowUp() {
        if commandSuggestionViewModel.isVisible {
            commandSuggestionViewModel.selectPrevious()
        }
    }

    /// 处理下箭头键
    private func handleArrowDown() {
        if commandSuggestionViewModel.isVisible {
            commandSuggestionViewModel.selectNext()
        }
    }

    /// 处理回车键
    private func handleEnter() {
        guard canChat else { return }

        if commandSuggestionViewModel.isVisible,
           let suggestion = commandSuggestionViewModel.getCurrentSuggestion() {
            // 选择命令建议
            inputViewModel.set(suggestion.command + " ")
            commandSuggestionViewModel.setIsVisible(false)
        } else {
            // 发送消息
            let text = inputViewModel.text
            inputViewModel.clear()
            inputQueueVM.enqueueText(text)
            // 发送后重置高度
            editorHeight = MacEditorView.minHeight
        }
    }
}

// MARK: - Action

extension InputAreaView {
    /// 处理从项目树拖放的文件
    /// - Parameter fileURL: 拖放的文件 URL
    private func handleFileDrop(fileURL: URL) {
        if Self.verbose {
            AgentInputPlugin.logger.info("\(Self.t)📎 handleFileDrop: \(fileURL.path)")
        }

        // 检查是否是图片文件
        let imageExtensions = ["jpg", "jpeg", "png", "gif", "bmp", "tiff", "webp", "heic"]
        let fileExtension = fileURL.pathExtension.lowercased()

        if imageExtensions.contains(fileExtension) {
            // 图片文件：作为附件上传
            agentAttachmentsVM.handleImageUpload(url: fileURL)
        } else {
            // 非图片文件：将文件路径插入到输入框
            // 使用 append 方法自动处理空格和光标位置
            inputViewModel.append(fileURL.path)
        }

        if Self.verbose {
            AgentInputPlugin.logger.info("\(Self.t)✅ handleFileDrop 完成，text.count=\(inputViewModel.text.count), cursorPosition=\(inputViewModel.cursorPosition)")
        }
    }
}

// MARK: - Preview
