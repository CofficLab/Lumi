import LumiUI
import SwiftUI

struct HTTPExchangeDailyCountChart: View {
    @LumiTheme private var theme

    let series: HTTPExchangeDailyCountSeries

    var body: some View {
        Canvas { context, size in
            guard size.width > 0, size.height > 0, !series.points.isEmpty else { return }

            let inset = EdgeInsets(top: 14, leading: 14, bottom: 24, trailing: 14)
            let plotWidth = max(size.width - inset.leading - inset.trailing, 1)
            let plotHeight = max(size.height - inset.top - inset.bottom, 1)
            let maxCount = max(series.peakCount, 1)
            let chartPoints = series.points.enumerated().map { index, point in
                let xRatio = series.points.count == 1 ? 0.5 : Double(index) / Double(series.points.count - 1)
                let yRatio = Double(point.count) / Double(maxCount)
                return CGPoint(
                    x: inset.leading + plotWidth * xRatio,
                    y: inset.top + plotHeight * (1 - yRatio)
                )
            }

            var grid = Path()
            for step in 0...2 {
                let y = inset.top + plotHeight * CGFloat(step) / 2
                grid.move(to: CGPoint(x: inset.leading, y: y))
                grid.addLine(to: CGPoint(x: inset.leading + plotWidth, y: y))
            }
            context.stroke(grid, with: .color(theme.divider.opacity(0.7)), lineWidth: 1)

            var line = Path()
            if let first = chartPoints.first {
                line.move(to: first)
                for point in chartPoints.dropFirst() {
                    line.addLine(to: point)
                }
            }
            context.stroke(line, with: .color(theme.primary), lineWidth: 2.2)

            for point in chartPoints {
                context.fill(
                    Path(ellipseIn: CGRect(x: point.x - 3, y: point.y - 3, width: 6, height: 6)),
                    with: .color(theme.primary)
                )
            }
        }
        .background(theme.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(theme.primary.opacity(0.12), lineWidth: 1)
        }
        .overlay(alignment: .bottomLeading) {
            dateLabel(series.points.first?.day)
                .padding(.leading, 12)
                .padding(.bottom, 5)
        }
        .overlay(alignment: .bottomTrailing) {
            dateLabel(series.points.last?.day)
                .padding(.trailing, 12)
                .padding(.bottom, 5)
        }
        .accessibilityLabel("Daily HTTP request count chart")
        .accessibilityValue("Peak (series.peakCount), total (series.totalCount)")
    }

    private func dateLabel(_ date: Date?) -> some View {
        Text(date.map(Self.dateFormatter.string(from:)) ?? "")
            .font(.system(size: 9))
            .foregroundStyle(theme.textTertiary)
            .monospacedDigit()
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"
        return formatter
    }()
}
