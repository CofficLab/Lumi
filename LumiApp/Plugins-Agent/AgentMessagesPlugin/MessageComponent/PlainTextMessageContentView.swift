import SwiftUI

/// 纯文本消息内容视图（不解析 Markdown）
struct PlainTextMessageContentView: View {
    let content: String
    let monospaced: Bool
    @Environment(\.preferOuterScroll) private var preferOuterScroll
    @Environment(\.chatListIsActivelyScrolling) private var chatListIsActivelyScrolling

    var body: some View {
        Group {
            if preferOuterScroll {
                Text(verbatim: content)
                    .font(.system(.body, design: monospaced ? .monospaced : .default))
                    .chatTextSelection(active: !chatListIsActivelyScrolling)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                TextEditor(text: .constant(content))
                    .font(.system(.body, design: monospaced ? .monospaced : .default))
                    .chatTextSelection(active: !chatListIsActivelyScrolling)
                    .scrollContentBackground(.hidden)
            }
        }
    }
}
