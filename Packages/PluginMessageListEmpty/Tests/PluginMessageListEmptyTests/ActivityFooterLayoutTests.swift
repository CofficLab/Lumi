import CoreGraphics
import Testing
@testable import PluginMessageListEmpty

/// 活动卡「宽度够就并排」的阈值契约。
///
/// 这是活动卡布局里唯一可单测的部分：真正的判定依赖运行时测量到的宽度
/// （曲线建在 `GeometryReader` 上，`ViewThatFits` 认不出「太窄」，
/// 所以 `ActivityFooterView` 只能量出可用宽度再比阈值）。阈值一旦被随手
/// 改大改小，界面上就会出现两种退化：窄窗口里曲线被挤成一团，或者宽窗口里
/// 两块图莫名其妙地上下排布 —— 两者都不会让编译失败，只能靠这条用例守住。
@Test func activityCardOnlyGoesSideBySideWhenTheChartKeepsItsMinimumWidth() {
    let threshold = ActivityFooterLayout.sideBySideMinWidth

    // 阈值必须正好由三块组成：热力图 + 间距 + 分隔线 + 间距 + 曲线最小宽度。
    #expect(
        ActivityFooterLayout.sideBySideInnerWidth
            == ActivityFooterLayout.heatmapWidth
            + ActivityFooterLayout.contentSpacing * 2
            + ActivityFooterLayout.separatorWidth
            + ActivityFooterLayout.minSparklineWidth
    )
    #expect(
        threshold
            == ActivityFooterLayout.cardHorizontalPadding * 2
            + ActivityFooterLayout.sideBySideInnerWidth
    )

    // 阈值本身以及常见的宽窗口都并排。
    #expect(ActivityFooterLayout.usesSideBySideLayout(availableWidth: threshold))
    #expect(ActivityFooterLayout.usesSideBySideLayout(availableWidth: 620))

    // 差 1pt 就退回上下排布：边界必须是闭合的「够用才算」。
    #expect(!ActivityFooterLayout.usesSideBySideLayout(availableWidth: threshold - 1))

    // 首帧宽度尚未测量到（0），宁可先上下排布也不要让内容溢出。
    #expect(!ActivityFooterLayout.usesSideBySideLayout(availableWidth: 0))
}

/// 卡片封顶之后，槽位再宽也不该改变排布。
///
/// 活动卡的最大宽度是 520pt（与提示胶囊流同宽），因此一个 2000pt 宽的窗口
/// 与一个 520pt 宽的窗口对卡片而言是同一件事。若判定误用槽位宽度，
/// 卡片在超宽窗口里会试图把曲线拉得比设计值更长，两侧留白也就不对称了。
@Test func activityCardLayoutIgnoresWidthBeyondTheCardCap() {
    let cap = ActivityFooterLayout.cardMaxWidth

    #expect(ActivityFooterLayout.usesSideBySideLayout(availableWidth: cap))
    #expect(
        ActivityFooterLayout.usesSideBySideLayout(availableWidth: cap)
            == ActivityFooterLayout.usesSideBySideLayout(availableWidth: cap * 4)
    )
}
