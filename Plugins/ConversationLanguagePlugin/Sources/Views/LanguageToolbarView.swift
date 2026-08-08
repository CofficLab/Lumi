import LumiKernel
import LumiUI
import SwiftUI

struct LanguageToolbarView: View {
    let kernel: LumiKernel

    @State private var selectedLanguage: LumiConversationLanguage = .chinese
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    @State private var isPopoverPresented = false

    private var conversations: (any ConversationManaging)? {
        kernel.conversations
    }

    /// 当前是否有选中对话
    private var hasSelectedConversation: Bool {
        conversations?.selectedConversationID != nil
    }

    private var foregroundColor: Color {
        selectedLanguage.foregroundColor
    }

    private var backgroundColor: Color {
        selectedLanguage.backgroundColor
    }

    var body: some View {
        Button {
            isPopoverPresented.toggle()
        } label: {
            HStack(spacing: ToolbarMetrics.chipSpacing) {
                Image(systemName: selectedLanguage.toolbarIconName)
                    .font(.system(size: ToolbarMetrics.chipIconSize, weight: .medium))
                Text(selectedLanguage.shortCode)
                    .font(.system(size: ToolbarMetrics.chipTextSize, weight: ToolbarMetrics.chipTextWeight))
            }
            .foregroundColor(foregroundColor)
            .padding(.horizontal, ToolbarMetrics.chipHorizontalPadding)
            .padding(.vertical, ToolbarMetrics.chipVerticalPadding)
            .background(backgroundColor, in: RoundedRectangle(cornerRadius: ToolbarMetrics.chipCornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .help(selectedLanguage.helpText)
        .popover(isPresented: $isPopoverPresented, arrowEdge: .bottom) {
            LanguagePopover(
                selectedLanguage: selectedLanguage,
                isConversationScope: hasSelectedConversation
            ) { language in
                updateLanguage(language)
                isPopoverPresented = false
            }
        }
        .task { refreshLanguage() }
        .onLumiSelectedConversationDidChange { refreshLanguage() }
    }

    // MARK: - Actions

    /// 根据是否有选中对话，写入对话级别或全局语言偏好
    private func updateLanguage(_ language: LumiConversationLanguage) {
        guard let conversations else { return }
        if let conversationID = conversations.selectedConversationID {
            // 有选中对话：同步到该对话的语言偏好
            conversations.setLanguage(language, for: conversationID)
            // 同时更新全局语言偏好，使后续新建对话继承此设置
            conversations.setGlobalLanguage(language)
        } else {
            // 无选中对话：直接修改全局语言偏好
            conversations.setGlobalLanguage(language)
        }
        selectedLanguage = language
    }

    /// 刷新显示值：有对话时读取对话的语言偏好，否则读取全局语言偏好
    private func refreshLanguage() {
        guard let conversations else {
            selectedLanguage = .chinese
            return
        }
        if let conversationID = conversations.selectedConversationID {
            selectedLanguage = conversations.language(for: conversationID)
        } else {
            selectedLanguage = conversations.globalLanguage
        }
    }
}
