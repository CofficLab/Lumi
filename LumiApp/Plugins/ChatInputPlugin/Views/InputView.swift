import AppKit
import SwiftUI
import MagicAlert
import MagicKit

/// Agent 输入包装视图 - 管理输入区域所需的状态
///
/// 模式切换、模型选择器、发送控制和附件已拆分为独立插件。
/// 本视图仅管理输入编辑器相关状态。
struct InputView: View, SuperLog {
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

    /// 插件管理器，用于聚合输入区浮层。
    @EnvironmentObject private var pluginProvider: AppPluginVM

    /// 命令建议 ViewModel
    @EnvironmentObject var commandSuggestionViewModel: WindowCommandSuggestionVM

    /// 窗口级聊天草稿
    @EnvironmentObject private var chatDraftVM: WindowChatDraftVM

    /// 输入框是否处于聚焦状态
    @State private var isInputFocused: Bool = false

    /// 编辑器动态高度
    @State private var editorHeight: CGFloat = MacEditorView.minHeight

    /// 图片文件正拖过输入框（显示「松开可添加」提示，由 `NSTextView` 更新）
    @State private var isImageDragHovering = false

    /// 是否允许输入/发送（必须先选中会话）
    @EnvironmentObject private var conversationVM: WindowConversationVM

    private var canChat: Bool {
        conversationVM.selectedConversationId != nil
    }

    private var activeInputQueueVM: WindowInputQueueVM {
        windowScope?.inputQueueVM ?? inputQueueVM
    }

    var body: some View {
        VStack(spacing: 8) {
            macEditorView
                .frame(height: editorHeight)
                .padding(.horizontal, 4)
                .padding(.top, 8)
                .padding(.bottom, 8)
                .allowsHitTesting(canChat)
                .opacity(canChat ? 1 : 0.6)
                .accessibilityLabel(String(localized: "Message Input", table: "ChatInputPlugin"))
                .accessibilityHint(String(localized: "Message Input Hint", table: "ChatInputPlugin"))
        }
        .background(themeVM.activeAppTheme.workspaceBackgroundColor())
        .overlay(RoundedRectangle(cornerRadius: 0)
            .stroke(themeVM.activeAppTheme.workspaceTertiaryTextColor().opacity(0.1), lineWidth: 1))
        .overlay {
            ForEach(Array(pluginProvider.getChatInputOverlayViews().enumerated()), id: \.offset) { _, view in
                view
            }
        }
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
        guard canChat else { return }
        let text = chatDraftVM.text
        chatDraftVM.clear()
        activeInputQueueVM.enqueueText(text)
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
        guard canChat else {
            if Self.verbose {
                ChatInputPlugin.logger.info("\(Self.t)回车提交被拦截：当前没有选中的会话")
            }
            alert_info(
                String(localized: "Please create or select a conversation first", table: "ChatInputPlugin"),
                subtitle: String(localized: "No active conversation", table: "ChatInputPlugin")
            )
            return
        }

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
            chatDraftVM.clear()
            activeInputQueueVM.enqueueText(text)
            editorHeight = MacEditorView.minHeight
        }
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
