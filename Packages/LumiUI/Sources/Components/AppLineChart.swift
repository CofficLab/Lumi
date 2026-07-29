import SwiftUI

/// A lightweight line chart with a point tooltip for settings views.
public struct AppLineChartPoint: Identifiable, Equatable, Sendable {
    public let id: Date
    public let date: Date
    public let value: Double

    public init(date: Date, value: Double) {
        self.id = date
        self.date = date
        self.value = value
    }
}

/// Reusable line chart for time-series settings data.
public struct AppLineChart: View {
    @LumiTheme private var theme

    public let points: [AppLineChartPoint]
    public let valueLabel: (Double) -> String
    public let accessibilityLabel: String

    @State private var hoveredIndex: Int?

    public init(
        points: [AppLineChartPoint],
        accessibilityLabel: String = "Line chart",
        valueLabel: @escaping (Double) -> String = { String(format: "%.0f", $0) }
    ) {
        self.points = points
        self.accessibilityLabel = accessibilityLabel
        self.valueLabel = valueLabel
    }

    public var body: some View {
        GeometryReader { proxy in
            let inset = EdgeInsets(top: 14, leading: 14, bottom: 24, trailing: 14)
            let plotWidth = max(proxy.size.width - inset.leading - inset.trailing, 1)
            let plotHeight = max(proxy.size.height - inset.top - inset.bottom, 1)
            let maxValue = max(points.map(\.value).max() ?? 0, 1)
            let chartPoints = points.enumerated().map { index, point in
                CGPoint(
                    x: inset.leading + plotWidth * (points.count == 1 ? 0.5 : CGFloat(index) / CGFloat(points.count - 1)),
                    y: inset.top + plotHeight * (1 - CGFloat(point.value / maxValue))
                )
            }

            ZStack(alignment: .topLeading) {
                Canvas { context, size in
                    guard !points.isEmpty, size.width > 0, size.height > 0 else { return }

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

                if let hoveredIndex,
                   points.indices.contains(hoveredIndex),
                   chartPoints.indices.contains(hoveredIndex) {
                    let point = chartPoints[hoveredIndex]
                    let dataPoint = points[hoveredIndex]

                    Path { path in
                        path.move(to: CGPoint(x: point.x, y: inset.top))
                        path.addLine(to: CGPoint(x: point.x, y: inset.top + plotHeight))
                    }
                    .stroke(theme.primary.opacity(0.35), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))

                    Circle()
                        .fill(theme.primary)
                        .frame(width: 9, height: 9)
                        .overlay(Circle().stroke(theme.background, lineWidth: 2))
                        .position(point)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(Self.tooltipDateFormatter.string(from: dataPoint.date))
                            .font(.system(size: 10, weight: .medium))
                        Text("X: \(Self.tooltipDateFormatter.string(from: dataPoint.date))")
                            .font(.system(size: 10))
                            .foregroundStyle(theme.textSecondary)
                        Text("Y: \(valueLabel(dataPoint.value))")
                            .font(.system(size: 11, weight: .semibold))
                            .monospacedDigit()
                    }
                    .padding(8)
                    .foregroundStyle(theme.textPrimary)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(theme.divider, lineWidth: 0.5)
                    }
                    .shadow(radius: 3, y: 1)
                    .fixedSize()
                    .position(x: min(max(point.x, 78), max(proxy.size.width - 78, 78)), y: 38)
                }
            }
            .contentShape(Rectangle())
            .onContinuousHover { phase in
                switch phase {
                case let .active(location):
                    guard !points.isEmpty else { return }
                    let ratio = (location.x - inset.leading) / plotWidth
                    let rawIndex = Int((ratio * CGFloat(points.count - 1)).rounded())
                    hoveredIndex = min(max(rawIndex, 0), points.count - 1)
                case .ended:
                    hoveredIndex = nil
                }
            }
        }
        .background(theme.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(theme.primary.opacity(0.12), lineWidth: 1)
        }
        .overlay(alignment: .bottomLeading) {
            dateLabel(points.first?.date)
                .padding(.leading, 12)
                .padding(.bottom, 5)
        }
        .overlay(alignment: .bottomTrailing) {
            dateLabel(points.last?.date)
                .padding(.trailing, 12)
                .padding(.bottom, 5)
        }
        .accessibilityLabel(accessibilityLabel)
    }

    private func dateLabel(_ date: Date?) -> some View {
        Text(date.map(Self.axisDateFormatter.string(from:)) ?? "")
            .font(.system(size: 9))
            .foregroundStyle(theme.textTertiary)
            .monospacedDigit()
    }

    private static let axisDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"
        return formatter
    }()

    private static let tooltipDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}
