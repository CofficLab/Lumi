import SwiftUI
import MarkdownUI
import OSLog
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
/// 使用 MarkdownUI 库渲染（支持 GitHub Flavored Markdown）
struct MarkdownMessageView: View, SuperLog {
    nonisolated static let emoji = "📝"
    nonisolated static let verbose = true
    static private var renderMarkdownEnabled: Bool = true

    let message: ChatMessage
    let showRawMessage: Bool
    let isCollapsible: Bool
    let isExpanded: Bool
    let onToggleExpand: () -> Void
    @Environment(\.preferOuterScroll) private var preferOuterScroll

    /// 最大高度（超过后折叠）
    private let maxHeight: CGFloat = 400

    var body: some View {
        Group {
            if showRawMessage {
                rawMessageContent
                    .applyCollapsible(isCollapsible: isCollapsible, isExpanded: isExpanded, maxHeight: maxHeight)
            } else if !Self.renderMarkdownEnabled {
                Text(verbatim: message.content)
                    .font(.system(.body, design: .default))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .applyCollapsible(isCollapsible: isCollapsible, isExpanded: isExpanded, maxHeight: maxHeight)
            } else {
                markdownContent
                    .applyCollapsible(isCollapsible: isCollapsible, isExpanded: isExpanded, maxHeight: maxHeight)
            }
        }
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
        // 简单判断：通过字符数估算
        // 更精确的方式需要使用 GeometryReader 测量实际高度
        let estimatedLines = message.content.components(separatedBy: "\n").count
        let estimatedHeight = CGFloat(estimatedLines * 20) // 每行约 20pt
        return estimatedHeight > maxHeight
    }

    /// 原始消息内容：preferOuterScroll 时用 Text 避免内部 ScrollView 吸住滚轮
    private var rawMessageContent: some View {
        Group {
            if preferOuterScroll {
                Text(verbatim: message.content)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                TextEditor(text: .constant(message.content))
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .scrollContentBackground(.hidden)
            }
        }
    }

    /// Markdown 内容：preferOuterScroll 时禁用内部滚动，让外层列表滚动
    @ViewBuilder
    private var markdownContent: some View {
        if preferOuterScroll {
            Markdown(message.content)
                .textSelection(.enabled)
                .scrollDisabled(true)
        } else {
            Markdown(message.content)
                .textSelection(.enabled)
        }
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
                        .font(.system(size: 12, weight: .semibold))
                    Text("展开")
                        .font(.system(size: 13, weight: .medium))
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

// MARK: - Expand Button

/// 展开按钮（独立按钮，不使用条状背景）
struct ExpandButton: View {
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                Text("展开")
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundColor(DesignTokens.Color.semantic.textPrimary)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(DesignTokens.Color.semantic.info.opacity(0.15))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(DesignTokens.Color.semantic.info.opacity(0.3), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
            )
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
