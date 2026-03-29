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
    let isCollapsible: Bool
    let isExpanded: Bool
    let onToggleExpand: () -> Void
    private var renderMetadata: MessageRenderMetadata {
        MessageRenderCache.shared.metadata(for: message)
    }

    /// 最大高度（超过后折叠）
    private let maxHeight: CGFloat = 400
    var body: some View {
        Group {
            if showRawMessage {
                rawMessageContent
            } else {
                nativeMarkdownContent
            }
        }
        .applyCollapsible(isCollapsible: isCollapsible, isExpanded: isExpanded, maxHeight: maxHeight)
        .overlay(alignment: .bottom) {
            // 折叠时显示渐变遮罩和展开按钮
            if isCollapsible && !isExpanded && contentNeedsCollapse {
                VStack {
                    Spacer()
                    // 展开按钮区域 - 横跨整个消息宽度
                    ExpandButtonBar(action: onToggleExpand)
                        .padding(.top, 60)
                        .padding(.horizontal, -10)  // 抵消父视图的 padding
                        .padding(.bottom, -10)
                }
            }
        }
    }
    
    /// 判断内容是否需要折叠（通过测量内容高度）
    private var contentNeedsCollapse: Bool {
        let estimatedHeight = CGFloat(renderMetadata.lineCount * 20)
        return estimatedHeight > maxHeight
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

// MARK: - Expand Button Bar

/// 展开按钮条 - 横跨整个消息底部的背景条
struct ExpandButtonBar: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Spacer()
                HStack(spacing: 6) {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                    Text("展开")
                        .font(DesignTokens.Typography.caption1)
                }
                .foregroundColor(DesignTokens.Color.semantic.textPrimary)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                Spacer()
            }
            .background(
                DesignTokens.Color.semantic.info.opacity(0.8)
                    .overlay(
                        Rectangle()
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [
                                        Color.clear,
                                        DesignTokens.Color.semantic.info.opacity(0.8)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    )
            )
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(DesignTokens.Color.semantic.info.opacity(0.8))
                    .frame(height: 1)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - View Modifier

extension View {
    @ViewBuilder
    func applyCollapsible(isCollapsible: Bool, isExpanded: Bool, maxHeight: CGFloat) -> some View {
        if isCollapsible && !isExpanded {
            self
                .lineLimit(20)
                .frame(maxHeight: maxHeight)
                .clipped()
        } else {
            self
        }
    }
}
