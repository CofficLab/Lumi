import MagicKit
import SwiftUI

/// 对话时间线标题栏
struct ConversationTimelineHeader: View {
    let itemCount: Int
    let currentContextTokens: Int
    let contextLimit: Int
    let onRefresh: () -> Void
    private let timelineService = ConversationTimelineService()

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("对话时间线")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color.adaptive(light: "1C1C1E", dark: "FFFFFF"))

                HStack(spacing: 12) {
                    Text("\(itemCount) 条消息")
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
                                Text("上下文 \(currentText)/\(limitText)")
                                    .font(.system(size: 11))
                            } else {
                                Text("上下文 \(currentText)")
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
            .help("刷新")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .overlay(alignment: .bottom) {
            Divider()
                .padding(.leading, 16)
        }
    }
}
