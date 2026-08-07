import LumiKernel
import SwiftUI

/// 语言切换按钮：每个对话保存独立语言偏好。
struct LanguageToggleButton: View {
    let kernel: LumiKernel

    // 只订阅 conversations 这一个 service：本视图不挂在 kernel 全局总线上，
    // project/workspace/settings 等无关服务变更不会触发这里刷新。
    @StateObject private var box = ObservableConversationsBox()

    @State private var isPopoverPresented = false

    private var conversations: (any ConversationManaging)? {
        box.service
    }

    private var selectedConversationID: UUID? {
        conversations?.selectedConversationID
    }

    private var currentLanguage: LumiConversationLanguage {
        conversations?.language(for: selectedConversationID) ?? .chinese
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
                isPopoverPresented = false
            }
        }
        .task { box.bind(kernel.conversations) }
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
