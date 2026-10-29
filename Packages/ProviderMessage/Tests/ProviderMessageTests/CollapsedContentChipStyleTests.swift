import CoreGraphics
import Foundation
import Testing
@testable import ProviderMessage

/// 折叠块 chip 的共享规格。
///
/// 这些值同时被输入框（AppKit）与消息列表（SwiftUI）使用，所以它们是
/// 「两处看起来一样」的唯一保证——一旦某处私自改一份，两边就会漂移。
@Suite("CollapsedContentChipStyle")
struct CollapsedContentChipStyleTests {
    @Test("标题串按第一个分隔符拆成标题与统计信息")
    func splitsTitleAndDetail() {
        let parts = CollapsedContentChipStyle.split(title: "粘贴的文本 · 13,253 字 · 75 行")

        #expect(parts.label == "粘贴的文本")
        // 统计信息本身也含分隔符，必须整体留在 detail 里。
        #expect(parts.detail == "13,253 字 · 75 行")
    }

    @Test("没有分隔符时整串都是标题")
    func keepsWholeTitleWhenNoSeparator() {
        // 代码编辑器送来的 chip 标题是文件名，不含统计信息。
        let parts = CollapsedContentChipStyle.split(title: "Sources/Greet.swift")

        #expect(parts.label == "Sources/Greet.swift")
        #expect(parts.detail == nil)
    }

    @Test("分隔符后为空时没有统计信息")
    func dropsEmptyDetail() {
        let parts = CollapsedContentChipStyle.split(title: "粘贴的文本 · ")

        #expect(parts.label == "粘贴的文本")
        #expect(parts.detail == nil)
    }

    @Test("空标题原样返回")
    func handlesEmptyTitle() {
        let parts = CollapsedContentChipStyle.split(title: "")

        #expect(parts.label == "")
        #expect(parts.detail == nil)
    }

    @Test("字号与消息列表的排版规格一致")
    func keepsTypographyScale() {
        // 标题比统计信息大一级，且统计信息不小于 10pt（再小就读不清了）。
        #expect(CollapsedContentChipStyle.titleSize > CollapsedContentChipStyle.detailSize)
        #expect(CollapsedContentChipStyle.detailSize >= 10)
    }
}
