import Foundation
import LumiUI
import SwiftUI

/// 近 30 天的活跃度卡片：热力图与 token 曲线合成一张，接在空态提示流下面。
///
/// ## 为什么是「一张卡」而不是两块控件
///
/// 这两块图曾经各画各的：一个裸方块网格、一个带卡片底与坐标轴的折线图，
/// 中间只隔一条缝。读者会把它们当成两个独立控件，而不是「同一段时间的两种
/// 视图」。合成一张卡之后，二者共用一个圆角、一份填充、一条描边，中间的
/// 1pt 竖线只负责区分「哪一天有对话」与「那天用了多少 token」，
/// 而不是负责分开两个控件。
///
/// ## 视觉语言与中间的提示流同源
///
/// 填充 / 描边 / 阴影都取自 `theme.primary` 的低透明度档位，与提示胶囊
/// （`PromptSuggestionFlow`）同一族；卡片宽度也取 520pt，与胶囊流同宽居中。
/// 两处的左右边界因此完全对齐 —— 这是「它们属于同一块画面」最直接的信号。
struct ActivityFusionCard: View {
    @LumiTheme private var theme
    let model: EmptyStateActivityViewModel
    let range: ClosedRange<Date>
    /// 窄窗口下改为上下堆叠，由 `ActivityFooterLayout` 判定。
    let placesSideBySide: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: ActivityFusionCardMetrics.anchorSpacing) {
            anchor

            if placesSideBySide {
                // 并排时两块竖直居中：热力图窄而高，曲线宽而矮，
                // 居中对齐让整张卡读起来是一个整体而不是两个控件。
                HStack(alignment: .center, spacing: ActivityFusionCardMetrics.contentSpacing) {
                    heatmap
                    separator
                    sparkline
                }
            } else {
                VStack(alignment: .leading, spacing: ActivityFusionCardMetrics.contentSpacing) {
                    heatmap
                    sparkline
                        .frame(height: ActivityFusionCardMetrics.sparklineHeight)
                }
            }
        }
        .padding(.horizontal, ActivityFusionCardMetrics.horizontalPadding)
        .padding(.vertical, ActivityFusionCardMetrics.verticalPadding)
        .frame(maxWidth: ActivityFusionCardMetrics.maxWidth)
        .background {
            RoundedRectangle(cornerRadius: ActivityFusionCardMetrics.cornerRadius, style: .continuous)
                .fill(theme.primary.opacity(ActivityFusionCardMetrics.fillOpacity))
        }
        .overlay {
            RoundedRectangle(cornerRadius: ActivityFusionCardMetrics.cornerRadius, style: .continuous)
                .stroke(theme.primary.opacity(ActivityFusionCardMetrics.strokeOpacity), lineWidth: 1)
        }
        .shadow(color: theme.primary.opacity(0.05), radius: 10, y: 2)
        // - Important: 卡片是这一块区域里**唯一**可寻址的无障碍元素。
        //
        //   标识符会向下传播并覆盖子孙自己的标识符：外层容器一旦带标识符，
        //   卡片与卡内的锚点就都寻址不到（实测三者最终都变成同一个 id）。
        //   所以标识符只留在卡片上，外层容器不设标识符。
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(MessageListEmptyAccessibility.activityStripID)
    }

    // MARK: - 组成

    /// 顶部的一行锚点文案。
    ///
    /// 图上没有可读的坐标轴，数字必须由文字给出来；这一行同时取代了两块图
    /// 各自曾经的 caption —— 只有一行，不会在图下堆出两行噪声。
    ///
    /// - Important: 这一行**不设标识符**。
    ///
    ///   标识符会向下传播并覆盖子孙自己的标识符，而卡片已经是这一块区域里
    ///   唯一的可寻址元素。锚点靠它的**文字**定位（「… messages in the last
    ///   … days」），这恰好也是它要被断言的东西：数字还在不在。
    private var anchor: some View {
        HStack(spacing: 6) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(theme.primary.opacity(0.9))
                .accessibilityHidden(true)

            Text(anchorText)
                .font(.system(size: 11.5))
                .foregroundStyle(theme.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.9)
        }
    }

    private var heatmap: some View {
        AppActivityHeatmap(
            days: model.days.map {
                AppActivityHeatmapDay(
                    date: $0.date,
                    level: $0.level,
                    accessibilityLabel: $0.accessibilityLabel
                )
            },
            range: range,
            cellSize: 9,
            cellSpacing: 3,
            levelCount: 5,
            showsMonthLabels: false,
            showsWeekdayLabels: false,
            scrollsHorizontally: false,
            showsLegend: false
        )
    }

    /// 两块图之间的竖向分隔线：1pt、极淡，只做区分不做分区。
    private var separator: some View {
        Rectangle()
            .fill(theme.primary.opacity(0.14))
            .frame(width: 1, height: ActivityFusionCardMetrics.sparklineHeight)
    }

    private var sparkline: some View {
        ActivitySparkline(
            values: model.tokenDays.map { Double($0.count) },
            accessibilityLabel: pluginLocalization.string("Daily token consumption chart")
        )
        .frame(height: ActivityFusionCardMetrics.sparklineHeight)
    }

    // MARK: - 文案

    /// 「近 30 天有多少条消息」＋（有 token 时）「消耗了多少」。
    ///
    /// 查表与格式化分两步：`String(localized:)` 能从模块 bundle 里取到模板，
    /// 但没有带参数的格式化重载；而 `pluginLocalization.string` 只解析 key，
    /// 不接受格式参数。因此先取模板，再交给 `String(format:locale:)` 填值。
    private var anchorText: String {
        if model.hasTokenActivity {
            let format = String(
                localized: "%lld messages in the last %lld days · %@ tokens",
                bundle: .module
            )
            return String(
                format: format,
                locale: pluginLocalization.preferredLocale(),
                model.totalMessages ?? 0,
                EmptyStateActivityViewModel.windowDayCount,
                ActivityTokenFormat.compact(model.totalTokens ?? 0)
            )
        }

        let format = String(
            localized: "%lld messages in the last %lld days",
            bundle: .module
        )
        return String(
            format: format,
            locale: pluginLocalization.preferredLocale(),
            model.totalMessages ?? 0,
            EmptyStateActivityViewModel.windowDayCount
        )
    }
}

// MARK: - 尺寸

/// 活动卡的尺寸常量。
///
/// 抽成命名常量而不是散落的字面量：卡片的宽度基准必须与
/// `PromptSuggestionFlow` 的 520pt 保持一致，注释写在这里比写在使用处更容易
/// 被下一次改动的人看到。
enum ActivityFusionCardMetrics {
    /// 卡片最大宽度。与提示胶囊流（520pt）同宽，两者的左右边界因此对齐。
    static let maxWidth: CGFloat = 520
    /// 卡片左右内边距。
    static let horizontalPadding: CGFloat = 14
    /// 卡片上下内边距。
    static let verticalPadding: CGFloat = 12
    /// 圆角。与提示胶囊的胶囊形不同，卡片是「容器」而非「可点的东西」，
    /// 因此用小圆角而不是全圆。
    static let cornerRadius: CGFloat = 14
    /// 锚点文案与图形区之间的间距。
    static let anchorSpacing: CGFloat = 10
    /// 图形区内部两块图之间的间距。
    static let contentSpacing: CGFloat = 14
    /// 曲线高度。热力图 7 行格子高 81pt，曲线取 56pt：再高就过于抢眼，
    /// 再矮则看不出起伏。
    static let sparklineHeight: CGFloat = 56
    /// 卡片填充不透明度。低于胶囊的 12%，大块面积必须更淡才不会压过提示流。
    static let fillOpacity: Double = 0.055
    /// 卡片描边不透明度。
    static let strokeOpacity: Double = 0.16
}
