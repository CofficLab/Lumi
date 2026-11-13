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

    @Test("插入目录路径不会展开已有 chip，区间保持不变")
    func insertingPlainTextKeepsExistingChip() throws {
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

        let pasted = "PASTED-BODY"
        textView.textStorage?.append(NSAttributedString(string: "summarize "))
        textView.hasPastePreviewAttachments = true
        textView.textStorage?.append(
            NSAttributedString(attachment: PastePreviewAttachment(originalText: pasted))
        )
        textView.setSelectedRange(NSRange(location: textView.string.count, length: 0))
        coordinator.publishCommittedTextForTesting(from: textView)
        #expect(draft == "summarize \(pasted)")
        #expect(reported.count == 1)

        // 目录拖放走同一条纯文本插入通道（阈值取最大值，永不折叠）。
        coordinator.insert(
            ConversationInputBlockRequest(
                text: "/tmp/pkg",
                title: "pkg",
                systemImage: "folder",
                collapseThreshold: .max
            ),
            in: textView
        )

        #expect(draft == "summarize \(pasted)\n/tmp/pkg")
        #expect(textView.hasPastePreviewAttachments)
        let block = try #require(reported.first)
        #expect(reported.count == 1)
        #expect(block.start == "summarize ".count)
        #expect(block.length == pasted.count)
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

    @Test("撤销恢复被删除的 chip 后重新拍平正文并恢复区间")
    func undoRestoringChipFlattensAgain() {
        let pasted = String(repeating: "P", count: 30)
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
        textView.textStorage?.setAttributedString(NSAttributedString(string: "A "))

        textView.hasPastePreviewAttachments = true
        textView.textStorage?.append(
            NSAttributedString(attachment: PastePreviewAttachment(originalText: pasted))
        )
        coordinator.publishCommittedTextForTesting(from: textView)
        #expect(draft == "A \(pasted)")

        // 删除 chip：发布后标志被清为 false，正文只剩 "A "。
        textView.textStorage?.deleteCharacters(in: NSRange(location: 2, length: 1))
        coordinator.publishCommittedTextForTesting(from: textView)
        #expect(draft == "A ")
        #expect(!textView.hasPastePreviewAttachments)
        #expect(reported.isEmpty)

        // Undo 把 attachment 放回 text storage，但不会同步恢复标志。
        textView.textStorage?.append(
            NSAttributedString(attachment: PastePreviewAttachment(originalText: pasted))
        )
        #expect(!textView.hasPastePreviewAttachments)

        coordinator.publishCommittedTextForTesting(from: textView)

        // 必须重新按真实 attachment 拍平，而不是把 U+FFFC 当正文发布。
        #expect(draft == "A \(pasted)")
        #expect(reported.count == 1)
        #expect(reported.first?.start == 2)
        #expect(reported.first?.length == pasted.count)
        #expect(textView.hasPastePreviewAttachments)
    }

    @Test("折叠粘贴必须保留原文首尾换行，发送正文不黏连（#336）")
    func collapsedPastePreservesOriginalNewlines() throws {
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

        // 用户先写了 prefix（无尾换行），光标停在末尾。
        textView.textStorage?.setAttributedString(NSAttributedString(string: "prefix"))
        textView.setSelectedRange(NSRange(location: textView.string.count, length: 0))

        // 粘贴「换行 + 1200 个 A + 换行」，达到折叠阈值。用独立命名 pasteboard，
        // 不触碰系统剪贴板。
        let raw = "\n" + String(repeating: "A", count: 1200) + "\n"
        let pasteboard = NSPasteboard(name: .init("PluginConversationInputTests.\(UUID().uuidString)"))
        pasteboard.declareTypes([.string], owner: nil)
        pasteboard.setString(raw, forType: .string)

        #expect(coordinator.handlePaste(pasteboard, in: textView))

        // chip 之后紧接着写 suffix 并发送。
        textView.setSelectedRange(NSRange(location: textView.string.count, length: 0))
        textView.insertText("suffix", replacementRange: textView.selectedRange())
        coordinator.publishCommittedTextForTesting(from: textView)

        // 原文首尾换行必须保留：prefix、长文本、suffix 各自保持换行边界，
        // 而不是被 trim 成 "prefixAAA...AAAsuffix"。
        #expect(draft == "prefix" + raw + "suffix")
        #expect(reported.count == 1)
        let block = try #require(reported.first)
        #expect(block.start == "prefix".count)
        #expect(block.length == raw.count)
    }

    @Test("纯换行粘贴不折叠，交回普通粘贴处理（#336）")
    func newlineOnlyPasteIsNotCollapsed() {
        var draft = ""
        var height: CGFloat = ChatInputEditorView.minHeight
        var focused = false
        var cursor = 0
        var dragging = false

        let view = ChatInputEditorView(
            text: Binding(get: { draft }, set: { draft = $0 }),
            height: Binding(get: { height }, set: { height = $0 }),
            onSubmit: {},
            onCollapsedBlocksChanged: { _ in },
            isFocused: Binding(get: { focused }, set: { focused = $0 }),
            cursorPosition: Binding(get: { cursor }, set: { cursor = $0 }),
            isImageDragHovering: Binding(get: { dragging }, set: { dragging = $0 })
        )
        let coordinator = view.makeCoordinator()
        let textView = EditorTextView()
        coordinator.attach(to: textView)

        let pasteboard = NSPasteboard(name: .init("PluginConversationInputTests.\(UUID().uuidString)"))
        pasteboard.declareTypes([.string], owner: nil)
        pasteboard.setString("\n\n\n", forType: .string)

        // trim 后为空：不折叠、不插入 chip，由普通粘贴通道处理。
        #expect(!coordinator.handlePaste(pasteboard, in: textView))
        #expect(!textView.hasPastePreviewAttachments)
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
        // 固定浅色外观：否则 `labelColor` 在深色外观下是白色，
        // 白底白字 → 墨迹检测失效（见 ChipPixelProbe.withLightAppearance）。
        ChipPixelProbe.withLightAppearance {
            let glyphRange = layoutManager.glyphRange(for: textContainer)
            layoutManager.drawBackground(forGlyphRange: glyphRange, at: .zero)
            layoutManager.drawGlyphs(forGlyphRange: glyphRange, at: .zero)
        }
        NSGraphicsContext.restoreGraphicsState()
        return (image, body.size().width)
    }

    /// 指定列区间内最靠下的墨迹行。中文的墨迹底边落在基线上。
    private func inkBottomRow(_ image: NSBitmapImageRep, xRange: Range<Int>) -> Int? {
        var bottom: Int?
        for row in 0..<image.pixelsHigh {
            for x in xRange {
                guard let color = image.colorAt(x: x, y: row)?.usingColorSpace(.deviceRGB) else { continue }
                if color.redComponent < ChipPixelProbe.inkThreshold,
                   color.greenComponent < ChipPixelProbe.inkThreshold,
                   color.blueComponent < ChipPixelProbe.inkThreshold {
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
