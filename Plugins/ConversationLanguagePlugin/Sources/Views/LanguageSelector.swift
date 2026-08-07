import LumiKernel
import SwiftUI

/// 语言切换按钮：每个对话保存独立语言偏好。
struct LanguageToggleButton: View {
    let kernel: LumiKernel

    // language 随当前会话切换变化。用事件 + @State 缓存，不挂 kernel 全局总线。
    @State private var selectedConversationID: UUID?
    @State private var currentLanguage: LumiConversationLanguage = .chinese

    @State private var isPopoverPresented = false

    private var conversations: (any ConversationManaging)? {
        kernel.conversations
    }

    var body: some View {
        Button {
            isPopoverPresented.toggle()
        } label: {
            HStack(spacing: ToolbarMetrics.chipSpacing) {
                Image(systemName: currentLanguage.toolbarIconName)
                    .font(.system(size: ToolbarMetrics.chipIconSize, weight: ToolbarMetrics.iconWeight))
                Text(currentLanguage.shortCode)
                    .font(.system(size: ToolbarMetrics.chipTextSize, weight: ToolbarMetrics.chipTextWeight))
            }
            .foregroundColor(foregroundColor)
            .padding(.horizontal, ToolbarMetrics.chipHorizontalPadding)
            .padding(.vertical, ToolbarMetrics.chipVerticalPadding)
            .background(backgroundColor, in: RoundedRectangle(cornerRadius: ToolbarMetrics.chipCornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .help(helpText)
        .accessibilityLabel(LumiPluginLocalization.string("Language Selector", bundle: .module))
        .popover(isPresented: $isPopoverPresented, arrowEdge: .bottom) {
            LanguagePopover(selectedLanguage: currentLanguage) { language in
                conversations?.setLanguage(language, for: selectedConversationID)
                currentLanguage = language
                isPopoverPresented = false
            }
        }
        .task { refreshState() }
        .onLumiSelectedConversationDidChange { refreshState() }
    }

    private func refreshState() {
        let id = conversations?.selectedConversationID
        selectedConversationID = id
        currentLanguage = conversations?.language(for: id) ?? .chinese
    }

    private var foregroundColor: Color {
        switch currentLanguage {
        case .chinese:
            return .blue
        case .english:
            return .purple
        }
    }

    private var backgroundColor: Color {
        foregroundColor.opacity(0.12)
    }

    private var helpText: String {
        switch currentLanguage {
        case .chinese:
            return LumiPluginLocalization.string("Current Chinese Help", bundle: .module)
        case .english:
            return LumiPluginLocalization.string("Current English Help", bundle: .module)
        }
    }
}
