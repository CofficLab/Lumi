import LumiUI
import SwiftUI

/// Rail 底部 token 趋势视图。
///
/// 紧凑的折线图 + 标题 + 总量摘要，适配 Rail 侧边栏宽度。
struct RailTokenTrendView: View {
    @ObservedObject private var viewModel: RailTokenTrendViewModel
    @LumiTheme private var theme

    init(viewModel: RailTokenTrendViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            header
            chart
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - 私有视图

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(pluginLocalization.string("Token Trend"))
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(theme.textSecondary)

            Spacer()

            if viewModel.totalTokens > 0 {
                Text(pluginLocalization.string("30d: %@").replacingOccurrences(
                    of: "%@",
                    with: TokenCountFormat.compact(viewModel.totalTokens)
                ))
                .font(.system(size: 10, weight: .regular))
                .foregroundStyle(theme.textTertiary)
                .monospacedDigit()
            }
        }
    }

    @ViewBuilder
    private var chart: some View {
        if viewModel.days.allSatisfy({ $0.tokens == 0 }) {
            emptyChart
        } else {
            AppLineChart(
                points: viewModel.days.map { AppLineChartPoint(date: $0.date, value: Double($0.tokens)) },
                accessibilityLabel: pluginLocalization.string("Token usage trend chart"),
                valueLabel: { TokenCountFormat.compact(Int($0)) }
            )
        }
    }

    private var emptyChart: some View {
        RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(theme.primary.opacity(0.05))
            .overlay(
                Text(pluginLocalization.string("No token usage yet"))
                    .font(.system(size: 11))
                    .foregroundStyle(theme.textTertiary)
            )
    }
}
