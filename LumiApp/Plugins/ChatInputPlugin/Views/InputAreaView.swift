import AppKit
import MagicKit
import SwiftUI

// MARK: - Input Events

/// 输入区域视图 - 包含输入编辑器和命令建议
///
/// ## 注意
/// 此视图不包含 `PendingMessagesView`，后者已拆分到 `ChatPendingMessagesPlugin`。
/// 这样设计是为了避免待发送消息队列的变化导致输入框重新渲染而丢失焦点。
struct InputAreaView: View, SuperLog {
    /// 日志标识 emoji
    nonisolated static let emoji = "💬"
    /// 是否输出详细日志
    nonisolated static let verbose: Bool = false

    /// 入队器：只负责把输入入队
    @EnvironmentObject private var inputQueueVM: WindowInputQueueVM

    /// 当前窗口作用域。发送输入时优先使用 scope 持有的队列，避免多窗口环境对象错位。
    @Environment(\.windowScope) private var windowScope

    /// 主题管理器
    @EnvironmentObject private var themeVM: AppThemeVM

    /// 会话管理 ViewModel
    @EnvironmentObject var WindowConversationVM: WindowConversationVM

    /// 命令建议 ViewModel
    @EnvironmentObject var commandSuggestionViewModel: WindowCommandSuggestionVM

    /// 输入框本地状态 ViewModel（与 agentProvider 解耦，避免击键触发全局重庆染）
    @ObservedObject var chatDraftVM: WindowChatDraftVM

    /// 输入框是否处于聚焦状态
    @Binding var isInputFocused: Bool

    /// 编辑器动态高度
    @State private var editorHeight: CGFloat = MacEditorView.minHeight

    /// 图片文件正拖过输入框（显示「松开可添加」提示，由 `NSTextView` 更新）
    @State private var isImageDragHovering = false

    /// 是否允许输入/发送（必须先选中会话）
    private var canChat: Bool {
        WindowConversationVM.selectedConversationId != nil
    }

    private var activeInputQueueVM: WindowInputQueueVM {
        windowScope?.inputQueueVM ?? inputQueueVM
    }

    var body: some View {
        VStack(spacing: 8) {
            // 编辑器 - 使用动态高度
            macEditorView
                .frame(height: editorHeight)
                .padding(.horizontal, 4)
                .padding(.top, 8)
                .padding(.bottom, 8)
                .allowsHitTesting(canChat)
                .opacity(canChat ? 1 : 0.6)
                .accessibilityLabel(String(localized: "Message Input", table: "AgentChat"))
                .accessibilityHint(String(localized: "Message Input Hint", table: "AgentChat"))
        }
        .background(themeVM.activeAppTheme.workspaceBackgroundColor())
        .overlay(RoundedRectangle(cornerRadius: 0)
            .stroke(themeVM.activeAppTheme.workspaceTertiaryTextColor().opacity(0.1), lineWidth: 1))
        .overlay {
            if !canChat {
                noConversationOverlay
            }
        }
        .shadow(color: themeVM.activeAppTheme.workspaceTertiaryTextColor().opacity(0.08), radius: 8, x: 0, y: 4)
        .overlay(alignment: .bottomLeading) {
            commandSuggestionOverlay
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(String(localized: "Input Area", table: "AgentChat"))
    }
}

// MARK: - View

extension InputAreaView {
    /// 无会话时的遮罩层
    private var noConversationOverlay: some View {
        let theme = themeVM.activeAppTheme
        return ZStack {
            // 半透明背景，盖住输入区域，防止误操作
            RoundedRectangle(cornerRadius: 12)
                .fill(theme.workspaceBackgroundColor().opacity(0.9))

            VStack(spacing: 8) {
                Image(systemName: "bubble.left.and.bubble.right")
                    .font(.system(size: 18))
                    .foregroundStyle(theme.workspaceTertiaryTextColor())

                Text(String(localized: "Please create or select a conversation first", table: "AgentChat"))
                    .font(.subheadline)
                    .foregroundStyle(theme.workspaceSecondaryTextColor())
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }
            .padding(.horizontal, 16)
        }
    }

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

extension InputAreaView {
    /// 编辑器视图（提取以避免类型检查超时）
    private var macEditorView: some View {
        MacEditorView(
            text: $chatDraftVM.text,
            height: $editorHeight,
            textColor: NSColor(themeVM.activeAppTheme.workspaceTextColor()),
            onSubmit: handleSubmit,
            onArrowUp: handleArrowUp,
            onArrowDown: handleArrowDown,
            onEnter: handleEnter,
            isFocused: $isInputFocused,
            cursorPosition: $chatDraftVM.cursorPosition,
            isImageDragHovering: $isImageDragHovering
        )
        // 添加高度变化动画
        .animation(.easeInOut(duration: 0.15), value: editorHeight)
        // 监听文本变化以触发命令建议
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

                Text(String(localized: "Release to add image to chat", table: "AgentChat"))
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

extension InputAreaView {
    /// 提交输入
    private func handleSubmit() {
        guard canChat else { return }
        let text = chatDraftVM.text
        chatDraftVM.clear()
        activeInputQueueVM.enqueueText(text)
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
            chatDraftVM.set(suggestion.command + " ")
            commandSuggestionViewModel.setIsVisible(false)
        } else {
            // 发送消息
            let text = chatDraftVM.text
            chatDraftVM.clear()
            activeInputQueueVM.enqueueText(text)
            // 发送后重置高度
            editorHeight = MacEditorView.minHeight
        }
    }
}

// MARK: - Preview
