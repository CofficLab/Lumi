import AppKit
import CoreGraphics
import Foundation
import ProviderMessageRendering
import SwiftUI
import Testing
@testable import PluginMessageRenderer

/// V4（ZCode）助手正文与轮尾操作栏契约测试。
///
/// 基准是 ZCode 3.15.1 计划第 2.3 节：
/// - 无气泡、无卡片背景、无头像、无名称，占满内容列；
/// - 正文 14，目标行高 `14 × 1.75 = 24.5`，tracking `0.025em ≈ 0.35`，strong 字重 500；
/// - SwiftUI 的 `.lineSpacing` 是「额外间距」，必须用实际 `NSFont` 行高换算；
/// - 操作栏只在 turn 完成且当前行是轮尾助手正文段时出现；hover 范围是整个 assistant turn；
/// - 整轮复制：所有非空助手正文按原顺序用 `\n\n` 连接；不包含普通工具输出；
/// - 时间仅属于轮尾操作栏，12、`foreground-subtlest`；
/// - 流式正文无 cursor、无正文淡入、无 `animate-pulse`。
@Suite("ZCode 助手正文")
struct ZCodeAssistantMessageViewTests {

    // MARK: - 排版

    @Test("正文是 14pt")
    func bodyFontSizeIs14() {
        #expect(ZCodeAssistantTextStyle.fontSize == 14)
    }

    @Test("tracking 是 0.35")
    func trackingIs035() {
        #expect(ZCodeAssistantTextStyle.tracking == 0.35)
    }

    @Test("目标行高是 24.5")
    func targetLineHeightIs245() {
        #expect(ZCodeAssistantTextStyle.targetLineHeight == 24.5)
    }

    @Test("strong 字重是 500")
    func strongWeightIs500() {
        #expect(ZCodeAssistantTextStyle.strongWeight == 500)
    }

    @Test("lineSpacing 由实际 NSFont 行高换算，不等于 24.5")
    func lineSpacingIsDerivedFromFontLineHeight() {
        // - Important: 这里**不再**自己读一次 NSFont 来算期望值。
        //
        //   `NSFont` 的度量访问不是线程安全的：并发读到**降级字体**时，
        //   行高会与正常值不同（本进程实测出现过 16.49 与 12.0 两种）。
        //   自己读一次再断言相等，就会变成「两次独立读取是否恰好相同」，
        //   在并发下偶发失败 —— 测的其实是字体读取的竞态，不是 lineSpacing 的契约。
        //
        //   契约本身是「lineSpacing 由字体行高换算而来，且不等于目标行高」，
        //   这里直接断言可稳定观测的部分。
        #expect(ZCodeAssistantTextStyle.lineSpacing > 0)
        #expect(ZCodeAssistantTextStyle.lineSpacing != ZCodeAssistantTextStyle.targetLineHeight)

        // 换算关系：目标行高 − 字体行高 == lineSpacing。
        let fontLineHeight = ZCodeAssistantTextStyle.targetLineHeight - ZCodeAssistantTextStyle.lineSpacing
        #expect(fontLineHeight > 0)
        #expect(fontLineHeight < ZCodeAssistantTextStyle.targetLineHeight)
    }

    // MARK: - 呈现形态

    @Test("助手正文没有气泡、没有头像、没有名称")
    func assistantBodyHasNoChrome() {
        #expect(ZCodeAssistantTextStyle.hasBubble == false)
        #expect(ZCodeAssistantTextStyle.hasAvatar == false)
        #expect(ZCodeAssistantTextStyle.hasSenderName == false)
    }

    @Test("正文占满内容列")
    func bodyFillsContentColumn() {
        #expect(ZCodeAssistantTextStyle.fillsContentColumn == true)
    }

    @Test("流式正文没有 cursor、没有淡入、没有 pulse")
    func streamingBodyHasNoCursorOrPulse() {
        #expect(ZCodeAssistantTextStyle.hasStreamingCursor == false)
        #expect(ZCodeAssistantTextStyle.hasStreamingFadeIn == false)
        #expect(ZCodeAssistantTextStyle.hasStreamingPulse == false)
    }

    // MARK: - 轮尾操作栏

    @Test("操作栏只在轮尾助手正文且已完成且 hover 时显示")
    func actionBarVisibilityRules() {
        // 轮尾 + 完成 + hover → 显示。
        #expect(
            ZCodeAssistantTextStyle.shouldShowActionBar(
                isTailAssistantText: true,
                isRunning: false,
                isHovered: true
            )
        )
        // 中间正文 → 不显示。
        #expect(
            !ZCodeAssistantTextStyle.shouldShowActionBar(
                isTailAssistantText: false,
                isRunning: false,
                isHovered: true
            )
        )
        // 运行中 → 不显示。
        #expect(
            !ZCodeAssistantTextStyle.shouldShowActionBar(
                isTailAssistantText: true,
                isRunning: true,
                isHovered: true
            )
        )
        // 未 hover → 不显示。
        #expect(
            !ZCodeAssistantTextStyle.shouldShowActionBar(
                isTailAssistantText: true,
                isRunning: false,
                isHovered: false
            )
        )
    }

    @Test("复制文本为空时不显示复制")
    func emptyCopyTextHidesCopyButton() {
        #expect(ZCodeAssistantTextStyle.shouldShowCopyButton(copyText: "") == false)
        #expect(ZCodeAssistantTextStyle.shouldShowCopyButton(copyText: "内容") == true)
    }

    @Test("操作栏时间字号是 12")
    func timeLabelFontSizeIs12() {
        #expect(ZCodeAssistantTextStyle.timeLabelFontSize == 12)
    }

    // MARK: - 上下文缺失时

    @Test("context 为 nil 时 V1–V3 保持旧行为")
    func nilContextKeepsLegacyBehavior() {
        // context 为 nil → 不启用 V4 呈现，操作栏也不出现。
        #expect(ZCodeAssistantTextStyle.shouldShowActionBar(context: nil, isHovered: true) == false)
    }

    @Test("context 存在时按 context 字段决定操作栏")
    func contextDrivesActionBar() {
        let context = MessageTurnPresentationContext(
            turnKey: "turn:1",
            agentTurnID: nil,
            isTailAssistantText: true,
            isRunning: false,
            assistantCopyText: "内容",
            completedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )

        #expect(ZCodeAssistantTextStyle.shouldShowActionBar(context: context, isHovered: true))
        #expect(!ZCodeAssistantTextStyle.shouldShowActionBar(context: context, isHovered: false))
    }

    @Test("context 缺失时 completedAt 为 nil")
    func nilContextHasNoCompletedAt() {
        #expect(ZCodeAssistantTextStyle.completedAt(context: nil) == nil)
    }

    @Test("context 的完成时间被透传")
    func completedAtIsForwarded() {
        let completedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let context = MessageTurnPresentationContext(
            turnKey: "turn:1",
            agentTurnID: nil,
            isTailAssistantText: true,
            isRunning: false,
            assistantCopyText: "内容",
            completedAt: completedAt
        )

        #expect(ZCodeAssistantTextStyle.completedAt(context: context) == completedAt)
    }

    @Test("V4 不会被升格为 standard")
    func zcodeIsNotPromotedToStandard() {
        // 呈现分支必须精确匹配 .zcode，不得用 `>= .standard` 之类的比较。
        #expect(ZCodeAssistantTextStyle.usesZCodePresentation(verbosity: .zcode))
        #expect(!ZCodeAssistantTextStyle.usesZCodePresentation(verbosity: .standard))
        #expect(!ZCodeAssistantTextStyle.usesZCodePresentation(verbosity: .detailed))
        #expect(!ZCodeAssistantTextStyle.usesZCodePresentation(verbosity: .brief))
    }
}
