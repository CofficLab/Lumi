import SwiftUI

/// 纯文本消息内容视图（不解析 Markdown）
struct PlainTextMessageContentView: View {
    let content: String
    let monospaced: Bool
    @Environment(\.preferOuterScroll) private var preferOuterScroll

    var body: some View {
        Group {
            if preferOuterScroll {
                Text(verbatim: content)
                    .font(monospaced ? DesignTokens.Typography.code : DesignTokens.Typography.body)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                TextEditor(text: .constant(content))
                    .font(monospaced ? DesignTokens.Typography.code : DesignTokens.Typography.body)
                    .textSelection(.enabled)
                    .scrollContentBackground(.hidden)
            }
        }
    }
}
