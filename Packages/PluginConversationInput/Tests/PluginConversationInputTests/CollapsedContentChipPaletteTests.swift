import AppKit
import ProviderMessage
import Testing
@testable import PluginConversationInput

/// 输入框 chip 与消息列表 chip 的**配色一致性**。
///
/// 同一段折叠内容会出现在两个地方：输入框里作为内联 chip（AppKit
/// `NSTextAttachment`），消息列表里作为独立胶囊（SwiftUI）。两处由不同的
/// 技术栈绘制，样式一旦各写一份就会漂移。
///
/// 早期输入框这一侧直接用 `NSColor.controlAccentColor` 画悬停态，胶囊会变成
/// 系统强调色（青绿），与消息列表里那颗安静的灰胶囊完全不是一回事；
/// 常态的标题/统计信息色也与消息列表的 `theme.textPrimary` / `theme.textTertiary`
/// 不是同一个来源。
///
/// 故颜色统一由 SwiftUI 层按主题注入（``PasteChipPalette``），两侧共用同一套色。
/// 这里守住「注入的配色真的被用上了」这条链路。
@MainActor
@Suite("CollapsedContentChip 配色一致性")
struct CollapsedContentChipPaletteTests {
    /// 一套可辨识的配色，用于验证注入是否生效。
    ///
    /// 刻意避开 `systemBlue`：系统强调色（`controlAccentColor`）本身就是蓝，
    /// 与 `systemBlue` 几乎同色，用它当图标色会让「排除强调色」的断言误判。
    private func distinctivePalette() -> PasteChipPalette {
        PasteChipPalette(
            title: .systemRed,
            detail: .systemGreen,
            icon: .systemPurple,
            fill: .systemYellow,
            stroke: .systemOrange,
            hoverFill: .systemTeal,
            hoverStroke: .systemBrown
        )
    }

    /// 渲染 chip 所在的「正文 + chip」行，返回位图。
    private func render(cell: PasteButtonAttachmentCell) -> (image: NSBitmapImageRep, bodyWidth: Int) {
        let width = 800
        let height = 120
        let font = NSFont.systemFont(ofSize: 15)
        let bodyText = "顺丰是大丰收的"

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

        let bodyWidth = Int((bodyText as NSString).size(withAttributes: [.font: font]).width)
        return (image, bodyWidth)
    }

    /// 指定列区间内是否出现了接近目标色的像素。
    private func containsColor(
        _ image: NSBitmapImageRep,
        xRange: Range<Int>,
        matching target: NSColor,
        tolerance: CGFloat = 0.12
    ) -> Bool {
        guard let targetRGB = target.usingColorSpace(.deviceRGB) else { return false }
        for row in 0..<image.pixelsHigh {
            for x in xRange {
                guard let color = image.colorAt(x: x, y: row)?.usingColorSpace(.deviceRGB) else { continue }
                let matches = abs(color.redComponent - targetRGB.redComponent) < tolerance
                    && abs(color.greenComponent - targetRGB.greenComponent) < tolerance
                    && abs(color.blueComponent - targetRGB.blueComponent) < tolerance
                if matches { return true }
            }
        }
        return false
    }

    @Test("胶囊底色用注入的配色，而不是系统强调色")
    func usesInjectedFillColor() {
        let palette = distinctivePalette()
        let cell = PasteButtonAttachmentCell(
            title: "粘贴的文本",
            detail: "12,480 字 · 312 行",
            font: .systemFont(ofSize: 15),
            palette: palette
        )

        let (image, bodyWidth) = render(cell: cell)
        let chipRange = (bodyWidth + 2)..<(bodyWidth + Int(cell.cellSize().width) - 2)

        #expect(containsColor(image, xRange: chipRange, matching: palette.fill))
        // 悬停态曾用 `controlAccentColor`，这里明确排除系统强调色。
        #expect(!containsColor(image, xRange: chipRange, matching: .controlAccentColor, tolerance: 0.06))
    }

    @Test("标题用注入的主色")
    func usesInjectedTitleColor() {
        let palette = distinctivePalette()
        let cell = PasteButtonAttachmentCell(
            title: "粘贴的文本",
            detail: "",
            font: .systemFont(ofSize: 15),
            palette: palette
        )

        let (image, bodyWidth) = render(cell: cell)
        // 标题起点：图标（11pt）+ 图标到标题间距（6pt）+ 胶囊左内边距（10pt）。
        let titleStart = bodyWidth + Int(CollapsedContentChipStyle.horizontalPadding)
            + Int(CollapsedContentChipStyle.iconSize)
            + Int(CollapsedContentChipStyle.iconSpacing)
        let titleRange = titleStart..<(titleStart + 24)

        #expect(containsColor(image, xRange: titleRange, matching: palette.title))
    }

    @Test("统计信息用注入的次级色")
    func usesInjectedDetailColor() {
        let palette = distinctivePalette()
        let cell = PasteButtonAttachmentCell(
            title: "粘贴的文本",
            detail: "12,480 字 · 312 行",
            font: .systemFont(ofSize: 15),
            palette: palette
        )

        let (image, bodyWidth) = render(cell: cell)
        // 统计信息在标题之后，量它所在的那一段。
        let titleWidth = Int(
            ("粘贴的文本" as NSString).size(
                withAttributes: [.font: NSFont.systemFont(ofSize: CollapsedContentChipStyle.titleSize, weight: .medium)]
            ).width
        )
        let detailStart = bodyWidth
            + Int(CollapsedContentChipStyle.horizontalPadding)
            + Int(CollapsedContentChipStyle.iconSize)
            + Int(CollapsedContentChipStyle.iconSpacing)
            + titleWidth
            + Int(CollapsedContentChipStyle.detailSpacing)
        let detailRange = detailStart..<(detailStart + 24)

        #expect(containsColor(image, xRange: detailRange, matching: palette.detail))
    }

    @Test("默认兜底配色不是系统强调色")
    func fallbackAvoidsAccentColor() {
        // 兜底配色用于没有主题上下文的路径（如单元测试）。
        // 它必须是安静的灰，而不是系统强调色。
        let palette = PasteChipPalette.fallback

        #expect(palette.fill != .controlAccentColor)
        #expect(palette.hoverFill != .controlAccentColor)
        #expect(palette.hoverStroke != .controlAccentColor)
    }
}
