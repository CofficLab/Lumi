import LumiKernel
import LumiUI
import SwiftUI

struct ProviderDailyTokenUsageCard: View {
    @LumiTheme private var theme

    let provider: LumiLLMProviderInfo
    let series: ProviderDailyTokenUsageSeries?
    let isLoading: Bool

    var body: some View {
        AppSettingsSection(title: "调用统计", subtitle: "最近 14 天每天的 token 用量", spacing: 12) {
            VStack(alignment: .leading, spacing: 12) {
                header
                chart
                footer
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(theme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(theme.divider, lineWidth: 0.5)
            )
        }
    }

    private var currentSeries: ProviderDailyTokenUsageSeries {
        series ?? ProviderDailyTokenUsageSeries(providerID: provider.id, points: [])
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Label(provider.displayName, systemImage: "chart.xyaxis.line")
                .font(.appCaptionEmphasized)
                .foregroundStyle(theme.textPrimary)

            Spacer(minLength: 0)

            if isLoading {
                ProgressView()
                    .controlSize(.small)
                    .scaleEffect(0.72)
            } else {
                Text("\(ModelSelectorFormatService.compactTokenCount(currentSeries.totalTokens)) tokens")
                    .font(.appCaptionEmphasized)
                    .monospacedDigit()
                    .foregroundStyle(theme.textPrimary)
                    .help("\(ModelSelectorFormatService.tokenCount(currentSeries.totalTokens)) tokens")
            }
        }
    }

    @ViewBuilder
    private var chart: some View {
        if currentSeries.points.isEmpty {
            emptyChart
        } else {
            ProviderDailyTokenLineChart(points: currentSeries.points)
                .frame(height: 128)
                .accessibilityLabel(accessibilitySummary)
        }
    }

    private var emptyChart: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(theme.primary.opacity(0.05))

            Text(isLoading ? "正在加载用量" : "最近 14 天暂无 token 记录")
                .font(.appCaption)
                .foregroundStyle(theme.textSecondary)
        }
        .frame(height: 128)
    }

    private var footer: some View {
        HStack(spacing: 12) {
            footerMetric("Input", value: currentSeries.inputTokens)
            footerMetric("Output", value: currentSeries.outputTokens)
            footerMetric("Peak", value: currentSeries.peakTokens)
            Spacer(minLength: 0)
        }
    }

    private func footerMetric(_ title: String, value: Int) -> some View {
        HStack(spacing: 4) {
            Text(title)
                .foregroundStyle(theme.textTertiary)
            Text(ModelSelectorFormatService.compactTokenCount(value))
                .monospacedDigit()
                .foregroundStyle(theme.textSecondary)
                .help(ModelSelectorFormatService.tokenCount(value))
        }
        .font(.appMicro)
    }

    private var accessibilitySummary: String {
        "\(provider.displayName) recent token usage, total \(currentSeries.totalTokens), peak \(currentSeries.peakTokens)"
    }
}

private struct ProviderDailyTokenLineChart: View {
    @LumiTheme private var theme

    let points: [ProviderDailyTokenUsagePoint]

    var body: some View {
        Canvas { context, size in
            guard !points.isEmpty, size.width > 0, size.height > 0 else { return }

            let values = points.map(\.totalTokens)
            let maxValue = max(values.max() ?? 0, 1)
            let inset = EdgeInsets(top: 14, leading: 12, bottom: 20, trailing: 12)
            let plotWidth = max(size.width - inset.leading - inset.trailing, 1)
            let plotHeight = max(size.height - inset.top - inset.bottom, 1)

            let chartPoints = points.enumerated().map { offset, point in
                let xRatio = points.count == 1 ? 0.5 : Double(offset) / Double(points.count - 1)
                let yRatio = Double(point.totalTokens) / Double(maxValue)
                return CGPoint(
                    x: inset.leading + plotWidth * xRatio,
                    y: inset.top + plotHeight * (1 - yRatio)
                )
            }

            drawGrid(in: &context, inset: inset, plotHeight: plotHeight, plotWidth: plotWidth)

            var fill = smoothedPath(points: chartPoints)
            fill.addLine(to: CGPoint(x: chartPoints.last?.x ?? inset.leading, y: inset.top + plotHeight))
            fill.addLine(to: CGPoint(x: chartPoints.first?.x ?? inset.leading, y: inset.top + plotHeight))
            fill.closeSubpath()
            context.fill(
                fill,
                with: .linearGradient(
                    Gradient(colors: [theme.primary.opacity(0.24), theme.primary.opacity(0.03)]),
                    startPoint: CGPoint(x: size.width / 2, y: inset.top),
                    endPoint: CGPoint(x: size.width / 2, y: inset.top + plotHeight)
                )
            )

            context.stroke(smoothedPath(points: chartPoints), with: .color(theme.primary), lineWidth: 2.2)

            if let last = chartPoints.last {
                context.fill(
                    Path(ellipseIn: CGRect(x: last.x - 3.5, y: last.y - 3.5, width: 7, height: 7)),
                    with: .color(theme.primary)
                )
                context.stroke(
                    Path(ellipseIn: CGRect(x: last.x - 6, y: last.y - 6, width: 12, height: 12)),
                    with: .color(theme.primary.opacity(0.28)),
                    lineWidth: 2
                )
            }
        }
        .background(theme.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(theme.primary.opacity(0.12), lineWidth: 1)
        )
        .overlay(alignment: .bottomLeading) {
            dateLabel(points.first?.day)
                .padding(.leading, 10)
                .padding(.bottom, 4)
        }
        .overlay(alignment: .bottomTrailing) {
            dateLabel(points.last?.day)
                .padding(.trailing, 10)
                .padding(.bottom, 4)
        }
        .overlay {
            HStack(spacing: 0) {
                ForEach(points) { point in
                    Color.clear
                        .contentShape(Rectangle())
                        .help(tooltip(for: point))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
    }

    private func drawGrid(
        in context: inout GraphicsContext,
        inset: EdgeInsets,
        plotHeight: CGFloat,
        plotWidth: CGFloat
    ) {
        var grid = Path()
        for step in 0...2 {
            let y = inset.top + plotHeight * Double(step) / 2
            grid.move(to: CGPoint(x: inset.leading, y: y))
            grid.addLine(to: CGPoint(x: inset.leading + plotWidth, y: y))
        }
        context.stroke(grid, with: .color(theme.divider.opacity(0.7)), lineWidth: 1)
    }

    private func dateLabel(_ date: Date?) -> some View {
        Text(date.map(Self.dateFormatter.string(from:)) ?? "")
            .font(.system(size: 9, weight: .regular))
            .foregroundStyle(theme.textTertiary)
            .monospacedDigit()
    }

    private func tooltip(for point: ProviderDailyTokenUsagePoint) -> String {
        "\(Self.tooltipDateFormatter.string(from: point.day)) · total \(ModelSelectorFormatService.tokenCount(point.totalTokens)) tokens (in \(ModelSelectorFormatService.tokenCount(point.inputTokens)) / out \(ModelSelectorFormatService.tokenCount(point.outputTokens)))"
    }

    private func smoothedPath(points: [CGPoint]) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: first)

        guard points.count > 1 else {
            path.addLine(to: first)
            return path
        }

        for index in 0..<(points.count - 1) {
            let current = points[index]
            let next = points[index + 1]
            let previous = index > 0 ? points[index - 1] : current
            let afterNext = index + 2 < points.count ? points[index + 2] : next
            let control1 = CGPoint(
                x: current.x + (next.x - previous.x) / 6,
                y: current.y + (next.y - previous.y) / 6
            )
            let control2 = CGPoint(
                x: next.x - (afterNext.x - current.x) / 6,
                y: next.y - (afterNext.y - current.y) / 6
            )
            path.addCurve(to: next, control1: control1, control2: control2)
        }

        return path
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"
        return formatter
    }()

    private static let tooltipDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
}
