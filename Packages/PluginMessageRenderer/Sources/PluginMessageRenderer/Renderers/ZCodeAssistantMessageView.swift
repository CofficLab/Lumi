import AppKit
import CoreGraphics
import Foundation
import KitMarkdown
import LumiLocalizationKit
import LumiUI
import ProviderConversation
import ProviderMessage
import ProviderMessageRendering
import SwiftUI

/// V4（ZCode）助手正文的排版与呈现规格。
///
/// 基准是 ZCode 3.15.1 计划第 2.3 节：
/// - 无气泡、无卡片背景、无头像、无名称，占满内容列；
/// - 正文 14，目标行高 `14 × 1.75 = 24.5`，tracking `0.025em ≈ 0.35`，strong 字重 500；
/// - SwiftUI 的 `.lineSpacing` 是「额外间距」，不能把 24.5 直接传入；
///   必须用实际 `NSFont` 行高计算 `max(0, 24.5 - font.lineHeight)`。
enum ZCodeAssistantTextStyle {

    // MARK: - 排版

    /// 正文字号。
    static let fontSize: CGFloat = 14

    /// 字间距（tracking）。
    static let tracking: CGFloat = 0.35

    /// 目标行高。
    static let targetLineHeight: CGFloat = 24.5

    /// strong 字重。
    static let strongWeight: CGFloat = 500

    /// 连续 reasoning / tool 等工作项之间的间距。
    static let workItemSpacing: CGFloat = 16

    /// 实际行距（额外间距）。
    ///
    /// - Important: SwiftUI 的 `.lineSpacing` 是「额外间距」，
    ///   所以必须由目标行高减去字体自身的行高得到。
    static let lineSpacing: CGFloat = {
        let font = NSFont.systemFont(ofSize: fontSize)
        let fontLineHeight = font.ascender - font.descender + font.leading
        return max(0, targetLineHeight - fontLineHeight)
    }()

    // MARK: - 呈现形态

    /// 助手正文**没有**气泡。
    static let hasBubble = false

    /// 助手正文**没有**头像。
    static let hasAvatar = false

    /// 助手正文**没有**发送者名称。
    static let hasSenderName = false

    /// 正文占满内容列。
    static let fillsContentColumn = true

    // MARK: - 流式

    /// 流式正文**没有** cursor。
    static let hasStreamingCursor = false

    /// 流式正文**没有**淡入。
    static let hasStreamingFadeIn = false

    /// 流式正文**没有** `animate-pulse`。
    static let hasStreamingPulse = false

    // MARK: - 轮尾操作栏

    /// 时间标签字号。
    static let timeLabelFontSize: CGFloat = 12

    /// 操作栏是否应该显示。
    ///
    /// - Important: 必须**同时**满足「是轮尾助手正文」「本轮已完成」「处于 hover」。
    static func shouldShowActionBar(
        isTailAssistantText: Bool,
        isRunning: Bool,
        isHovered: Bool
    ) -> Bool {
        isTailAssistantText && !isRunning && isHovered
    }

    /// 按 context 判断操作栏是否应该显示。
    ///
    /// - Important: context 为 nil（V1–V3）时**永远不显示**。
    static func shouldShowActionBar(
        context: MessageTurnPresentationContext?,
        isHovered: Bool
    ) -> Bool {
        guard let context else { return false }
        return shouldShowActionBar(
            isTailAssistantText: context.isTailAssistantText,
            isRunning: context.isRunning,
            isHovered: isHovered
        )
    }

    /// 复制文本为空时不显示复制按钮。
    static func shouldShowCopyButton(copyText: String) -> Bool {
        !copyText.isEmpty
    }

    /// 轮尾完成时间；context 为 nil 时没有。
    static func completedAt(context: MessageTurnPresentationContext?) -> Date? {
        context?.completedAt
    }

    /// 是否使用 V4 呈现。
    ///
    /// - Important: 必须**精确匹配** `.zcode`。
    ///   若写成 `verbosity >= .standard` 之类的比较，`.zcode` 会被误当作
    ///   `.standard` 处理，导致 V4 走旧 chrome。
    static func usesZCodePresentation(verbosity: ResponseVerbosity) -> Bool {
        verbosity == .zcode
    }
}

/// V4（ZCode）助手正文视图。
///
/// 与 V1–V3 的差异：
/// - 无气泡、无卡片背景、无头像、无名称，占满内容列；
/// - 不显示旧 header、info popover、模型名或每行操作；
/// - 轮尾操作栏（整轮复制 + 时间）只挂在轮尾助手正文上，
///   且需要整个 turn 处于 hover 才显示。
///
/// - Important: 复用真实复制能力，不新增 fake retry / like / fork。
struct ZCodeAssistantMessageView: View {
    let capability: any MessageRendererCapability
    @ObservedObject var stateViewModel: MessageRendererStateViewModel
    let message: Message
    let verbosity: ResponseVerbosity

    @Environment(\.messageTurnPresentation) private var turnContext
    @Environment(\.messageTurnIsHovered) private var isTurnHovered
    @Environment(\.colorScheme) private var colorScheme

    /// 复制反馈状态。
    @State private var copyState = ZCodeCopyFeedbackState()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let reasoning, ZCodeReasoningStyle.shouldRender(text: reasoning, isStreaming: isRunning) {
                ZCodeReasoningView(
                    text: reasoning,
                    isStreaming: isRunning,
                    durationMilliseconds: message.streamingDurationMs.map { Int($0) }
                )
                .padding(.bottom, ZCodeAssistantTextStyle.workItemSpacing)
            }

            if hasVisibleContent {
                MarkdownBlockRenderer(
                    markdown: message.content,
                    theme: ChatMarkdownTheme.makeZCode(from: theme)
                )
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
                .font(.system(size: ZCodeAssistantTextStyle.fontSize))
                .tracking(ZCodeAssistantTextStyle.tracking)
                .lineSpacing(ZCodeAssistantTextStyle.lineSpacing)
            }

            if let toolCalls = message.toolCalls, !toolCalls.isEmpty {
                Group {
                    if ZCodeToolWorkHistoryStyle.shouldGroup(tools: toolCalls) {
                        // 两个及以上连续 Explore/Execute 才形成父分组。
                        ZCodeToolWorkHistoryView(
                            capability: capability,
                            stateViewModel: stateViewModel,
                            message: message,
                            verbosity: verbosity,
                            toolCalls: toolCalls
                        )
                    } else {
                        // 单工具或非分组家族：保持独立工具行。
                        ToolCallRowsView(
                            capability: capability,
                            stateViewModel: stateViewModel,
                            message: message,
                            verbosity: verbosity,
                            allowsCustomToolRenderers: true,
                            originalVerbosity: verbosity
                        )
                    }
                }
                .padding(.top, hasVisibleContent ? ZCodeAssistantTextStyle.workItemSpacing : 0)
            }

            actionBar
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// reasoning 正文。
    private var reasoning: String? {
        guard let content = message.reasoningContent,
              !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else { return nil }
        return content
    }

    /// 本轮是否仍在运行中。
    private var isRunning: Bool {
        turnContext?.isRunning ?? false
    }

    // MARK: - 轮尾操作栏

    @ViewBuilder
    private var actionBar: some View {
        if ZCodeAssistantTextStyle.shouldShowActionBar(context: turnContext, isHovered: isTurnHovered) {
            HStack(spacing: 8) {
                if let copyText = turnContext?.assistantCopyText,
                   ZCodeAssistantTextStyle.shouldShowCopyButton(copyText: copyText) {
                    copyButton(text: copyText)
                }
                if let label = timeLabel {
                    Text(label)
                        .font(.system(size: ZCodeAssistantTextStyle.timeLabelFontSize))
                        .foregroundColor(palette.subtlest)
                }
            }
            .padding(.top, 8)
        }
    }

    private func copyButton(text: String) -> some View {
        Button {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
            copyState.markCopied()
        } label: {
            Image(systemName: copyState.isCopied ? "checkmark" : "doc.on.doc")
                .font(.system(size: ZCodeUserBubbleStyle.copyButtonIconSize))
                .foregroundColor(copyState.isCopied ? palette.foreground : palette.subtle)
                .frame(width: ZCodeUserBubbleStyle.copyButtonSize, height: ZCodeUserBubbleStyle.copyButtonSize)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(pluginLocalization.string("Copy"))
    }

    /// 轮尾时间标签；无效或缺失时为 nil（不显示）。
    private var timeLabel: String? {
        guard let completedAt = ZCodeAssistantTextStyle.completedAt(context: turnContext) else { return nil }
        return ZCodeMessageTimeLabel.format(
            timestamp: completedAt.timeIntervalSince1970,
            now: Date(),
            calendar: .current,
            locale: .current
        )
    }

    // MARK: - 私有

    @LumiTheme private var theme

    private var palette: ZCodeMessageAppearance.Palette {
        ZCodeMessageAppearance.palette(for: colorScheme)
    }

    /// 内容是否含可见字符。
    private var hasVisibleContent: Bool {
        message.content.contains { !$0.isWhitespace && !$0.isNewline }
    }
}
