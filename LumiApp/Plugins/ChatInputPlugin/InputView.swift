import AppKit
import SwiftUI
import ChatInputEditorKit

/// Agent 输入包装视图 - 管理输入区域所需的状态
///
/// 模式切换、模型选择器、发送控制和附件已拆分为独立插件。
/// 本视图仅管理输入编辑器相关状态。
struct InputView: View, SuperLog {
    /// 日志标识 emoji
    nonisolated static let emoji = "💬"
    /// 是否输出详细日志
    nonisolated static let verbose: Bool = true

    /// 入队器：只负责把输入入队
    @EnvironmentObject private var inputQueueVM: WindowInputQueueVM

    /// 当前窗口作用域。发送输入时优先使用 scope 持有的队列，避免多窗口环境对象错位。
    @Environment(\.windowContainer) private var windowContainer

    /// 主题管理器
    @EnvironmentObject private var themeVM: AppThemeVM

    /// 命令建议 ViewModel
    @EnvironmentObject var commandSuggestionViewModel: WindowCommandSuggestionVM

    /// 窗口级聊天草稿
    @EnvironmentObject private var chatDraftVM: WindowChatDraftVM

    /// 输入框是否处于聚焦状态
    @State private var isInputFocused: Bool = false

    /// 编辑器动态高度
    @State private var editorHeight: CGFloat = ChatInputEditorView.minHeight

    /// 图片文件正拖过输入框（显示「松开可添加」提示，由 `NSTextView` 更新）
    @State private var isImageDragHovering = false

    /// 会话管理
    @EnvironmentObject private var conversationVM: WindowConversationVM
    @EnvironmentObject private var projectVM: WindowProjectVM
    @EnvironmentObject private var attachmentsVM: WindowAttachmentsVM

    private var canChat: Bool {
        activeConversationVM.selectedConversationId != nil
    }

    private var activeConversationVM: WindowConversationVM {
        windowContainer?.conversationVM ?? conversationVM
    }

    private var activeProjectVM: WindowProjectVM {
        windowContainer?.projectVM ?? projectVM
    }

    private var activeAttachmentsVM: WindowAttachmentsVM {
        windowContainer?.agentAttachmentsVM ?? attachmentsVM
    }

    private var activeInputQueueVM: WindowInputQueueVM {
        windowContainer?.inputQueueVM ?? inputQueueVM
    }

    var body: some View {
        VStack(spacing: 8) {
            macEditorView
                .frame(height: editorHeight)
                .padding(.horizontal, 4)
                .padding(.top, 8)
                .padding(.bottom, 8)
                .accessibilityLabel(String(localized: "Message Input", table: "ChatInputPlugin"))
                .accessibilityHint(String(localized: "Message Input Hint", table: "ChatInputPlugin"))
        }
        .background(themeVM.activeAppTheme.workspaceBackgroundColor())
        .overlay(RoundedRectangle(cornerRadius: 0)
            .stroke(themeVM.activeAppTheme.workspaceTertiaryTextColor().opacity(0.1), lineWidth: 1))
        .shadow(color: themeVM.activeAppTheme.workspaceTertiaryTextColor().opacity(0.08), radius: 8, x: 0, y: 4)
        .overlay(alignment: .bottomLeading) {
            commandSuggestionOverlay
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(String(localized: "Input Area", table: "ChatInputPlugin"))
        .onAppear(perform: onAppear)
        // 监听「添加到聊天」事件：将文件选区信息插入输入框
        .onAddToChat { text in
            chatDraftVM.append(text)
            isInputFocused = true
        }
    }
}

// MARK: - View

extension InputView {
    /// 命令建议浮层
    private var commandSuggestionOverlay: some View {
        CommandSuggestionView { suggestion in
            chatDraftVM.set(suggestion.command + " ")
            commandSuggestionViewModel.setIsVisible(false)
            isInputFocused = true
        }
        .offset(x: 16, y: -60)
    }
}

// MARK: - Editor View

extension InputView {
    /// 编辑器视图（提取以避免类型检查超时）
    private var macEditorView: some View {
        ChatInputEditorView(
            text: $chatDraftVM.text,
            height: $editorHeight,
            textColor: NSColor(themeVM.activeAppTheme.workspaceTextColor()),
            isVerbose: Self.verbose,
            log: { message in
                ChatInputPlugin.logger.info("\(Self.t)\(message)")
            },
            onSubmit: handleSubmit,
            onArrowUp: handleArrowUp,
            onArrowDown: handleArrowDown,
            onEnter: handleEnter,
            onFileDrop: { url in
                NotificationCenter.postFileDroppedToChat(fileURL: url)
            },
            isFocused: $isInputFocused,
            cursorPosition: $chatDraftVM.cursorPosition,
            isImageDragHovering: $isImageDragHovering
        )
        .animation(.easeInOut(duration: 0.15), value: editorHeight)
        .onChange(of: chatDraftVM.text) {
            commandSuggestionViewModel.updateSuggestions(for: chatDraftVM.text)
        }
        .overlay {
            if canChat, isImageDragHovering {
                imageDropHoverOverlay
            }
        }
        .animation(.easeInOut(duration: 0.12), value: isImageDragHovering)
    }

    /// 图片拖入输入框时的松开提示
    private var imageDropHoverOverlay: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(.ultraThinMaterial)
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(
                    style: StrokeStyle(lineWidth: 2, dash: [7, 5]),
                    antialiased: true
                )
                .foregroundStyle(.secondary.opacity(0.65))

            VStack(spacing: 8) {
                Image(systemName: "photo.badge.plus")
                    .font(.title2)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.secondary)

                Text(String(localized: "Release to add image to the chat", table: "ChatInputPlugin"))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 12)
            }
        }
        .allowsHitTesting(false)
        .transition(.opacity)
    }
}

// MARK: - Editor Actions

extension InputView {
    /// 提交输入
    private func handleSubmit() {
        submitDraft()
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
        if commandSuggestionViewModel.isVisible,
           let suggestion = commandSuggestionViewModel.getCurrentSuggestion() {
            if Self.verbose {
                ChatInputPlugin.logger.info("\(Self.t)回车选择命令建议：\(suggestion.command)")
            }
            chatDraftVM.set(suggestion.command + " ")
            commandSuggestionViewModel.setIsVisible(false)
        } else {
            let text = chatDraftVM.text
            if Self.verbose {
                ChatInputPlugin.logger.info("\(Self.t)回车发送输入：\(text.count) 字符")
            }
            submitDraft(text)
        }
    }

    private func submitDraft(_ text: String? = nil) {
        let text = text ?? chatDraftVM.text
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty || !activeAttachmentsVM.pendingAttachments.isEmpty else {
            return
        }

        chatDraftVM.clear()
        editorHeight = ChatInputEditorView.minHeight

        Task { @MainActor in
            await ensureConversationSelected()
            activeInputQueueVM.enqueueText(text)
        }
    }

    private func ensureConversationSelected() async {
        guard activeConversationVM.selectedConversationId == nil else { return }

        if Self.verbose {
            ChatInputPlugin.logger.info("\(Self.t)发送前自动创建新会话")
        }

        await activeConversationVM.createNewConversation(
            projectName: activeProjectVM.isProjectSelected ? activeProjectVM.currentProjectName : nil,
            projectPath: activeProjectVM.isProjectSelected ? activeProjectVM.currentProjectPath : nil,
            languagePreference: activeProjectVM.languagePreference
        )
    }
}

// MARK: - Event Handler

extension InputView {
    func onAppear() {
        isInputFocused = true
    }
}

// MARK: - Preview

#Preview("App - Small Screen") {
    InputView()
        .frame(width: 800, height: 600)
        .inRootView()
}

#Preview("App - Big Screen") {
    InputView()
        .frame(width: 1200, height: 800)
        .inRootView()
}
