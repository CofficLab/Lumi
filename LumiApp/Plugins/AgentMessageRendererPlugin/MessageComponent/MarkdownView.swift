import SwiftUI
import MagicKit
import MarkdownKit

/// Markdown 消息视图，负责渲染聊天消息内容
struct MarkdownView: View {
    let message: ChatMessage
    let showRawMessage: Bool
    
    private var renderMetadata: MessageRenderMetadata {
        MessageRenderCache.shared.metadata(for: message)
    }

    var body: some View {
        Group {
            if showRawMessage {
                rawMessageContent
            } else {
                nativeMarkdownContent
            }
        }
    }

    /// 原始消息内容：preferOuterScroll 时用 Text 避免内部 ScrollView 吸住滚轮
    private var rawMessageContent: some View {
        PlainTextMessageContentView(content: message.content, monospaced: true)
    }

    private var nativeMarkdownContent: some View {
        MarkdownContent(
            content: message.content
        )
        .id("native-\(message.id.uuidString)-\(renderMetadata.contentHash)")
    }
}
