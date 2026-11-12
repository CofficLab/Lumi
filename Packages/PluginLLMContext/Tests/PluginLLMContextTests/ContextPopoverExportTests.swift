#if os(macOS)
import Foundation
import ProviderMessage
import SwiftUI
import Testing

@testable import PluginLLMContext

/// 上下文弹窗「导出为图片」的回归测试。
///
/// ## 为什么需要这组测试
///
/// 导出走的是 `ImageRenderer`，它与屏幕渲染有一处关键差异：
///
/// **弹窗的 `maxHeight: 520` 若作用到导出内容上，超出的部分会被裁掉**——
/// 压缩历史时间线就会只剩视口内那几条。这类缺陷不会报错，只会静默地
/// 导出一张残缺的图，因此断言必须落在**实际像素尺寸**上。
///
/// 另一个容易踩的坑：`ImageRenderer` 会把 `ScrollView` 展开到完整内容高度，
/// 所以导出内容**不需要**去掉滚动容器——真正会裁掉内容的是高度约束。
@MainActor
struct ContextPopoverExportTests {
    // MARK: - Helpers

    private func usage(
        contextWindow: Int = 1_000_000,
        inputLimit: Int = 861_000,
        estimatedInput: Int = 546_000
    ) -> ContextWindowUsageSnapshot {
        ContextWindowUsageSnapshot(
            contextWindowTokens: contextWindow,
            effectiveContextWindowTokens: contextWindow,
            inputTokenLimit: inputLimit,
            estimatedInputTokens: estimatedInput,
            usesFallbackWindow: false
        )
    }

    private func previewCompactionEvents(count: Int) -> [Message] {
        let base = Date(timeIntervalSince1970: 1_700_000_000)
        return (0..<count).map { i in
            Message.previewContextCompaction(createdAt: base.addingTimeInterval(Double(i) * 1_200))
        }
    }

    private func history() -> ContextUsageHistory {
        .preview
    }

    /// 渲染导出内容并返回像素尺寸。
    private func exportedSize(popover: ContextPopover) -> CGSize {
        guard let image = ContextPopoverImageExporter.render(content: popover.exportContent) else {
            return .zero
        }
        return CGSize(width: image.width, height: image.height)
    }

    // MARK: - 导出内容完整性

    @Test("导出图片的高度不被弹窗的最大高度约束裁剪",
          .timeLimit(.minutes(1)))
    func exportHeightIsNotClampedByPopoverMaxHeight() {
        // 20 条压缩历史远超弹窗的 maxHeight: 520。
        let events = previewCompactionEvents(count: 20)
        let popover = ContextPopover(
            usage: usage(),
            history: history(),
            events: events
        )

        let size = exportedSize(popover: popover)

        // 导出倍率是 2，因此像素高度 = 逻辑高度 × 2。
        // 弹窗限制 520 逻辑像素（约 1040 设备像素）。
        // 完整渲染 20 条历史必然超过这个高度；若没有超过，说明时间线被裁掉了。
        #expect(
            size.height > 1_040,
            "导出高度 \(size.height) 仍受 maxHeight: 520 限制，压缩历史被裁剪"
        )
    }

    @Test("导出图片包含完整的压缩时间线，不止可视区域",
          .timeLimit(.minutes(1)))
    func exportRendersFullCompactionTimeline() {
        // 两条历史在弹窗可视区内，20 条在可视区外。
        let fewEvents = previewCompactionEvents(count: 2)
        let manyEvents = previewCompactionEvents(count: 20)

        let fewSize = exportedSize(popover: ContextPopover(
            usage: usage(),
            history: history(),
            events: fewEvents
        ))
        let manySize = exportedSize(popover: ContextPopover(
            usage: usage(),
            history: history(),
            events: manyEvents
        ))

        // 多出 18 条历史，导出图必须明显更高。
        #expect(
            manySize.height > fewSize.height,
            "增加压缩历史后导出高度没有变化（\(fewSize.height) → \(manySize.height)），时间线可能被截断"
        )
    }

    @Test("导出图片宽度与弹窗一致", .timeLimit(.minutes(1)))
    func exportWidthMatchesPopoverWidth() {
        let popover = ContextPopover(
            usage: usage(),
            history: history(),
            events: previewCompactionEvents(count: 3)
        )

        let size = exportedSize(popover: popover)

        // 弹窗宽度 360，导出倍率 2。
        #expect(
            abs(size.width - 720) <= 2,
            "导出宽度 \(size.width) 与预期 720（360 × 2）不符"
        )
    }

    @Test("无压缩历史时导出仍然成功", .timeLimit(.minutes(1)))
    func exportWorksWithoutCompactionEvents() {
        let popover = ContextPopover(
            usage: usage(),
            history: history(),
            events: []
        )

        let size = exportedSize(popover: popover)

        #expect(size.width > 0, "导出宽度为 0")
        #expect(size.height > 0, "导出高度为 0")
    }

    @Test("导出内容可以写成 PNG 文件", .timeLimit(.minutes(1)))
    func exportProducesWritablePNG() throws {
        let popover = ContextPopover(
            usage: usage(),
            history: history(),
            events: previewCompactionEvents(count: 3)
        )

        let image = try #require(ContextPopoverImageExporter.render(content: popover.exportContent))

        // 写到临时目录，避免污染真实位置。
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("llm-context-export-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let url = directory.appendingPathComponent("export.png")
        ContextPopoverImageExporter.write(image, to: url)

        let data = try #require(FileManager.default.contents(atPath: url.path))
        #expect(data.count > 0, "写出的 PNG 是空文件")

        // PNG 文件头签名，验证写出的确实是 PNG 而不是其它格式。
        let signature = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
        #expect(data.starts(with: signature), "写出的文件不是合法 PNG")
    }
}
#endif
