import AppKit
import Foundation
import Testing
@testable import PluginConversationInput

/// 粘贴折叠 chip 的命中测试。
///
/// ## 回归背景（真实用户缺陷）
///
/// 往空输入框里粘贴 1200 个 ASCII 字符，正文折叠成一个 chip。此时点击 chip
/// 下方的**空白编辑区**，预览弹窗会被打开，这次点击也被吞掉——输入框拿不到
/// 焦点，也不再移动插入点。
///
/// 根因：命中测试用的是 AppKit 的
/// `characterIndex(for:in:fractionOfDistanceBetweenInsertionPoints:)`。该 API
/// 在没有字符覆盖该点时返回**最近**的字符，而不是「没有命中」。代码拿到最近
/// 字符后没有再判断点击点是否落在附件的实际矩形里，于是空白区域也被算作命中。
///
/// 悬停判断用的是同一套查询，同样缺少矩形包含判断，会显示错误的 chip 高亮。
@MainActor
@Suite("粘贴折叠 chip 的命中测试")
struct PastePreviewHitTestingTests {

    @Test("chip 矩形内的点命中 chip")
    func pointInsideChipHitsChip() throws {
        let textView = try makeTextViewWithChip()
        let rect = try #require(chipRect(in: textView))

        let hit = textView.pastePreviewHit(at: NSPoint(x: rect.midX, y: rect.midY))

        #expect(hit != nil)
    }

    @Test("chip 矩形外的空白点不命中 chip")
    func pointOutsideChipDoesNotHit() throws {
        let textView = try makeTextViewWithChip()
        let rect = try #require(chipRect(in: textView))

        // chip 下方 30 像素处的空白编辑区：离 chip 足够远，又仍在文本容器内，
        // 「最近字符」查询仍会解析到那个唯一的附件字符。
        let emptyPoint = NSPoint(x: rect.midX, y: rect.minY - 30)
        let hit = textView.pastePreviewHit(at: emptyPoint)

        #expect(hit == nil)
    }

    @Test("chip 矩形左侧的空白点不命中 chip")
    func pointLeftOfChipDoesNotHit() throws {
        let textView = try makeTextViewWithChip()
        let rect = try #require(chipRect(in: textView))

        let emptyPoint = NSPoint(x: rect.minX - 40, y: rect.midY)
        let hit = textView.pastePreviewHit(at: emptyPoint)

        #expect(hit == nil)
    }

    // MARK: - Helpers

    /// 造一个只含有一个粘贴 chip 的编辑器。
    private func makeTextViewWithChip() throws -> EditorTextView {
        let textView = EditorTextView(frame: NSRect(x: 0, y: 0, width: 400, height: 200))
        textView.hasPastePreviewAttachments = true
        textView.textStorage?.append(
            NSAttributedString(attachment: PastePreviewAttachment(originalText: String(repeating: "a", count: 1200)))
        )
        textView.layoutManager?.ensureLayout(for: textView.textContainer!)

        return textView
    }

    /// 取 chip 在视图坐标系里的矩形。
    private func chipRect(in textView: EditorTextView) -> NSRect? {
        guard let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer,
              textView.textStorage?.length ?? 0 > 0 else {
            return nil
        }

        let glyphRange = layoutManager.glyphRange(
            forCharacterRange: NSRange(location: 0, length: 1),
            actualCharacterRange: nil
        )
        return layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
            .offsetBy(dx: textView.textContainerOrigin.x, dy: textView.textContainerOrigin.y)
    }
}
