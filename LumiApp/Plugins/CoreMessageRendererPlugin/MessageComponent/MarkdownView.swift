import SwiftUI
import MagicKit

// MARK: - Environment: 禁用消息内部滚动（由外层列表统一滚动，避免长消息“吸住”滚轮）

private struct PreferOuterScrollKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// 为 true 时（如 AppKit 消息列表）：消息内不使用可滚动控件，由外层列表统一滚动，避免长 MD 消息“吸住”滚轮。
    var preferOuterScroll: Bool {
        get { self[PreferOuterScrollKey.self] }
        set { self[PreferOuterScrollKey.self] = newValue }
    }
}

/// Markdown 消息视图，负责渲染聊天消息内容
/// 使用内置原生渲染（基于 swift-markdown AST）
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
        NativeMarkdownContent(
            content: message.content
        )
        .id("native-\(message.id.uuidString)-\(renderMetadata.contentHash)")
    }
}
