import LumiLocalizationKit
import LumiUI
import ProviderMessage
import SwiftUI

/// 消息正文里的折叠内容块（粘贴的大段文本、编辑器选区等）。
///
/// 输入框把大段内容渲染成一行内联 chip，但发给上层的正文是**拍平后的完整
/// 文本**。折叠区间随消息一起存在 metadata 里，本组件据此把那一段还原成
/// 可点击展开的 chip——与输入框里看到的形态一致，而不是摊开成一长串文字。
struct CollapsedContentChips: View {
    @LumiTheme private var theme

    /// 正文（拍平后的完整文本）。
    let text: String
    /// 折叠区间。已由调用方按正文长度归一化。
    let blocks: [CollapsedContentBlock]
    /// 该折叠段是否已展开为正文。
    @State private var expandedBlocks: Set<Int> = []

    var body: some View {
        // 区间已归一化：无折叠块时直接渲染纯文本，走与旧消息完全一致的路径。
        guard !blocks.isEmpty else {
            return AnyView(CollapsiblePlainText(text: text))
        }

        return AnyView(
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                    switch segment {
                    case let .plain(value):
                        Text(value)
                            .font(.appBody)
                            .foregroundColor(theme.textPrimary)
                            .lineSpacing(3)
                            .textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                    case let .collapsed(block):
                        CollapsedContentChip(
                            title: block.title,
                            systemImage: block.systemImage ?? Self.defaultSymbolName,
                            isExpanded: expandedBlocks.contains(block.start),
                            content: collapsedText(for: block)
                        ) {
                            toggle(block)
                        }
                    }
                }
            }
        )
    }

    /// 正文按折叠区间切出的片段序列（普通文本与折叠块交替）。
    private enum Segment {
        case plain(String)
        case collapsed(CollapsedContentBlock)
    }

    private var segments: [Segment] {
        var result: [Segment] = []
        var cursor = text.startIndex

        var consumed = 0
        for block in blocks {
            // 区间已归一化，这里仍做一次防御：正文被外部改动过也不能越界崩溃。
            guard block.start >= consumed,
                  let start = text.index(text.startIndex, offsetBy: block.start, limitedBy: text.endIndex),
                  let end = text.index(start, offsetBy: block.length, limitedBy: text.endIndex),
                  start >= cursor else {
                continue
            }

            let plain = String(text[cursor..<start])
            if !plain.isEmpty {
                result.append(.plain(plain))
            }
            result.append(.collapsed(block))
            cursor = end
            consumed = block.start + block.length
        }

        let tail = String(text[cursor...])
        if !tail.isEmpty {
            result.append(.plain(tail))
        }
        return result
    }

    /// 折叠段在正文中的原始文本。
    private func collapsedText(for block: CollapsedContentBlock) -> String {
        let start = text.index(text.startIndex, offsetBy: block.start, limitedBy: text.endIndex)
            ?? text.endIndex
        let end = text.index(start, offsetBy: block.length, limitedBy: text.endIndex)
            ?? text.endIndex
        return String(text[start..<end])
    }

    private func toggle(_ block: CollapsedContentBlock) {
        if expandedBlocks.contains(block.start) {
            expandedBlocks.remove(block.start)
        } else {
            expandedBlocks.insert(block.start)
        }
    }

    private static let defaultSymbolName = "doc.on.clipboard"
}

/// 单个折叠块 chip：点击在「一行摘要」与「完整原文」之间切换。
private struct CollapsedContentChip: View {
    @LumiTheme private var theme

    let title: String
    let systemImage: String
    let isExpanded: Bool
    let content: String
    let onToggle: () -> Void

    /// 标题与统计信息。
    ///
    /// metadata 里存的是一个拼好的标题串（「粘贴的文本 · 13,253 字 · 75 行」），
    /// 这里按分隔符拆开，好让「这是什么」与「有多大」分成两层排版——与输入框
    /// 里的 chip 一致。
    private var parts: (label: String, detail: String?) {
        CollapsedContentChipStyle.split(title: title)
    }

    var body: some View {
        Button(action: onToggle) {
            if isExpanded {
                VStack(alignment: .leading, spacing: 6) {
                    header
                    Text(content)
                        .font(.system(size: 12))
                        .foregroundColor(theme.textSecondary)
                        .lineSpacing(2)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: CollapsedContentChipStyle.cornerRadius, style: .continuous)
                        .fill(theme.textPrimary.opacity(0.05))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: CollapsedContentChipStyle.cornerRadius, style: .continuous)
                        .strokeBorder(theme.textPrimary.opacity(0.10), lineWidth: 1)
                )
            } else {
                HStack(spacing: CollapsedContentChipStyle.iconSpacing) {
                    Image(systemName: systemImage)
                        .font(.system(size: CollapsedContentChipStyle.iconSize, weight: .medium))
                        .foregroundColor(theme.textSecondary)

                    // 标题与统计信息分层：标题用正文色，统计信息小一号用次级色。
                    Text(parts.label)
                        .font(.system(size: CollapsedContentChipStyle.titleSize, weight: .medium))
                        .foregroundColor(theme.textPrimary)
                        .lineLimit(1)

                    if let detail = parts.detail {
                        Text(detail)
                            .font(.system(size: CollapsedContentChipStyle.detailSize))
                            .foregroundColor(theme.textTertiary)
                            .lineLimit(1)
                    }
                }
                .padding(.horizontal, CollapsedContentChipStyle.horizontalPadding)
                .padding(.vertical, CollapsedContentChipStyle.standaloneVerticalPadding)
                .background(
                    RoundedRectangle(cornerRadius: CollapsedContentChipStyle.cornerRadius, style: .continuous)
                        .fill(theme.textPrimary.opacity(CollapsedContentChipStyle.fillOpacity))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: CollapsedContentChipStyle.cornerRadius, style: .continuous)
                        .strokeBorder(theme.textPrimary.opacity(CollapsedContentChipStyle.strokeOpacity), lineWidth: 1)
                )
            }
        }
        .buttonStyle(.plain)
    }

    private var header: some View {
        HStack(spacing: CollapsedContentChipStyle.iconSpacing) {
            Image(systemName: systemImage)
                .font(.system(size: CollapsedContentChipStyle.iconSize, weight: .medium))
                .foregroundColor(theme.textSecondary)
            Text(parts.label)
                .font(.system(size: CollapsedContentChipStyle.titleSize, weight: .medium))
                .foregroundColor(theme.textPrimary)
                .lineLimit(1)
            if let detail = parts.detail {
                Text(detail)
                    .font(.system(size: CollapsedContentChipStyle.detailSize))
                    .foregroundColor(theme.textTertiary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            Text(pluginLocalization.string("Show less"))
                .font(.system(size: 10))
                .foregroundColor(theme.textTertiary)
        }
    }
}