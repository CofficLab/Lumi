import AppKit
import ProviderMessage
import Testing
@testable import PluginConversationInput

/// 内联 chip 与**所在那一行文字**的垂直对齐。
///
/// 这里守的是一条硬约束：chip 是「长在这一行文字里」的元素——chip 的文字
/// 基线与正文基线重合，胶囊的上下沿与正文的字顶/字底齐平。
///
/// ## 为什么必须在真实 NSTextView 里量
///
/// 离屏的 `NSTextStorage` + `NSLayoutManager` 与真实 `NSTextView` 给
/// attachment 的 `cellFrame` **不是同一个**：真实文本视图里 cell 帧的位置
/// 由滚动视图、容器内边距、行的实际高度共同决定。用离屏渲染量出来的
/// 「对齐」，在真实 App 里未必成立——早期的对齐断言就是这么被骗过去的。
///
/// 故这里的量测全部走真实 `EditorTextView` + `insertText`（App 里插入
/// chip 的真实路径），再把视图渲染成位图量像素。
///
/// 绘制使用 `cacheDisplay`，保留 `NSTextView` 在真实窗口里的 flipped
/// 上下文。直接把手绘位图上下文当窗口使用会漏掉坐标翻转，让错误的
/// 垂直布局也得到通过结果。
@MainActor
@Suite("CollapsedContentChip 垂直对齐")
struct CollapsedContentChipVerticalAlignmentTests {
    /// 渲染「chip + 正文」一行，返回量测结果。
    ///
    /// - Parameters:
    ///   - cellHeightOverride: 故意改掉 cell 的占位高度，模拟 AppKit 把 cell
    ///     摆到别处（行盒与 cell 高度不一致）时的情形。`nil` 表示用真实高度。
    private func measure(
        cellHeightOverride: CGFloat? = nil,
        bodyText: String = "粘贴的文本",
        font: NSFont = .systemFont(ofSize: 15)
    ) -> (pillTop: Int, pillBottom: Int, inkTop: Int, inkBottom: Int, bodyTop: Int, bodyBottom: Int, secondBodyTop: Int) {
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

        // 走 App 的真实插入路径：真 attachment + insertText，
        // 而不是直接 append 到 textStorage。
        let attachment = PastePreviewAttachment(
            originalText: String(repeating: "粘贴内容\n", count: 2_000),
            title: "粘贴的文本",
            systemImage: nil,
            font: font
        )
        let cell = attachment.attachmentCell as? PasteButtonAttachmentCell
        if let cellHeightOverride, let cell {
            // 模拟 AppKit 把 cell 摆到别处：cell 的占位高度与算基线时用的
            // 高度不一致时，早期实现估算出的基线会整块偏移。
            cell.setCellHeightForTesting(cellHeightOverride)
        }
        textView.insertText(
            NSAttributedString(attachment: attachment),
            replacementRange: NSRange(location: textView.string.count, length: 0)
        )
        textView.insertText(
            bodyText,
            replacementRange: NSRange(location: textView.string.count, length: 0)
        )
        if let container = textView.textContainer,
           let layoutManager = textView.layoutManager {
            layoutManager.glyphRange(for: container)
        }

        let bounds = NSRect(x: 0, y: 0, width: width, height: height)
        let image = textView.bitmapImageRepForCachingDisplay(in: bounds)!
        textView.cacheDisplay(in: bounds, to: image)

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

        /// 找某一列区间里最深的像素列——写死单列会落在字与字的空隙里。
        func darkestColumn(_ x0: Int, _ x1: Int, threshold: Double) -> Int? {
            var best = -1
            var bestCount = 0
            for x in x0..<min(x1, width) {
                var count = 0
                for y in 0..<height where luminance(x, y) < threshold { count += 1 }
                if count > bestCount {
                    bestCount = count
                    best = x
                }
            }
            return bestCount > 0 ? best : nil
        }

        /// 某一列上的深色（文字墨迹）像素范围。
        func inkRange(at column: Int, threshold: Double) -> (top: Int, bottom: Int)? {
            var top = Int.max
            var bottom = -1
            for y in 0..<height where luminance(column, y) < threshold {
                top = min(top, y)
                bottom = max(bottom, y)
            }
            return bottom >= 0 ? (top, bottom) : nil
        }

        /// 某一列上的浅灰（胶囊底色/描边）像素范围。
        func pillRange(at column: Int) -> (top: Int, bottom: Int)? {
            var top = Int.max
            var bottom = -1
            for y in 0..<height {
                if luminance(column, y) < 0.985 {
                    top = min(top, y)
                    bottom = y
                } else if bottom >= 0 {
                    break
                }
            }
            return bottom >= 0 ? (top, bottom) : nil
        }

        // chip 是这一行的第一个元素，它的横向起点 = 容器内边距 + 行片段内边距。
        let cellX = Int(textView.textContainerInset.width
            + (textView.textContainer?.lineFragmentPadding ?? 5))
        let chipWidth = cell?.cellSize().width ?? 0
        let titleStart = cellX + Int(CollapsedContentChipStyle.horizontalPadding)
            + Int(CollapsedContentChipStyle.iconSize)
            + Int(CollapsedContentChipStyle.iconSpacing)
        let bodyStart = cellX + Int(chipWidth) + 4

        let titleColumn = darkestColumn(titleStart, titleStart + 40, threshold: 0.62)
        let bodyColumn = darkestColumn(bodyStart, bodyStart + 40, threshold: 0.62)
        // 胶囊是圆角矩形，边缘几列会被圆角切掉，量不到底色。
        var pillColumn: Int?
        var pillCount = 0
        for x in cellX..<min(cellX + Int(chipWidth), width) {
            var count = 0
            for y in 0..<height where luminance(x, y) < 0.985 { count += 1 }
            if count > pillCount {
                pillCount = count
                pillColumn = x
            }
        }

        let titleInk = titleColumn.flatMap { inkRange(at: $0, threshold: 0.62) }
        let bodyInk = bodyColumn.flatMap { inkRange(at: $0, threshold: 0.62) }
        let pill = pillColumn.flatMap { pillRange(at: $0) }

        var secondBodyTop = -1
        var foundFirstLine = false
        var foundLineGap = false
        for y in 0..<height {
            let hasInk = (0..<width).contains { luminance($0, y) < 0.62 }
            if hasInk {
                if foundLineGap {
                    secondBodyTop = y
                    break
                }
                foundFirstLine = true
            } else if foundFirstLine {
                foundLineGap = true
            }
        }

        return (
            pill?.top ?? -1,
            pill?.bottom ?? -1,
            titleInk?.top ?? -1,
            titleInk?.bottom ?? -1,
            bodyInk?.top ?? -1,
            bodyInk?.bottom ?? -1,
            secondBodyTop
        )
    }

    @Test("chip 标题与正文的字顶、字底和基线一致")
    func alignsChipTitleWithBodyText() {
        let measured = measure()

        #expect(measured.inkTop != -1)
        #expect(measured.bodyTop != -1)

        #expect(abs(measured.inkTop - measured.bodyTop) <= 1)
        #expect(abs(measured.inkBottom - measured.bodyBottom) <= 1)
    }

    @Test("胶囊与正文的上下沿齐平（不偏上也不偏下）")
    func alignsPillWithBodyTextBand() {
        let measured = measure()

        #expect(measured.pillTop != -1)
        #expect(measured.bodyTop != -1)

        // 胶囊上下沿相对正文字墨迹的偏移，取绝对值后应当接近相等：
        // 胶囊是「裹住」这一行字的，不是「压在」字下的一块底板。
        let topGap = abs(measured.pillTop - measured.bodyTop)
        let bottomGap = abs(measured.pillBottom - measured.bodyBottom)
        #expect(topGap <= 2)
        #expect(bottomGap <= 2)
    }

    @Test("胶囊不越过正文的行盒")
    func staysWithinLineBox() {
        let font = NSFont.systemFont(ofSize: 15)
        let measured = measure()

        #expect(measured.pillTop != -1)

        let pillHeight = measured.pillBottom - measured.pillTop + 1
        let lineHeight = Int(NSLayoutManager().defaultLineHeight(for: font))

        // 行内 chip 必须待在行盒里，否则会压到相邻行。
        #expect(pillHeight <= lineHeight)
    }

    @Test("chip 不侵入下一行文字")
    func staysAboveFollowingLine() {
        let measured = measure(bodyText: "粘贴的文本\n粘贴的文本")

        #expect(measured.secondBodyTop > 0)
        #expect(measured.pillBottom < measured.secondBodyTop)
    }

    @Test("行盒与 cell 高度不一致时，chip 仍与正文同基线")
    func keepsBaselineWhenCellIsMisplaced() {
        // 30pt 的 cell 高度与 18pt 的行盒不一致：早期实现会据此把基线算
        // 偏约 12pt，chip 整块掉到正文下面（用户截图里的观感）。
        let measured = measure(cellHeightOverride: 30)

        #expect(measured.inkTop != -1)
        #expect(measured.bodyTop != -1)

        #expect(abs(measured.inkBottom - measured.bodyBottom) <= 1)
    }
}
