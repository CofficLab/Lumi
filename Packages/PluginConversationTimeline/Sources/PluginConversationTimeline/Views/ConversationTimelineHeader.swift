import SwiftUI

/// 对话时间线标题栏
public struct ConversationTimelineHeader: View {
    public let itemCount: Int
    public let currentContextTokens: Int
    public let contextLimit: Int
    public let onRefresh: () -> Void
    private let timelineService = ConversationTimelineService()

    public var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(String(localized: "对话时间线", table: "ConversationTimeline"))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color.adaptive(light: "1C1C1E", dark: "FFFFFF"))

                HStack(spacing: 12) {
                    Text(String(format: String(localized: "%lld messages", table: "ConversationTimeline"), itemCount))
                        .font(.system(size: 11))
                        .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))

                    // 当前上下文 Token 数
                    if currentContextTokens > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "chart.bar.xaxis")
                                .font(.system(size: 9))
                            let currentText = timelineService.formatToken(currentContextTokens)
                            if contextLimit > 0 {
                                let limitText = timelineService.formatToken(contextLimit)
                                Text(String(format: String(localized: "Context %@/%@", table: "ConversationTimeline"), currentText, limitText))
                                    .font(.system(size: 11))
                            } else {
                                Text(String(format: String(localized: "Context %@", table: "ConversationTimeline"), currentText))
                                    .font(.system(size: 11))
                            }
                        }
                        .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
                    }
                }
            }

            Spacer()

            // 刷新按钮
            Button(action: onRefresh) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 12))
                    .foregroundColor(Color.adaptive(light: "6B6B7B", dark: "EBEBF5"))
            }
            .buttonStyle(.plain)
            .help(String(localized: "刷新", table: "ConversationTimeline"))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .overlay(alignment: .bottom) {
            Divider()
                .padding(.leading, 16)
        }
    }
}
