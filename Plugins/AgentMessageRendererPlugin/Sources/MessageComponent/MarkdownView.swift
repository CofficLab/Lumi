import SwiftUI
import LumiCoreKit
import MarkdownKit

/// Markdown 消息视图，负责渲染聊天消息内容
public struct MarkdownView: View {
    public let message: ChatMessage
    public let showRawMessage: Bool
    
    public var body: some View {
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
    }
}
