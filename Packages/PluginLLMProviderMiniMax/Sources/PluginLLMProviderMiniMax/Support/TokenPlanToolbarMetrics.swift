import SwiftUI

/// 工具栏 chip 尺寸常量（与其它工具栏 chip 插件保持一致）。
enum TokenPlanToolbarMetrics {
    static let chipIconSize: CGFloat = 10
    static let chipTextSize: CGFloat = 10
    static let chipTextWeight: Font.Weight = .medium
    static let chipSpacing: CGFloat = 3
    static let chipHorizontalPadding: CGFloat = 6
    static let chipVerticalPadding: CGFloat = 3
    static let chipCornerRadius: CGFloat = 5

    /// 定时轮询间隔：只用于推进 TTL 判定，真实请求受 ViewModel 的 5 分钟 TTL 抑制。
    static let pollInterval: TimeInterval = 60

    /// 详情面板宽度：两张配额卡片并排时需要足够空间容纳时间段文本。
    static let popoverWidth: CGFloat = 420
}
