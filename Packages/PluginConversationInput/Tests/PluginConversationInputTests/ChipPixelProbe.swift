import AppKit
@testable import PluginConversationInput

/// chip 像素量测的共享底座。
///
/// ## 为什么必须固定浅色外观
///
/// 这些断言靠**像素亮度**区分「墨迹」和「背景」：阈值是按「白底 + 深色字」
/// 写死的（墨迹 < 0.62，背景 > 0.985）。但 `NSTextView` 的背景取自
/// `textBackgroundColor`——它跟着**系统外观**走。深色外观下背景是深色
/// （luminance ≈ 0.12），于是**整个画布**都低于阈值，被当成墨迹：
/// 量出来的「墨迹行」覆盖全部 120px，「胶囊高度」远超行盒，
/// 「下一行文字的顶边」永远是 -1。
///
/// 这不是 chip 渲染有缺陷，而是**量测方法假设了宿主外观**。
/// 把外观固定成浅色后，量测恢复自洽：背景纯白（luminance = 1.0），
/// 墨迹行只有实际有字的那几行。
///
/// - Important: 固定外观必须作用在**视图**上（`view.appearance`），
///   而不只是当前绘图上下文——`cacheDisplay` 会走视图自己的绘制路径。
enum ChipPixelProbe {
    /// 构造一个固定浅色外观的文本视图。
    ///
    /// - Parameters:
    ///   - font: 正文字体。
    ///   - width: 视图宽度（点）。
    ///   - height: 视图高度（点）。
    @MainActor
    static func makeTextView(
        font: NSFont,
        width: CGFloat,
        height: CGFloat
    ) -> EditorTextView {
        let textView = EditorTextView(frame: NSRect(x: 0, y: 0, width: width, height: height))
        textView.font = font
        textView.textColor = .labelColor
        textView.isRichText = false
        textView.isVerticallyResizable = true
        textView.textContainerInset = NSSize(width: 4, height: 4)
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(
            width: width,
            height: CGFloat.greatestFiniteMagnitude
        )
        // 固定浅色外观，让像素阈值与背景自洽（见类型注释）。
        textView.appearance = NSAppearance(named: .aqua)
        return textView
    }

    /// 墨迹亮度阈值：低于此值算文字墨迹。
    static let inkThreshold = 0.62
    /// 背景亮度阈值：高于此值算纯背景。
    static let backgroundThreshold = 0.985

    /// 把视图渲染成 1× 位图。
    ///
    /// - Important: 固定 1× 位图：量测代码按「1 point = 1 pixel」取坐标，
    ///   若用设备 scale 的 rep，Retina 上整张图的坐标会翻倍。
    @MainActor
    static func render(
        _ textView: NSView,
        width: Int,
        height: Int
    ) -> NSBitmapImageRep {
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
        image.size = NSSize(width: CGFloat(width), height: CGFloat(height))
        textView.cacheDisplay(
            in: NSRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height)),
            to: image
        )
        return image
    }

    /// 像素亮度（0 = 黑，1 = 白）。
    ///
    /// - Note: 标 `@MainActor` 是为了和位图的创建/读取留在同一隔离域——
    ///   `NSBitmapImageRep` 不是 `Sendable`，跨隔离域传递会触发
    ///   Swift 6 的 region isolation 检查。
    @MainActor
    static func luminance(_ image: NSBitmapImageRep, x: Int, y: Int) -> Double {
        guard let raw = image.colorAt(x: x, y: y) else { return 1 }
        let alpha = raw.alphaComponent
        if alpha < 0.001 { return 1 }
        let rgb = raw.usingColorSpace(.deviceRGB)!
        return (Double(rgb.redComponent) / alpha + (1 - alpha)
            + Double(rgb.greenComponent) / alpha + (1 - alpha)
            + Double(rgb.blueComponent) / alpha + (1 - alpha)) / 3
    }
}

extension ChipPixelProbe {
    /// 在**浅色外观**下执行绘制。
    ///
    /// 直接用 `NSLayoutManager.drawGlyphs` 离屏绘制时没有视图可以挂外观，
    /// `NSColor.labelColor` 这类语义色会按**当前**外观解析——深色外观下
    /// `labelColor` 是白色，配上白底就「白底白字」，墨迹检测完全失效。
    ///
    /// - Parameter body: 需要在浅色外观下执行的绘制代码。
    @MainActor
    static func withLightAppearance(_ body: () -> Void) {
        guard let aqua = NSAppearance(named: .aqua) else {
            body()
            return
        }
        aqua.performAsCurrentDrawingAppearance(body)
    }
}
