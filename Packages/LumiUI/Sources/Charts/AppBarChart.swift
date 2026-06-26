import SwiftUI

/// Compact vertical bar chart for pre-formatted presentation data.
public struct AppBarChart: View {
    @LumiTheme private var theme

    public let data: AppBarChartData

    private static let chartHeight: CGFloat = 38
    private static let barMinHeight: CGFloat = 2

    public init(data: AppBarChartData) {
        self.data = data
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            header
            bars
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(data.accessibilitySummary)
    }

    private var header: some View {
        HStack(spacing: 6) {
            Image(systemName: "chart.bar")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(theme.textSecondary)

            Text(data.title)
                .font(.system(size: 11, weight: .regular))
                .foregroundColor(theme.textSecondary)

            Text(data.totalText)
                .font(.system(size: 11, weight: .medium))
                .monospacedDigit()
                .foregroundColor(theme.textSecondary)

            Spacer(minLength: 0)

            if let peakText = data.peakText {
                Text(peakText)
                    .font(.system(size: 10, weight: .regular))
                    .monospacedDigit()
                    .foregroundColor(theme.textTertiary)
            }
        }
    }

    private var bars: some View {
        GeometryReader { proxy in
            let peak = max(data.bars.map(\.value).max() ?? 0, 1)
            let spacing: CGFloat = max(1, proxy.size.width / CGFloat(max(data.bars.count * 6, 1)))
            let barWidth = max(2, (proxy.size.width - spacing * CGFloat(data.bars.count - 1)) / CGFloat(max(data.bars.count, 1)))

            HStack(alignment: .bottom, spacing: spacing) {
                ForEach(data.bars.indices, id: \.self) { index in
                    let bar = data.bars[index]
                    let ratio = CGFloat(bar.value) / CGFloat(peak)
                    let height = max(Self.barMinHeight, ratio * proxy.size.height)

                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(barColor(for: bar))
                        .frame(width: barWidth, height: height)
                        .help(bar.tooltip)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
        .frame(height: Self.chartHeight)
    }

    private func barColor(for bar: AppBarChartData.Bar) -> Color {
        if bar.isHighlighted {
            return theme.primary
        }
        return bar.value > 0 ? theme.primary.opacity(0.45) : theme.primary.opacity(0.15)
    }
}
