import LumiCoreKit
import LumiCoreKit
import SwiftUI

/// 语言切换按钮：每个对话保存独立语言偏好。
struct LanguageToggleButton: View {
    @ObservedObject var chatService: ChatService

    @State private var isPopoverPresented = false

    private var selectedConversationID: UUID? {
        chatService.selectedConversationID
    }

    private var currentLanguage: LumiConversationLanguage {
        chatService.language(for: selectedConversationID)
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
                chatService.setLanguage(language, for: selectedConversationID)
                isPopoverPresented = false
            }
        }
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
