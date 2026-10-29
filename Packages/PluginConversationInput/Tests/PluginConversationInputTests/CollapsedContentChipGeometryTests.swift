import AppKit
import ProviderMessage
import Testing
@testable import PluginConversationInput

/// 内联 chip 的**胶囊几何**。
///
/// 这里的断言守着一条硬约束：胶囊是「裹住文字」的，不是「压在文字下面」的。
///
/// 早期实现把胶囊画成整个 cell 高度（等于行盒高度），实测胶囊有 27pt 高、
/// 底边落到正文基线以下 13pt——它越出了 18pt 的行盒，视觉上像一块底板压住
/// 这行文字。输入框里的粘贴 chip 正是因此显得杂乱，且与消息列表里的 chip
/// 完全不是一个样子。
///
/// 断言直接量像素，不依赖内部实现细节。
@MainActor
@Suite("CollapsedContentChip 胶囊几何")
struct CollapsedContentChipGeometryTests {
    /// 排版并离屏渲染「正文 + chip」，返回量测结果。
    private func measure(
        bodyText: String,
        font: NSFont,
        cell: NSTextAttachmentCell
    ) -> (pillBottom: Int, pillHeight: Int, baseline: Int, lineHeight: CGFloat) {
        let width = 900
        let height = 160
        let storage = NSTextStorage()
        let layoutManager = NSLayoutManager()
        let textContainer = NSTextContainer(size: NSSize(width: width, height: height))
        textContainer.widthTracksTextView = true
        storage.addLayoutManager(layoutManager)
        layoutManager.addTextContainer(textContainer)

        storage.append(
            NSAttributedString(
                string: bodyText,
                attributes: [.font: font, .foregroundColor: NSColor.labelColor]
            )
        )
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

        let bodyPx = Int((bodyText as NSString).size(withAttributes: [.font: font]).width)
        let chipWidth = Int(cell.cellSize().width)

        // 胶囊**底色/描边**（浅灰）的行范围。文字墨迹（深色）不算在内——
        // 否则量到的是字的高度，而不是胶囊的高度。
        var top = Int.max
        var bottom = -1
        for row in 0..<image.pixelsHigh {
            for x in bodyPx..<min(bodyPx + chipWidth, image.pixelsWide) {
                guard let color = image.colorAt(x: x, y: row)?.usingColorSpace(.deviceRGB) else { continue }
                if color.redComponent < 0.985 {
                    if color.redComponent >= 0.62 {
                        top = min(top, row)
                        bottom = max(bottom, row)
                    }
                    break
                }
            }
        }

        // 正文中文的墨迹底边即基线。
        var baseline = -1
        for row in 0..<image.pixelsHigh {
            for x in 0..<(bodyPx - 3) {
                guard let color = image.colorAt(x: x, y: row)?.usingColorSpace(.deviceRGB) else { continue }
                if color.redComponent < 0.62 {
                    baseline = max(baseline, row)
                    break
                }
            }
        }

        return (bottom, bottom - top + 1, baseline, NSLayoutManager().defaultLineHeight(for: font))
    }

    private func makeCell(font: NSFont) -> PasteButtonAttachmentCell {
        PasteButtonAttachmentCell(
            title: "粘贴的文本",
            detail: "13,253 字 · 75 行",
            font: font
        )
    }

    @Test("胶囊底边不落到正文基线以下")
    func keepsPillAboveBodyBaseline() {
        let font = NSFont.systemFont(ofSize: 15)
        let measured = measure(
            bodyText: "顺丰撤发生的是发顺丰讽短发",
            font: font,
            cell: makeCell(font: font)
        )

        // 胶囊只允许比基线低「下内边距 + 字体降部」那么多（实测 2pt）。
        // 早期实现下这个差值是 13pt——胶囊整块压在文字下面。
        #expect(measured.pillBottom - measured.baseline <= 3)
    }

    @Test("胶囊紧贴文字，不撑满整个行盒")
    func pillHugsContentInsteadOfLineBox() {
        let font = NSFont.systemFont(ofSize: 15)
        let measured = measure(
            bodyText: "顺丰撤发生的是发顺丰讽短发",
            font: font,
            cell: makeCell(font: font)
        )

        // 胶囊必须待在行盒里（实测 16pt / 行盒 18pt）。
        // 早期实现下胶囊高 27pt，比行盒还高——它越出了行盒。
        #expect(Double(measured.pillHeight) <= measured.lineHeight)
    }

    @Test("chip 的字号固定，不随正文字号缩放")
    func keepsFixedFontSize() {
        // 同一个 chip 在 15pt 与 18pt 正文下应当是同样大小——
        // 否则它与消息列表里的 chip 对不上。
        let small = PasteButtonAttachmentCell(
            title: "粘贴的文本",
            detail: "13,253 字 · 75 行",
            font: .systemFont(ofSize: 15)
        )
        let large = PasteButtonAttachmentCell(
            title: "粘贴的文本",
            detail: "13,253 字 · 75 行",
            font: .systemFont(ofSize: 18)
        )

        #expect(small.cellSize().width == large.cellSize().width)
    }
}
