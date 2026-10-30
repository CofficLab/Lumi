import AppKit
import ProviderMessage
import Testing
@testable import PluginConversationInput

/// 内联 chip 的**胶囊几何**。
///
/// 这里的断言守着一条硬约束：胶囊是「裹住这一行文字」的，不是「压在文字
/// 下面的一块底板」。
///
/// 早期实现把胶囊画成整个 cell 高度（等于行盒高度），实测胶囊有 27pt 高、
/// 底边落到正文基线以下 13pt——它越出了 18pt 的行盒，视觉上像一块底板压住
/// 这行文字。输入框里的粘贴 chip 正是因此显得杂乱，且与消息列表里的 chip
/// 完全不是一个样子。
///
/// 量测全部走**真实 `EditorTextView`**：离屏的 `NSTextStorage` +
/// `NSLayoutManager` 给 attachment 的 cell 帧与真实文本视图不同，量出来的
/// 「对齐」在真实 App 里未必成立。
///
/// 断言直接量像素，不依赖内部实现细节。
@MainActor
@Suite("CollapsedContentChip 胶囊几何")
struct CollapsedContentChipGeometryTests {
    /// 在真实文本视图里渲染「chip + 正文」，返回量测结果。
    private func measure(
        bodyText: String,
        font: NSFont,
        cell: NSTextAttachmentCell
    ) -> (pillBottom: Int, pillHeight: Int, baseline: Int, lineHeight: CGFloat) {
        let width = 900
        let height = 120

        let textView = EditorTextView(frame: NSRect(x: 0, y: 0, width: width, height: height))
        textView.font = font
        textView.textColor = .labelColor
        textView.isRichText = false
        textView.isVerticallyResizable = true
        textView.textContainerInset = NSSize(width: 4, height: 4)
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(
            width: CGFloat(width),
            height: CGFloat.greatestFiniteMagnitude
        )

        let attachment = NSTextAttachment()
        attachment.attachmentCell = cell
        textView.insertText(
            NSAttributedString(attachment: attachment),
            replacementRange: NSRange(location: 0, length: 0)
        )
        textView.insertText(
            bodyText,
            replacementRange: NSRange(location: textView.string.count, length: 0)
        )
        if let container = textView.textContainer,
           let layoutManager = textView.layoutManager {
            layoutManager.glyphRange(for: container)
        }

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
        textView.draw(NSRect(x: 0, y: 0, width: width, height: height))
        NSGraphicsContext.restoreGraphicsState()

        func luminance(_ x: Int, _ y: Int) -> Double {
            guard let raw = image.colorAt(x: x, y: y) else { return 1 }
            let alpha = raw.alphaComponent
            if alpha < 0.001 { return 1 }
            let rgb = raw.usingColorSpace(.deviceRGB)!
            let red = Double(rgb.redComponent) / alpha + (1 - alpha)
            let green = Double(rgb.greenComponent) / alpha + (1 - alpha)
            let blue = Double(rgb.blueComponent) / alpha + (1 - alpha)
            return (red + green + blue) / 3
        }

        let chipWidth = Int(cell.cellSize().width)
        let bodyWidth = Int((bodyText as NSString).size(withAttributes: [.font: font]).width)

        // 胶囊**底色/描边**（浅灰）的行范围。文字墨迹（深色）不算在内——
        // 否则量到的是字的高度，而不是胶囊的高度。
        var top = Int.max
        var bottom = -1
        for row in 0..<height {
            for x in 0..<min(chipWidth, width) where luminance(x, row) < 0.985 {
                top = min(top, row)
                bottom = max(bottom, row)
                break
            }
        }

        // 正文中文的墨迹底边即基线。
        var baseline = -1
        for row in 0..<height {
            for x in chipWidth..<min(chipWidth + bodyWidth, width) where luminance(x, row) < 0.62 {
                baseline = max(baseline, row)
                break
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

        // 胶囊必须待在行盒里（实测 15pt / 行盒 18pt）。
        // 早期实现下胶囊高 27pt，比行盒还高——它越出了行盒。
        #expect(Double(measured.pillHeight) <= measured.lineHeight)
    }

    @Test("chip 主标题随正文字号变化")
    func matchesBodyFontSize() {
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

        #expect(large.cellSize().width > small.cellSize().width)
    }
}
