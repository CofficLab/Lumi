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
    ///
    /// - Important: `NSFont` 的度量访问**不是线程安全的**。
    ///   这里用锁串行化：`static let` 的惰性初始化可能发生在任意线程，
    ///   与并发的其它字体读取竞争时，AppKit 可能返回一个**降级字体**，
    ///   于是同一进程内两次读到的行高不同（实测出现过 16.49 与 12.0）。
    ///
    ///   - Note: 锁必须覆盖「取字体 → 读度量 → 算结果」整段，
    ///     只保护写入是不够的。
    static let lineSpacing: CGFloat = {
        fontMetricsLock.lock()
        defer { fontMetricsLock.unlock() }
        let font = NSFont.systemFont(ofSize: fontSize)
        let fontLineHeight = font.ascender - font.descender + font.leading
        return max(0, targetLineHeight - fontLineHeight)
    }()

    /// 保护字体度量的读取。
    private static let fontMetricsLock = NSLock()

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

    /// 轮尾操作栏的**常驻占位**高度。
    ///
    /// - Important: 操作栏必须**常驻占位**，只在不显示时把透明度降为 0。
    ///   若用条件插入，操作栏一出现整行就长高 32pt，下一轮内容被顶下去 ——
    ///   这正是「hover 一下底下就跳」的直接原因。
    ///
    ///   基准：ZCode 原型 `ConversationTurnGroup.tsx` 的
    ///   `opacity-0 transition-opacity group-hover/assistant-turn:opacity-100`
    ///   —— 元素始终在布局里占位，只改透明度。
    static let actionBarSlotHeight: CGFloat = 32

    /// 操作栏淡入 / 淡出时长（秒）。
    static let actionBarFadeDuration: TimeInterval = 0.15

    /// 操作栏是否应该**预留常驻占位**。
    ///
    /// - Important: 只有「轮尾助手正文」「本轮已完成」「确实有可显示内容」
    ///   三者同时成立时才占位。
    ///
    ///   - 占位条件里**不含 hover**：占位一旦与 hover 绑定，
    ///     hover 就会改变行高，正是要消除的跳动。
    ///   - `isRunning` 为真时不占位：流式期间正文还在增长，
    ///     尾部留 32pt 空白比「流式结束时多出一行操作栏」更突兀；
    ///     而流式轮与历史轮是**不同的 turn**，完成时的行高变化不是 hover 引起的。
    static func shouldReserveActionBarSlot(context: MessageTurnPresentationContext?) -> Bool {
        guard let context else { return false }
        guard context.isTailAssistantText, !context.isRunning else { return false }
        return !context.assistantCopyText.isEmpty || context.completedAt != nil
    }

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
                // Important: 标识符必须挂在**外层容器**上，不能挂在
                //   `MarkdownBlockRenderer` 上 —— 后者会渲染多个 block，
                //   修饰符被每个 block 继承，于是 AX 树里出现 N 个同名元素，
                //   UI 测试按 firstMatch 命中哪一个全靠运气。
                // Important: 标识符挂在**外层**容器上，且用
                //   `.accessibilityElement(children: .contain)`。
                //   若把标识符挂在 `MarkdownBlockRenderer` 上，修饰符会向下
                //   传播到每一个 Markdown block，AX 树里就会出现 N 个同名元素；
                //   若挂在 VStack 上而不加 `contain`，SwiftUI 会把整个子树
                //   合并成**一个** AX 元素，内部元素反而全部消失。
                VStack(alignment: .leading, spacing: 0) {
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
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier(ZCodeRendererAccessibilityIdentifiers.assistantBody)
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

    /// 轮尾操作栏。
    ///
    /// - Important: **常驻占位**，只在不显示时把透明度降为 0。
    ///
    ///   之前这里是条件插入（`if shouldShowActionBar { ... }`），
    ///   操作栏一出现就多出 32pt，下一轮内容被顶下去 —— 这正是
    ///   「hover 一下底下就跳」的根因。
    ///
    ///   现在改为：占位与否只看「轮尾 + 已完成 + 有内容」（与 hover 无关），
    ///   hover 只切换透明度。行高因此恒定，hover 不再引起任何位移。
    ///
    ///   基准：ZCode 原型 `ConversationTurnGroup.tsx` 的
    ///   `opacity-0 transition-opacity group-hover/assistant-turn:opacity-100`。
    @ViewBuilder
    private var actionBar: some View {
        if ZCodeAssistantTextStyle.shouldReserveActionBarSlot(context: turnContext) {
            HStack(spacing: 8) {
                if let copyText = turnContext?.assistantCopyText,
                   ZCodeAssistantTextStyle.shouldShowCopyButton(copyText: copyText) {
                    copyButton(text: copyText)
                }
                if let label = timeLabel {
                    Text(label)
                        .font(.system(size: ZCodeAssistantTextStyle.timeLabelFontSize))
                        .foregroundColor(palette.subtlest)
                        .accessibilityIdentifier(ZCodeRendererAccessibilityIdentifiers.turnTimeLabel)
                }
            }
            .padding(.top, 8)
            // Important: 透明时**不能**用 `hidden()` / `removeFromTree` ——
            //   那会把按钮从 AX 树里摘掉，键盘用户与 UI 测试都拿不到。
            //   正确做法是保留在树上、只改透明度。
            .frame(minHeight: ZCodeAssistantTextStyle.actionBarSlotHeight - 8, alignment: .leading)
            .opacity(isActionBarVisible ? 1 : 0)
            .animation(
                .easeOut(duration: ZCodeAssistantTextStyle.actionBarFadeDuration),
                value: isActionBarVisible
            )
            // Important: 操作栏**容器**不能挂 `accessibilityIdentifier`。
            //   SwiftUI 会把标识符向下传播给子元素，于是 `turn-copy`
            //   与 `turn-time` 都被覆盖成 `turn-action-bar`，
            //   UI 测试再也定位不到具体的按钮与时间。
            //
            //   「这一轮有操作栏」的可观测证据因此改由**子元素**表达：
            //   每个 turn 恰好一个 `turn-copy` 按钮 + 一个 `turn-time` 标签。
            //   这比「容器计数」更贴近语义 —— 操作栏的意义就是那个复制按钮。
        }
    }

    /// 操作栏当前是否可见（占位已在 `actionBar` 里处理）。
    private var isActionBarVisible: Bool {
        ZCodeAssistantTextStyle.shouldShowActionBar(context: turnContext, isHovered: isTurnHovered)
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
        .accessibilityIdentifier(ZCodeRendererAccessibilityIdentifiers.turnCopyButton)
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
