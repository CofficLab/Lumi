import LumiUI
import SwiftUI

/// 配额列表：按模型分组展示 5 小时窗口与本周配额的剩余量。
///
/// 每个模型一组，组内两张卡片并排（时段 / 本周），
/// 卡片只承载「主数值 + 状态 + 时间」三类信息，避免把接口字段逐行罗列成键值表。
struct TokenPlanQuotaList: View {
    @LumiTheme private var theme: any LumiUITheme

    let plans: [TokenPlanData]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(Array(plans.enumerated()), id: \.offset) { index, plan in
                if index > 0 {
                    Divider()
                        .padding(.vertical, 2)
                }
                modelSection(plan)
            }
        }
    }

    // MARK: - Model Section

    /// 单个模型分组：分组标题 + 时段 / 本周两张卡片。
    private func modelSection(_ plan: TokenPlanData) -> some View {
        let config = TokenPlanModelDisplayConfig.from(plan.modelName)

        return VStack(alignment: .leading, spacing: 8) {
            modelHeader(config)

            HStack(alignment: .top, spacing: 10) {
                quotaCard(periodDisplay(plan: plan, config: config, period: .interval))
                quotaCard(periodDisplay(plan: plan, config: config, period: .weekly))
            }
        }
    }

    /// 分组标题：图标 + 模型名，替代原先的「模型：xxx」键值行。
    private func modelHeader(_ config: TokenPlanModelDisplayConfig) -> some View {
        HStack(spacing: 5) {
            Image(systemName: config.iconName)
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(theme.textSecondary)

            Text(pluginLocalization.string(config.displayNameKey))
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(theme.textPrimary)
        }
    }

    // MARK: - Period Assembly

    /// 列表里的两个配额周期。
    enum Period: Sendable {
        case interval
        case weekly
    }

    /// 把一个周期的原始数据整理成卡片需要的展示数据。
    private func periodDisplay(
        plan: TokenPlanData,
        config: TokenPlanModelDisplayConfig,
        period: Period
    ) -> TokenPlanPeriodDisplay {
        switch period {
        case .interval:
            return TokenPlanPeriodDisplay(
                title: pluginLocalization.string(config.intervalTitleKey),
                metric: config.intervalMetric,
                percent: plan.remainingPercent,
                statusKey: plan.intervalStatusKey,
                isNormal: plan.intervalStatus == QuotaStatusCode.normal.rawValue,
                usage: plan.intervalUsage,
                total: plan.intervalTotal,
                remainingCount: plan.intervalRemainingCount,
                timeRangeText: plan.intervalTimeRangeCompact,
                resetText: resetText(plan.remainsTimeComponents)
            )
        case .weekly:
            return TokenPlanPeriodDisplay(
                title: pluginLocalization.string("Weekly Quota"),
                metric: config.weeklyMetric,
                percent: plan.weeklyRemainingPercent,
                statusKey: plan.weeklyStatusKey,
                isNormal: plan.weeklyStatus == QuotaStatusCode.normal.rawValue,
                usage: plan.weeklyUsage,
                total: plan.weeklyTotal,
                remainingCount: plan.weeklyRemainingCount,
                timeRangeText: plan.weeklyTimeRangeCompact,
                resetText: resetText(plan.weeklyRemainsTimeComponents)
            )
        }
    }

    /// 重置倒计时文案；缺少倒计时时返回 `nil`（卡片不显示该行）。
    private func resetText(_ components: ResetTimeComponents?) -> String? {
        guard let components else { return nil }
        return TokenPlanStatusLocalization.resetCountdownText(components)
    }

    /// 剩余比例 → 颜色：充足为绿、偏低为橙、告急为红；已耗尽一律为红。
    ///
    /// `ratio` 为 `nil` 表示该周期没有可比的比例（如不限次），按充足处理。
    private func tint(forRatio ratio: Double?, isNormal: Bool) -> Color {
        guard isNormal else { return theme.error }
        guard let ratio else { return theme.success }
        switch ratio {
        case 0.5...: return theme.success
        case 0.2..<0.5: return theme.warning
        default: return theme.error
        }
    }

    /// 单个周期 → 卡片。
    private func quotaCard(_ display: TokenPlanPeriodDisplay) -> some View {
        let isPercent = display.metric == .percent
        let progressRatio: Double? = isPercent
            ? Double(display.percent) / 100
            : (display.total > 0 ? Double(display.remainingCount) / Double(display.total) : nil)

        return TokenPlanQuotaCard(
            title: display.title,
            headline: isPercent ? "\(display.percent)" : "\(display.remainingCount)",
            unit: isPercent ? .percent : .calls,
            tint: tint(forRatio: progressRatio, isNormal: display.isNormal),
            statusText: pluginLocalization.string(display.statusKey),
            isNormal: display.isNormal,
            progressRatio: progressRatio,
            timeRangeText: display.timeRangeText,
            usageText: TokenPlanStatusLocalization.usageText(used: display.usage, total: display.total),
            resetText: display.resetText
        )
    }
}

// MARK: - Period Display

/// 一个配额周期的展示数据（已按展示口径换算完毕）。
struct TokenPlanPeriodDisplay {
    let title: String
    let metric: TokenPlanMetric
    let percent: Int
    let statusKey: String
    let isNormal: Bool
    let usage: Int
    let total: Int
    let remainingCount: Int
    let timeRangeText: String
    let resetText: String?
}

// MARK: - Preview

#if DEBUG
#Preview("Quota List") {
    TokenPlanQuotaList(plans: TokenPlanPreviewFixtures.allPlans)
        .frame(width: 392)
        .padding(14)
        .background(Color.white)
        .environment(\.colorScheme, .light)
        .inRootView()
}
#endif
