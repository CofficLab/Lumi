import Foundation
import ProviderMessage
import SwiftUI
import Testing

@testable import PluginLLMContext

/// 上下文弹窗布局回归测试。
///
/// 防止 GeometryReader 膨胀、弹出层超出屏幕等布局问题再次出现。
/// 使用 `ImageRenderer.proposedSize` 提供建议空间（而非强制 frame），
/// 让视图按自身约束决定实际渲染尺寸。
@MainActor
struct ContextPopoverLayoutTests {

    // MARK: - Helpers

    /// 渲染视图并返回输出图像的像素尺寸。
    ///
    /// `proposedSize` 是父视图提供的建议空间。
    /// 与 `.frame(width:height:)` 不同，`proposedSize` 不会强制视图撑满，
    /// 视图可以根据内部 `.frame(maxHeight:)` 等约束自行决定实际大小。
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

    /// 生成带多条压缩事件的预览历史，用于测试内容撑高场景。
    private func historyWithManyCompactions() -> ContextUsageHistory {
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let samples = (0..<10).map { i in
            ContextUsageSample(
                id: UUID(),
                index: i,
                date: base.addingTimeInterval(Double(i) * 600),
                tokens: 20_000 + i * 5_000,
                isEstimated: false
            )
        }
        let markers = (0..<7).map { i in
            ContextUsageCompactionMarker(
                id: UUID(),
                date: base.addingTimeInterval(Double(i) * 1_200 + 300),
                afterSampleIndex: i + 1,
                reason: .hardThreshold
            )
        }
        return ContextUsageHistory(samples: samples, compactionMarkers: markers)
    }

    private func previewCompactionEvents(count: Int) -> [Message] {
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        return (0..<count).map { i in
            Message.previewContextCompaction(createdAt: base.addingTimeInterval(Double(i) * 1_200))
        }
    }

    // MARK: - 趋势图高度约束

    @Test("趋势图在宽松空间下不应超过图表高度",
          .timeLimit(.minutes(1)))
    func trendViewHeightIsConstrained() {
        let history = historyWithManyCompactions()
        let view = ContextUsageTrendView(history: history)

        // 模拟弹出层给趋势图一个很大的可用空间。
        let size = renderedSize(view, proposedSize: CGSize(width: 340, height: 600))

        // 图表本身固定 118，加上标题与统计行仍应远小于 600。
        #expect(size.height <= 260, "趋势图高度 \(size.height) 超出预期上限 260")
    }

    @Test("趋势图在极小空间下仍能渲染",
          .timeLimit(.minutes(1)))
    func trendViewRendersInTightSpace() {
        let history = historyWithManyCompactions()
        let view = ContextUsageTrendView(history: history)

        let size = renderedSize(view, proposedSize: CGSize(width: 200, height: 118))
        #expect(size.height > 0)
        #expect(size.width > 0)
    }

    /// 请求数极多时趋势图不应膨胀：数据超出视口后改为横向滚动，
    /// 高度始终由图表固定。
    @Test("请求数极多时趋势图高度不变",
          .timeLimit(.minutes(1)))
    func trendViewHeightStaysStableWithManySamples() {
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        let samples = (0..<500).map { i in
            ContextUsageSample(
                id: UUID(),
                index: i,
                date: base.addingTimeInterval(Double(i) * 60),
                tokens: 20_000 + i * 1_000,
                isEstimated: false
            )
        }
        let history = ContextUsageHistory(samples: samples, compactionMarkers: [])

        let size = renderedSize(
            ContextUsageTrendView(history: history),
            proposedSize: CGSize(width: 340, height: 600)
        )

        #expect(size.height <= 260, "500 个采样点时趋势图高度 \(size.height) 异常增大")
    }

    // MARK: - ContextPopover 最大高度约束

    @Test("ContextPopover 在内容很多时不应超出最大高度",
          .timeLimit(.minutes(1)))
    func popoverHeightIsConstrainedWithManyEvents() {
        let usage = ContextWindowUsageSnapshot(
            contextWindowTokens: 1_000_000,
            effectiveContextWindowTokens: 1_000_000,
            inputTokenLimit: 861_000,
            estimatedInputTokens: 546_000,
            usesFallbackWindow: false
        )
        let history = historyWithManyCompactions()
        let events = previewCompactionEvents(count: 7)

        let popover = ContextPopover(usage: usage, history: history, events: events)

        // 给弹出层一个远超其最大高度的容器。
        let size = renderedSize(popover, proposedSize: CGSize(width: 360, height: 1_200))

        // maxHeight: 520 约束下，渲染高度不应超过 530（含像素取整余量）。
        // 如果没有约束，7 条压缩事件 + 图表会让高度远超 1000。
        #expect(size.height <= 530, "弹出层高度 \(size.height) 超出 maxHeight: 520，可能缺少最大高度约束")
    }

    @Test("ContextPopover 在内容很少时不超过最大高度",
          .timeLimit(.minutes(1)))
    func popoverHeightRespectsMaxHeightWithMinimalContent() {
        let usage = ContextWindowUsageSnapshot(
            contextWindowTokens: 128_000,
            effectiveContextWindowTokens: 128_000,
            inputTokenLimit: 112_000,
            estimatedInputTokens: 41_500,
            usesFallbackWindow: false
        )

        let popover = ContextPopover(usage: usage, history: .empty, events: [])
        let size = renderedSize(popover, proposedSize: CGSize(width: 360, height: 800))

        // 内容少时高度由内容决定，但也不应超过 maxHeight。
        #expect(size.height <= 530)
    }

    @Test("ContextPopover 无压缩事件时只显示窗口信息和趋势",
          .timeLimit(.minutes(1)))
    func popoverWithoutCompactionEvents() {
        let usage = ContextWindowUsageSnapshot(
            contextWindowTokens: 128_000,
            effectiveContextWindowTokens: 128_000,
            inputTokenLimit: 112_000,
            estimatedInputTokens: 41_500,
            usesFallbackWindow: false
        )

        let popover = ContextPopover(usage: usage, history: .preview, events: [])
        let size = renderedSize(popover, proposedSize: CGSize(width: 360, height: 800))

        #expect(size.height > 100, "弹出层高度 \(size.height) 异常偏小，可能缺少内容")
        #expect(size.height <= 530)
    }
}
