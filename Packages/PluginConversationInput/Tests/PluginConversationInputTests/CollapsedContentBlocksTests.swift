import AppKit
import ProviderMessage
import SwiftUI
import Testing
@testable import PluginConversationInput

/// 折叠块区间的计算与上报。
///
/// 这是「粘贴时是折叠块、发出后却展开成一大段」这条链路的起点：
/// 编辑器必须把 chip 在拍平正文中的位置算出来并上报，否则发送端拿不到区间。
@MainActor
@Suite("CollapsedContentBlocks")
struct CollapsedContentBlocksTests {
    @Test("chip 拍平后保留原文，区间指向该段在正文中的位置")
    func flattensChipIntoTextWithRange() {
        let pasted = "PASTED-BODY"
        let storage = NSTextStorage(string: "before ")
        let attachment = PastePreviewAttachment(originalText: pasted)
        storage.append(NSAttributedString(attachment: attachment))
        storage.append(NSAttributedString(string: " after"))

        let result = ChatInputEditorView.flattenedContent(from: storage)

        #expect(result.hasAttachments)
        #expect(result.text == "before \(pasted) after")
        #expect(result.blocks.count == 1)

        let block = try! #require(result.blocks.first)
        #expect(block.start == "before ".count)
        #expect(block.length == pasted.count)
        #expect(block.title == attachment.chipTitle)
        #expect(block.systemImage == attachment.systemImage)

        // 区间必须真的指向那段文字。
        let start = result.text.index(result.text.startIndex, offsetBy: block.start)
        let end = result.text.index(start, offsetBy: block.length)
        #expect(String(result.text[start..<end]) == pasted)
    }

    @Test("多个 chip 的区间各自指向自己那一段")
    func tracksMultipleChips() {
        let storage = NSTextStorage()
        storage.append(NSAttributedString(string: "a"))
        storage.append(NSAttributedString(attachment: PastePreviewAttachment(originalText: "ONE")))
        storage.append(NSAttributedString(string: "b"))
        storage.append(NSAttributedString(attachment: PastePreviewAttachment(originalText: "TWO")))
        storage.append(NSAttributedString(string: "c"))

        let result = ChatInputEditorView.flattenedContent(from: storage)

        #expect(result.text == "aONEbTWOc")
        #expect(result.blocks.count == 2)
        #expect(result.blocks.map(\.start) == [1, 5])
        #expect(result.blocks.map(\.length) == [3, 3])
    }

    @Test("没有 chip 时不产生区间")
    func producesNoBlocksForPlainText() {
        let storage = NSTextStorage(string: "plain text")

        let result = ChatInputEditorView.flattenedContent(from: storage)

        #expect(!result.hasAttachments)
        #expect(result.blocks.isEmpty)
        #expect(result.text == "plain text")
    }

    @Test("编辑器把折叠块区间上报给上层")
    func reportsCollapsedBlocksUpward() {
        var draft = ""
        var height: CGFloat = ChatInputEditorView.minHeight
        var focused = false
        var cursor = 0
        var dragging = false
        var reported: [CollapsedContentBlock] = []

        let view = ChatInputEditorView(
            text: Binding(get: { draft }, set: { draft = $0 }),
            height: Binding(get: { height }, set: { height = $0 }),
            onSubmit: {},
            onCollapsedBlocksChanged: { reported = $0 },
            isFocused: Binding(get: { focused }, set: { focused = $0 }),
            cursorPosition: Binding(get: { cursor }, set: { cursor = $0 }),
            isImageDragHovering: Binding(get: { dragging }, set: { dragging = $0 })
        )
        let coordinator = view.makeCoordinator()
        let textView = EditorTextView()
        coordinator.attach(to: textView)

        textView.hasPastePreviewAttachments = true
        textView.textStorage?.append(
            NSAttributedString(attachment: PastePreviewAttachment(originalText: "BODY"))
        )

        coordinator.publishCommittedTextForTesting(from: textView)

        #expect(draft == "BODY")
        #expect(reported.count == 1)
        #expect(reported.first?.start == 0)
        #expect(reported.first?.length == 4)
    }
}
/// 内联 chip 的排版几何。
///
/// 这些断言守着「chip 像长在这行文字里」的几条硬约束：
/// chip 与正文基线重合、chip 不撑高文字行、标题与正文同字号。
@MainActor
@Suite("CollapsedContentChip 排版")
struct CollapsedContentChipLayoutTests {
    /// 构造一个「正文 + chip」的真实排版。
    private func layout(
        bodyText: String,
        font: NSFont,
        cell: NSTextAttachmentCell?
    ) -> (layoutManager: NSLayoutManager, textContainer: NSTextContainer, bodyWidth: CGFloat) {
        let storage = NSTextStorage()
        let layoutManager = NSLayoutManager()
        let textContainer = NSTextContainer(size: NSSize(width: 800, height: 400))
        textContainer.widthTracksTextView = true
        storage.addLayoutManager(layoutManager)
        layoutManager.addTextContainer(textContainer)

        let body = NSAttributedString(
            string: bodyText,
            attributes: [.font: font, .foregroundColor: NSColor.labelColor]
        )
        storage.append(body)
        if let cell {
            let attachment = NSTextAttachment()
            attachment.attachmentCell = cell
            storage.append(NSAttributedString(attachment: attachment))
        }
        layoutManager.glyphRange(for: textContainer)
        return (layoutManager, textContainer, body.size().width)
    }

    /// 把「正文 + chip」真实排版并离屏渲染，返回位图与正文宽度。
    private func render(
        bodyText: String,
        font: NSFont,
        cell: NSTextAttachmentCell
    ) -> (image: NSBitmapImageRep, bodyWidth: CGFloat) {
        let width = 800
        let height = 120
        let storage = NSTextStorage()
        let layoutManager = NSLayoutManager()
        let textContainer = NSTextContainer(size: NSSize(width: width, height: height))
        textContainer.widthTracksTextView = true
        storage.addLayoutManager(layoutManager)
        layoutManager.addTextContainer(textContainer)

        let body = NSAttributedString(
            string: bodyText,
            attributes: [.font: font, .foregroundColor: NSColor.labelColor]
        )
        storage.append(body)
        let attachment = NSTextAttachment()
        attachment.attachmentCell = cell
        storage.append(NSAttributedString(attachment: attachment))
        layoutManager.glyphRange(for: textContainer)

        let image = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: width,
            pixelsHigh: height,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )!
        NSGraphicsContext.saveGraphicsState()
        let context = NSGraphicsContext(bitmapImageRep: image)!
        NSGraphicsContext.current = context
        context.cgContext.setFillColor(NSColor.white.cgColor)
        context.cgContext.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let glyphRange = layoutManager.glyphRange(for: textContainer)
        layoutManager.drawBackground(forGlyphRange: glyphRange, at: .zero)
        layoutManager.drawGlyphs(forGlyphRange: glyphRange, at: .zero)
        NSGraphicsContext.restoreGraphicsState()
        return (image, body.size().width)
    }

    /// 指定列区间内最靠下的墨迹行。中文的墨迹底边落在基线上。
    private func inkBottomRow(_ image: NSBitmapImageRep, xRange: Range<Int>) -> Int? {
        var bottom: Int?
        for row in 0..<image.pixelsHigh {
            for x in xRange {
                guard let color = image.colorAt(x: x, y: row)?.usingColorSpace(.deviceRGB) else { continue }
                if color.redComponent < 0.62,
                   color.greenComponent < 0.62,
                   color.blueComponent < 0.62 {
                    bottom = max(bottom ?? row, row)
                    break
                }
            }
        }
        return bottom
    }

    @Test("chip 的文字基线与正文基线重合")
    func alignsChipBaselineWithBody() {
        let font = NSFont.systemFont(ofSize: 15)
        let cell = PasteButtonAttachmentCell(title: "粘贴的文本", detail: "12,480 字 · 312 行", font: font)

        // 直接量像素：正文与 chip 标题都是中文，墨迹底边落在基线上，
        // 两者底边相同即说明基线重合。
        let (image, bodyWidth) = render(bodyText: "顺丰是大丰收的", font: font, cell: cell)

        let bodyBottom = inkBottomRow(image, xRange: 0..<(Int(bodyWidth) - 3))
        // 只量 chip 标题那一段（图标之后），避免统计信息的小字号干扰。
        let titleStart = Int(bodyWidth) + 7 + 13 + 5
        let chipBottom = inkBottomRow(image, xRange: titleStart..<(titleStart + 20))

        #expect(bodyBottom != nil)
        #expect(chipBottom != nil)
        #expect(abs((chipBottom ?? 0) - (bodyBottom ?? 0)) <= 1)
    }

    @Test("chip 不撑高文字行")
    func keepsBodyLineHeight() {
        let font = NSFont.systemFont(ofSize: 15)

        let plain = layout(bodyText: "顺丰是大丰收的", font: font, cell: nil)
        let plainHeight = plain.layoutManager.usedRect(for: plain.textContainer).height

        let withChip = layout(
            bodyText: "顺丰是大丰收的",
            font: font,
            cell: PasteButtonAttachmentCell(title: "粘贴的文本", detail: "12,480 字 · 312 行", font: font)
        )
        let chipHeight = withChip.layoutManager.usedRect(for: withChip.textContainer).height

        #expect(chipHeight <= plainHeight + 1)
    }

    @Test("chip 占位高度等于正文的自然行高")
    func usesBodyLineHeightAsCellHeight() {
        let font = NSFont.systemFont(ofSize: 15)
        let cell = PasteButtonAttachmentCell(title: "粘贴的文本", detail: "12,480 字 · 312 行", font: font)

        let lineHeight = NSLayoutManager().defaultLineHeight(for: font)
        #expect(cell.cellSize().height == lineHeight)
    }

    @Test("chip 宽度包含图标、标题与统计信息")
    func measuresChipWidth() {
        let font = NSFont.systemFont(ofSize: 15)
        let titleOnly = PasteButtonAttachmentCell(title: "粘贴的文本", detail: "", font: font)
        let withDetail = PasteButtonAttachmentCell(title: "粘贴的文本", detail: "12,480 字 · 312 行", font: font)

        #expect(withDetail.cellSize().width > titleOnly.cellSize().width)
    }

    @Test("统计信息太长时舍弃统计信息，保留标题")
    func dropsDetailWhenTooLong() {
        let font = NSFont.systemFont(ofSize: 15)
        let cell = PasteButtonAttachmentCell(
            title: "粘贴的文本",
            detail: String(repeating: "很长的统计信息 ", count: 40),
            font: font
        )
        // 宽度有上限。
        #expect(cell.cellSize().width <= 320)
    }
}
