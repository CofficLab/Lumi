import AppKit
import LumiUI
import ProviderMessage

/// 输入框内联 chip 的配色。
///
/// 消息列表里的 chip 由 SwiftUI 按 LumiUI 主题绘制，输入框这一侧由 AppKit 绘制。
/// 两边若各写一份颜色，久而久之就会漂移：标题一个色、统计信息一个色、图标又是
/// 一个色；更糟的是悬停时改用 `NSColor.controlAccentColor`，胶囊会直接变成
/// 系统强调色（青绿），与消息列表里那颗安静的灰胶囊完全不是一回事。
///
/// 故颜色统一由 SwiftUI 层按主题注入，两侧共用同一套色。
///
/// - Note: `NSColor` 未标注 `Sendable`，但本类型只持有不可变的颜色值，
///   故按 `@unchecked Sendable` 处理。
public struct PasteChipPalette: @unchecked Sendable {
    /// 标题（正文主色）。
    public var title: NSColor
    /// 统计信息（比标题弱一级）。
    public var detail: NSColor
    /// 图标。
    public var icon: NSColor
    /// 胶囊底色。
    public var fill: NSColor
    /// 胶囊描边色。
    public var stroke: NSColor
    /// 悬停时的底色。
    public var hoverFill: NSColor
    /// 悬停时的描边色。
    public var hoverStroke: NSColor

    /// 按 LumiUI 主题组装配色。
    ///
    /// 各色的语义与消息列表里的 chip 一一对应：标题用主色、统计信息用三级色、
    /// 图标用二级色，胶囊底色与描边由主色压低透明度得到。
    public init(
        title: NSColor,
        detail: NSColor,
        icon: NSColor,
        fill: NSColor,
        stroke: NSColor,
        hoverFill: NSColor,
        hoverStroke: NSColor
    ) {
        self.title = title
        self.detail = detail
        self.icon = icon
        self.fill = fill
        self.stroke = stroke
        self.hoverFill = hoverFill
        self.hoverStroke = hoverStroke
    }

    /// 按 LumiUI 主题组装配色。
    ///
    /// 各色的语义与消息列表里的 chip 一一对应：标题用主色、统计信息用三级色、
    /// 图标用二级色，胶囊底色与描边由主色压低透明度得到。
    public init(theme: any LumiUITheme) {
        self.init(
            title: NSColor(theme.textPrimary),
            detail: NSColor(theme.textTertiary),
            icon: NSColor(theme.textSecondary),
            fill: NSColor(theme.textPrimary.opacity(CollapsedContentChipStyle.fillOpacity)),
            stroke: NSColor(theme.textPrimary.opacity(CollapsedContentChipStyle.strokeOpacity)),
            hoverFill: NSColor(theme.textPrimary.opacity(CollapsedContentChipStyle.hoverFillOpacity)),
            hoverStroke: NSColor(theme.textPrimary.opacity(CollapsedContentChipStyle.hoverStrokeOpacity))
        )
    }

    /// 未注入主题时的兜底配色（AppKit 标准色）。
    ///
    /// 仅供没有主题上下文的路径使用；正常运行时由 ``ComposerView`` 按主题注入。
    public static let fallback = PasteChipPalette(
        title: NSColor.labelColor,
        detail: NSColor.tertiaryLabelColor,
        icon: NSColor.secondaryLabelColor,
        fill: NSColor.labelColor.withAlphaComponent(CollapsedContentChipStyle.fillOpacity),
        stroke: NSColor.labelColor.withAlphaComponent(CollapsedContentChipStyle.strokeOpacity),
        hoverFill: NSColor.labelColor.withAlphaComponent(CollapsedContentChipStyle.hoverFillOpacity),
        hoverStroke: NSColor.labelColor.withAlphaComponent(CollapsedContentChipStyle.hoverStrokeOpacity)
    )
}
