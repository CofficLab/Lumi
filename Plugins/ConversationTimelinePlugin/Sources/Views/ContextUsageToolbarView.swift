import LumiCoreKit
import LumiCoreKit
import LumiUI
import SwiftUI

struct ContextUsageToolbarView: View {
    @LumiTheme private var theme
    @ObservedObject private var chatService: ChatService

    init(chatService: any LumiChatServicing) {
        guard let chatService = chatService as? ChatService else {
            preconditionFailure("ContextUsageToolbarView requires ChatService")
        }
        _chatService = ObservedObject(wrappedValue: chatService)
    }

    var body: some View {
        let conversationID = chatService.selectedConversationID
        let contextUsage = conversationID.map { chatService.conversationContextUsage(for: $0) }

        if let contextUsage, contextUsage.currentTokens > 0 {
            HStack(spacing: ToolbarMetrics.chipSpacing) {
                Image(systemName: "chart.bar.xaxis")
                    .font(.system(size: ToolbarMetrics.chipIconSize, weight: ToolbarMetrics.iconWeight))

                Text(contextUsage.label)
                    .font(.system(size: ToolbarMetrics.chipTextSize, weight: ToolbarMetrics.chipTextWeight))
                    .monospacedDigit()
            }
            .foregroundColor(foregroundColor(for: contextUsage))
            .padding(.horizontal, ToolbarMetrics.chipHorizontalPadding)
            .padding(.vertical, ToolbarMetrics.chipVerticalPadding)
            .background(
                foregroundColor(for: contextUsage).opacity(0.12),
                in: RoundedRectangle(cornerRadius: ToolbarMetrics.chipCornerRadius, style: .continuous)
            )
            .help(helpText(for: contextUsage))
        }
    }

    private func foregroundColor(for usage: LumiConversationContextUsage) -> Color {
        guard usage.limit > 0 else { return theme.textSecondary }

        let ratio = Double(usage.currentTokens) / Double(usage.limit)
        switch ratio {
        case 0.85...:
            return .red
        case 0.65...:
            return .orange
        default:
            return theme.info
        }
    }

    private func helpText(for usage: LumiConversationContextUsage) -> String {
        if usage.limit > 0 {
            return String(
                format: LumiPluginLocalization.string("Context %@/%@", bundle: .module),
                LumiConversationContextUsage.formatToken(usage.currentTokens),
                LumiConversationContextUsage.formatToken(usage.limit)
            )
        }
        return String(
            format: LumiPluginLocalization.string("Context %@", bundle: .module),
            LumiConversationContextUsage.formatToken(usage.currentTokens)
        )
    }
}
