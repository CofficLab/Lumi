import CoreGraphics
import Foundation
import LumiLocalizationKit
import LumiUI
import ProviderConversation
import ProviderMessage
import ProviderMessageRendering
import SwiftUI

/// V5（ChatGPT）助手正文的排版与呈现规格。
///
/// 基准是 V5 方案第 2.2 / 2.5 节：
/// - 无气泡、无头像、无「AI/ChatGPT」名称、无默认模型名与时间戳；
/// - 正文占满阅读列（最大 768），目标行高 24；
/// - 轮尾操作只挂在轮尾助手正文上，且整轮只出现一次；
/// - 成功回复**不**显示「重新生成」，只有真实可重试的失败回合才显示重试。
///
/// - Important: 所有判定都必须是**纯函数**，以便单元测试直接覆盖，
///   不依赖渲染时机与 hover 状态。
enum ChatGPTAssistantTextStyle {

    // MARK: - 排版

    /// 正文字号。
    static let fontSize: CGFloat = 15

    /// 目标行高。
    static let targetLineHeight: CGFloat = 24

    /// 实际行距（额外间距）。
    ///
    /// - Important: SwiftUI 的 `.lineSpacing` 是「额外间距」，
    ///   不能把目标行高直接传进去；必须减去字体自身的行高。
    ///
    /// - Important: `NSFont` 的度量访问**不是线程安全的**。
    ///   `static let` 的惰性初始化可能发生在任意线程，
    ///   与并发的其它字体读取竞争时 AppKit 可能返回一个**降级字体**，
    ///   于是同一进程内两次读到的行高不同。这里用锁串行化，
    ///   且锁必须覆盖「取字体 → 读度量 → 算结果」整段。
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

    /// 助手正文**没有**默认模型名与时间戳。
    static let showsDefaultTimestamp = false

    /// 正文占满内容列。
    static let fillsContentColumn = true

    /// 连续 reasoning / tool 等工作项之间的间距。
    static let workItemSpacing: CGFloat = 12

    // MARK: - 流式

    /// 流式正文**没有** cursor。
    static let hasStreamingCursor = false

    /// 流式正文**没有**淡入。
    static let hasStreamingFadeIn = false

    /// 流式正文**没有** `animate-pulse`。
    static let hasStreamingPulse = false

    // MARK: - 轮尾操作栏

    /// 操作栏的**常驻占位**高度。
    ///
    /// - Important: 操作栏必须**常驻占位**，只在不显示时把透明度降为 0。
    ///   若用条件插入，操作栏一出现整行就长高，下一轮内容被顶下去 ——
    ///   这正是「hover 一下底下就跳」的直接原因。
    static let actionBarSlotHeight: CGFloat = 32

    /// 操作按钮尺寸。
    static let actionButtonSize: CGFloat = 28

    /// 操作栏淡入 / 淡出时长（秒）。
    static let actionBarFadeDuration: TimeInterval = 0.15

    /// 复制成功反馈的持续时长（秒）。
    static let copyFeedbackDuration: TimeInterval = 1.2

    /// 操作栏是否应该**预留常驻占位**。
    ///
    /// - Important: 占位条件里**不含 hover**：占位一旦与 hover 绑定，
    ///   hover 就会改变行高，正是要消除的跳动。
    /// - `isRunning` 为真时不占位：流式期间正文还在增长，
    ///   尾部留 32pt 空白比「流式结束时多出一行操作栏」更突兀。
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
    /// - Important: context 为 nil（V1–V4）时**永远不显示**。
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

    // MARK: - 重试

    /// 该错误消息的回合当前是否真的可重试。
    ///
    /// - Important: 成功回复**绝不**显示重试或「重新生成」。
    ///   重试只出现在带有效 `turnID` 且 AgentLoop 仍停留在该失败回合上时。
    @MainActor
    static func retryableTurnID(
        message: Message,
        capability: (any MessageRendererCapability)?
    ) -> UUID? {
        guard message.isError else { return nil }
        guard let turnID = message.turnID,
              capability?.canRetryTurn(turnID: turnID, conversationID: message.conversationID) == true
        else { return nil }
        return turnID
    }

    // MARK: - 分发

    /// 是否使用 V5 呈现。
    ///
    /// - Important: 必须**精确匹配** `.chatGPT`。
    ///   若写成 `verbosity >= .standard` 之类的比较，`.chatGPT` 会被误当作
    ///   `.standard` 处理，导致 V5 走旧 chrome。
    static func usesChatGPTPresentation(verbosity: ResponseVerbosity) -> Bool {
        verbosity == .chatGPT
    }
}
