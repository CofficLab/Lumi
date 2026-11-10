import CoreGraphics
import Foundation

/// 折叠块 chip 的共享视觉规格。
///
/// 同一段折叠内容会出现在两个地方：输入框里作为内联 chip（AppKit
/// `NSTextAttachment`），消息列表里作为独立胶囊（SwiftUI）。两处由不同的
/// 技术栈绘制，样式一旦各写一份就会慢慢漂移——输入框里的 chip 显得又大又
/// 沉、消息列表里的又轻又小，正是这么来的。
///
/// 故所有尺寸只在这里定义一次，两边各自引用。
public enum CollapsedContentChipStyle {
    /// 胶囊圆角。
    ///
    /// 取 4pt：芯片高度约 14.7pt，8pt 会让它变成全圆胶囊；
    /// 4pt 只给四个角一点轻微弧度，视觉更轻、与正文更协调。
    public static let cornerRadius: CGFloat = 4

    /// 胶囊左右内边距。
    public static let horizontalPadding: CGFloat = 10

    /// 图标尺寸。
    public static let iconSize: CGFloat = 11

    /// 图标与标题之间的间距。
    public static let iconSpacing: CGFloat = 6

    /// 标题与统计信息之间的间距。
    public static let detailSpacing: CGFloat = 6

    /// 消息列表独立胶囊的标题字号。输入框的内联 chip 使用正文字号。
    public static let titleSize: CGFloat = 12

    /// 统计信息字号。比标题小一级，用次级色，与标题拉开层次。
    public static let detailSize: CGFloat = 10

    /// 胶囊底色不透明度。
    public static let fillOpacity: CGFloat = 0.06

    /// 胶囊描边不透明度。
    public static let strokeOpacity: CGFloat = 0.12

    /// 胶囊描边宽度。
    ///
    /// 两侧共用同一个宽度：输入框侧是 AppKit 的 `NSBezierPath.lineWidth`，
    /// 消息列表侧是 SwiftUI 的 `strokeBorder(_:lineWidth:)`。描边宽度不同
    /// 会让同一个胶囊看起来一边更「实」、一边更「虚」。
    public static let strokeWidth: CGFloat = 1

    /// 悬停时的胶囊底色不透明度。
    ///
    /// 悬停必须比常态**更明显**，但不能用系统强调色：强调色是用户设定的
    /// 品牌色（青绿、紫色……），用它画 chip 会让输入框里的胶囊与消息列表里
    /// 那颗安静的灰胶囊完全不是一回事。改为同色系加深，语义统一。
    public static let hoverFillOpacity: CGFloat = 0.10

    /// 悬停时的胶囊描边不透明度。
    public static let hoverStrokeOpacity: CGFloat = 0.24

    /// 胶囊最大宽度。超出时截断标题而不是无限拉长。
    public static let maximumWidth: CGFloat = 320

    /// 行内 chip（输入框）的上下内边距。
    ///
    /// 这个内边距是**相对正文那一行的字形墨迹**加的：胶囊的高度取正文
    /// 墨迹高再加上下各一个内边距，于是胶囊上沿与正文的字顶齐平、下沿与
    /// 正文的字底齐平——chip 看起来是「长在这一行字里」。
    ///
    /// 取 1pt：正文 15pt 的墨迹高约 12.7pt，加上下各 1pt 得 14.7pt，
    /// 稳稳落在 18pt 的行盒里；再加就会溢出到相邻行。
    ///
    /// 比独立胶囊小得多：行内 chip 必须待在文字行里，撑到独立胶囊那么高
    /// 会溢出行盒、压到相邻行。
    public static let inlineVerticalPadding: CGFloat = 1

    /// 独立胶囊（消息列表）的上下内边距。
    public static let standaloneVerticalPadding: CGFloat = 6

    /// 标题与统计信息之间的分隔符。
    ///
    /// 旧消息的 metadata 里只有一个拼好的标题串（「粘贴的文本 · 13,253 字 ·
    /// 75 行」）。渲染层按这个分隔符拆出标题与统计信息，好让旧消息也能
    /// 呈现新的两段式排版。
    public static let separator = " · "

    /// 把拼好的标题串拆成「标题」与「统计信息」两段。
    ///
    /// - 只按**第一个**分隔符拆：统计信息本身也含分隔符（「13,253 字 · 75
    ///   行」），拆成三段就错了。
    /// - 没有分隔符时整串都是标题（如代码编辑器送来的文件名 chip）。
    public static func split(title: String) -> (label: String, detail: String?) {
        guard let range = title.range(of: separator) else {
            return (title, nil)
        }
        let label = String(title[..<range.lowerBound])
        let detail = String(title[range.upperBound...])
        return (label, detail.isEmpty ? nil : detail)
    }
}
