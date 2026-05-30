import SwiftUI
import MarkdownKit
import LumiUI

/// 纯文本消息内容视图（不解析 Markdown）
public struct PlainTextMessageContentView: View {
    @LumiUI.LumiTheme private var theme: any LumiUITheme

    public let content: String
    public let monospaced: Bool
    @Environment(\.preferOuterScroll) private var preferOuterScroll

    public var body: some View {
        Group {
            if preferOuterScroll {
                Text(verbatim: content)
                    .font(monospaced ? .appMonoCaption : .appBody)
                    .foregroundColor(theme.textPrimary)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                TextEditor(text: .constant(content))
                    .font(monospaced ? .appMonoCaption : .appBody)
                    .foregroundColor(theme.textPrimary)
                    .textSelection(.enabled)
                    .scrollContentBackground(.hidden)
            }
        }
    }
}
