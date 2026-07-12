import SwiftUI
import Charts
import LumiUI
import LumiCoreKit

/// Line chart view displaying daily token consumption over time.
struct TokenLineChartView: View {
    // MARK: - Properties

    let data: [ActivityDayToken]

    // MARK: - Constants

    private let lineColor = Color(hex: "6db0f0")
    private let areaGradient = LinearGradient(
        colors: [
            Color(hex: "6db0f0").opacity(0.3),
            Color(hex: "6db0f0").opacity(0.05)
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Title
            HStack {
                Text(LumiPluginLocalization.string("Token Usage", bundle: .module))
                    .font(.appBody)
                    .bold()
                Spacer()
                if let total = totalTokens {
                    Text(formatNumber(total))
                        .font(.appCaption)
                        .foregroundColor(.secondary)
                }
            }

            // Chart
            chartContent
                .frame(height: 150)
        }
    }

    // MARK: - Chart

    @ViewBuilder
    private var chartContent: some View {
        if data.isEmpty {
            emptyState
        } else {
            Chart(data) { day in
                LineMark(
                    x: .value("Date", day.date),
                    y: .value("Tokens", day.totalTokens)
                )
                .foregroundStyle(lineColor)
                .lineStyle(StrokeStyle(lineWidth: 2))

                AreaMark(
                    x: .value("Date", day.date),
                    y: .value("Tokens", day.totalTokens)
                )
                .foregroundStyle(areaGradient)
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 5))
            }
            .chartYAxis {
                AxisMarks(position: .leading)
            }
            .chartYScale(domain: 0...maxYValue)
        }
    }

    // MARK: - Helpers

    private var emptyState: some View {
        Text(LumiPluginLocalization.string("No data", bundle: .module))
            .font(.appBody)
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var totalTokens: Int? {
        let total = data.reduce(0) { $0 + $1.totalTokens }
        return total > 0 ? total : nil
    }

    private var maxYValue: Int {
        let maxTokens = data.map(\.totalTokens).max() ?? 0
        // Add 10% padding to the top
        return max(100, Int(Double(maxTokens) * 1.1))
    }

    private func formatNumber(_ value: Int) -> String {
        if value >= 1_000_000 {
            return String(format: "%.1fM", Double(value) / 1_000_000)
        } else if value >= 1_000 {
            return String(format: "%.1fK", Double(value) / 1_000)
        } else {
            return String(value)
        }
    }
}

// MARK: - Preview

#Preview("With Data") {
    let sampleData: [ActivityDayToken] = {
        let cal = Calendar.current
        let today = Date()
        return (0..<30).compactMap { offset -> ActivityDayToken? in
            guard let date = cal.date(byAdding: .day, value: -offset, to: today) else { return nil }
            return ActivityDayToken(
                date: date,
                totalTokens: Int.random(in: 0...5000)
            )
        }.reversed()
    }()
    TokenLineChartView(data: sampleData)
}

#Preview("Empty") {
    TokenLineChartView(data: [])
}
