import CoreGraphics
import Foundation
import KitMarkdown
import LumiLocalizationKit
import LumiUI
import ProviderConversation
import ProviderMessage
import SwiftUI

/// V5（ChatGPT）未知消息类型的 Markdown 兜底。
///
/// 基准是 V5 方案第 2 节路由矩阵：
/// - `default` / 未知 `renderKind` 落到**无旧 chrome 的 Markdown 兜底**；
/// - 不画头像、名称、旧 header 或诊断条；
/// - 空正文显示轻量空态，不留下无意义的大块留白。
struct ChatGPTDefaultMessageView: View {
    @LumiTheme private var theme

    let message: Message
    let verbosity: ResponseVerbosity

    /// 正文是否含可见字符。
    private var hasVisibleContent: Bool {
        message.content.contains { !$0.isWhitespace && !$0.isNewline }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if hasVisibleContent {
                MarkdownBlockRenderer(
                    markdown: message.content,
                    theme: ChatMarkdownTheme.makeChatGPT(from: theme)
                )
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
                .font(.system(size: ChatGPTAssistantTextStyle.fontSize))
                .lineSpacing(ChatGPTAssistantTextStyle.lineSpacing)
            } else {
                HStack(spacing: 6) {
                    Image(systemName: "text.bubble")
                        .font(.system(size: 12))
                        .foregroundColor(theme.textTertiary)
                    Text(pluginLocalization.string("(empty message)"))
                        .font(.appCaption)
                        .foregroundColor(theme.textSecondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
