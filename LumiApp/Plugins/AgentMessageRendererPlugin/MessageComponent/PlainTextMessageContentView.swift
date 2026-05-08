import SwiftUI
import MagicKit
import MarkdownKit

/// 纯文本消息内容视图（不解析 Markdown）
struct PlainTextMessageContentView: View {
    let content: String
    let monospaced: Bool
    @Environment(\.preferOuterScroll) private var preferOuterScroll

    var body: some View {
        Group {
            if preferOuterScroll {
                Text(verbatim: content)
                    .font(monospaced ? .system(size: 13, weight: .regular, design: .monospaced) : .system(size: 15, weight: .regular))
                    .foregroundColor(Color.adaptive(light: "1C1C1E", dark: "FFFFFF"))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                TextEditor(text: .constant(content))
                    .font(monospaced ? .system(size: 13, weight: .regular, design: .monospaced) : .system(size: 15, weight: .regular))
                    .foregroundColor(Color.adaptive(light: "1C1C1E", dark: "FFFFFF"))
                    .textSelection(.enabled)
                    .scrollContentBackground(.hidden)
            }
        }
    }
}
