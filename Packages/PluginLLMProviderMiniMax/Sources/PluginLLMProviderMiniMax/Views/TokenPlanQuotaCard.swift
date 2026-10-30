import LumiUI
import SwiftUI

/// 主数值的单位样式。
///
/// 百分比紧贴数字（`68%`），调用次数作为略小的后缀（`3 次`），
/// 两者在卡片里的视觉重量保持一致。
enum TokenPlanQuotaUnit: Sendable {
    case percent
    case calls

    /// 单位文本。
    var text: String {
        switch self {
        case .percent: return "%"
        case .calls: return pluginLocalization.string("calls")
        }
    }

    /// 单位字号。
    var font: Font {
        switch self {
        case .percent: return .system(size: 13, weight: .semibold)
        case .calls: return .system(size: 11, weight: .medium)
        }
    }

    /// 与主数值之间的间距。
    var spacing: CGFloat {
        switch self {
        case .percent: return 0
        case .calls: return 2
        }
    }
}

/// 单个配额周期（5 小时窗口 / 本周配额）的剩余量卡片。
///
/// 卡片只负责排版：主数值、状态、进度条、时间段与重置倒计时。
/// 数值与文案由 ``TokenPlanQuotaList`` 组装后传入，视图本身不读数据模型。
struct TokenPlanQuotaCard: View {
    @LumiTheme private var theme: any LumiUITheme

    /// 周期标题，如「5 小时窗口」。
    let title: String
    /// 主数值文本，如 `68`。
    let headline: String
    /// 主数值单位。
    let unit: TokenPlanQuotaUnit
    /// 主数值与进度条的颜色（由剩余比例决定）。
    let tint: Color
    /// 状态文本，如「正常」。
    let statusText: String
    /// 状态是否为正常（决定状态圆点颜色）。
    let isNormal: Bool
    /// 剩余比例（0-1）；`nil` 表示不展示进度条。
    let progressRatio: Double?
    /// 时间段文本，如 `10/19 17:26 → 22:26`。
    let timeRangeText: String
    /// 调用次数文本，如 `已用 19 / 100`。
    let usageText: String
    /// 重置倒计时文本；`nil` 表示没有倒计时信息。
    let resetText: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            header
            headlineRow
            if let progressRatio {
                progressBar(ratio: progressRatio)
            }
            timeRangeRow
            metaRow
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            tint.opacity(0.08),
            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(tint.opacity(0.18), lineWidth: 1)
        )
    }
}

// MARK: - Rows

extension TokenPlanQuotaCard {

    /// 标题行：周期标题在左，状态圆点 + 文案在右。
    private var header: some View {
        HStack(spacing: 4) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(theme.textSecondary)
                .lineLimit(1)

            Spacer(minLength: 4)

            Circle()
                .fill(isNormal ? theme.success : theme.error)
                .frame(width: 5, height: 5)

            Text(statusText)
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(isNormal ? theme.success : theme.error)
                .lineLimit(1)
        }
    }

    /// 主数值行。
    private var headlineRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: unit.spacing) {
            Text(headline)
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundColor(tint)

            Text(unit.text)
                .font(unit.font)
                .foregroundColor(tint.opacity(0.75))
        }
        .lineLimit(1)
    }

    /// 剩余比例进度条。
    ///
    /// 自绘而非系统 `ProgressView`：紧凑卡片里系统样式偏重，且默认强调色
    /// 会盖掉主题色，这里用胶囊轨道精确控制高度（5pt）与配色。
    private func progressBar(ratio: Double) -> some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule(style: .continuous)
                    .fill(tint.opacity(0.18))
                Capsule(style: .continuous)
                    .fill(tint)
                    .frame(width: max(2, proxy.size.width * ratio))
            }
        }
        .frame(height: 5)
    }

    /// 时间段行。
    private var timeRangeRow: some View {
        HStack(spacing: 3) {
            Image(systemName: "clock")
                .font(.system(size: 8, weight: .medium))
                .foregroundColor(theme.textSecondary)

            Text(timeRangeText)
                .font(.system(size: 9))
                .monospacedDigit()
                .foregroundColor(theme.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }

    /// 底部信息行：调用次数在左，重置倒计时在右。
    private var metaRow: some View {
        HStack(spacing: 6) {
            Text(usageText)
                .font(.system(size: 9))
                .foregroundColor(theme.textSecondary)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer(minLength: 0)

            if let resetText {
                Text(resetText)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(theme.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .layoutPriority(1)
            }
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Quota Card - Percent") {
    TokenPlanQuotaCard(
        title: "5 小时窗口",
        headline: "68",
        unit: .percent,
        tint: .green,
        statusText: "正常",
        isNormal: true,
        progressRatio: 0.68,
        timeRangeText: "10/19 17:26 → 22:26",
        usageText: "不限次",
        resetText: "2 小时 32 分后重置"
    )
    .frame(width: 200)
    .padding()
    .background(Color.gray.opacity(0.15))
}
#endif
