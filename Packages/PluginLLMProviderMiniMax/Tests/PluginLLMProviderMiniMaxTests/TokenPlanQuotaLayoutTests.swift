import Foundation
import SwiftUI
import Testing
@testable import PluginLLMProviderMiniMax

/// 配额面板的布局回归测试。
///
/// 详情面板原先是「逐字段键值表」，时间戳等长文本会撑破 360pt 的弹层宽度；
/// 改版后改为双列卡片，需要守住两条约束：
/// - 内容不横向溢出弹层宽度；
/// - 常见数据量（2 个模型）在弹层内排得下，不需要滚动。
@MainActor
@Suite("配额面板布局")
struct TokenPlanQuotaLayoutTests {

    // MARK: - Helpers

    /// 渲染视图并返回输出图像的像素尺寸。
    ///
    /// `proposedSize` 是父视图提供的建议空间；用 `proposedSize` 而非
    /// `.frame(width:height:)`，让视图按自身约束决定实际渲染尺寸。
    private func renderedSize<V: View>(
        _ view: V,
        proposedSize: CGSize
    ) -> CGSize {
        let renderer = ImageRenderer(content: view)
        renderer.proposedSize = ProposedViewSize(proposedSize)
        renderer.scale = 1
        guard let cgImage = renderer.cgImage else {
            return .zero
        }
        return CGSize(width: cgImage.width, height: cgImage.height)
    }

    /// 弹层内的内容宽度：弹层宽度减去左右内边距。
    private var contentWidth: CGFloat {
        TokenPlanToolbarMetrics.popoverWidth - 28
    }

    // MARK: - 列表

    @Test("两个模型的配额列表不横向溢出", .timeLimit(.minutes(1)))
    func quotaListDoesNotOverflowWidth() {
        let list = TokenPlanQuotaList(plans: TokenPlanPreviewFixtures.allPlans)

        let size = renderedSize(list, proposedSize: CGSize(width: contentWidth, height: 600))

        #expect(size.width > 0, "配额列表没有渲染出内容")
        #expect(
            size.width <= contentWidth + 1,
            "配额列表宽度 \(size.width) 超出内容宽度 \(contentWidth)，卡片可能溢出"
        )
    }

    @Test("两个模型的配额列表在弹层内排得下", .timeLimit(.minutes(1)))
    func quotaListFitsWithoutScrolling() {
        let list = TokenPlanQuotaList(plans: TokenPlanPreviewFixtures.allPlans)

        let size = renderedSize(list, proposedSize: CGSize(width: contentWidth, height: 600))

        // 面板滚动区上限 440pt；两个模型应远小于该值，否则用户每次都要滚动。
        #expect(
            size.height <= 320,
            "配额列表高度 \(size.height) 超过预期上限 320，弹层内排不下"
        )
    }

    @Test("模型数量增加时列表仍能渲染", .timeLimit(.minutes(1)))
    func quotaListRendersWithManyModels() {
        let plans = (0..<8).map { _ in
            TokenPlanData(
                modelName: "general",
                remainingPercent: 50,
                intervalStatus: 1,
                intervalTotal: 100,
                intervalUsage: 50,
                startTime: 0,
                endTime: 0,
                remainsTime: 0,
                weeklyRemainingPercent: 50,
                weeklyStatus: 1,
                weeklyTotal: 100,
                weeklyUsage: 50,
                weeklyStartTime: 0,
                weeklyEndTime: 0,
                weeklyRemainsTime: 0
            )
        }

        let list = TokenPlanQuotaList(plans: plans)

        let size = renderedSize(list, proposedSize: CGSize(width: contentWidth, height: 600))

        #expect(size.height > 0)
        #expect(size.width <= contentWidth + 1)
    }

    // MARK: - 卡片

    @Test("配额卡片高度紧凑", .timeLimit(.minutes(1)))
    func quotaCardStaysCompact() {
        let card = TokenPlanQuotaCard(
            title: "5-Hour Window",
            headline: "68",
            unit: .percent,
            tint: .green,
            statusText: "Normal",
            isNormal: true,
            progressRatio: 0.68,
            timeRangeText: "10/19 17:26 → 22:26",
            usageText: "Used 19 / 100",
            resetText: "Resets in 2 hours"
        )

        let size = renderedSize(card, proposedSize: CGSize(width: 191, height: 400))

        #expect(size.width > 0)
        #expect(
            size.height <= 140,
            "配额卡片高度 \(size.height) 超过预期上限 140，卡片过于厚重"
        )
    }
}
