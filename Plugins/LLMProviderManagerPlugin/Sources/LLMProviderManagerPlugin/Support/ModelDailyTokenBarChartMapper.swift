import Foundation
import LumiKernel
import LumiUI

public enum ModelDailyTokenBarChartMapper {
    public static func chartData(from dailyUsage: [String: ModelDailyTokenSeries]) -> AppBarChartData {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none

        let allBuckets = dailyUsage.values.flatMap { $0.buckets }
        guard let firstDay = allBuckets.map(\.day).min(),
              let lastDay = allBuckets.map(\.day).max() else {
            return emptyChartData()
        }

        let calendar = Calendar.current
        let dayCount = calendar.dateComponents([.day], from: firstDay, to: lastDay).day ?? 0
        let totalDays = dayCount + 1

        var aggregatedData: [Date: (input: Int, output: Int)] = [:]
        for bucket in allBuckets {
            let day = calendar.startOfDay(for: bucket.day)
            let existing = aggregatedData[day] ?? (0, 0)
            aggregatedData[day] = (existing.input + bucket.inputTokens, existing.output + bucket.outputTokens)
        }

        let title = String(localized: "Last \(totalDays) days")

        var bars: [AppBarChartData.Bar] = []
        var totalTokens = 0
        var peakTokens = 0

        for dayOffset in 0..<totalDays {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: firstDay) else { continue }
            let startOfDay = calendar.startOfDay(for: day)
            let usage = aggregatedData[startOfDay] ?? (0, 0)
            let dayTotal = usage.input + usage.output

            totalTokens += dayTotal
            peakTokens = max(peakTokens, dayTotal)

            let isHighlighted = dayOffset == totalDays - 1
            let tooltip = String(
                localized: "\(formatter.string(from: day)) · \(ModelSelectorFormatService.tokenCount(dayTotal)) tokens (in \(ModelSelectorFormatService.tokenCount(usage.input)) / out \(ModelSelectorFormatService.tokenCount(usage.output)))"
            )

            bars.append(AppBarChartData.Bar(value: dayTotal, isHighlighted: isHighlighted, tooltip: tooltip))
        }

        let totalText = ModelSelectorFormatService.tokenCount(totalTokens)
        let peakText = peakTokens > 0 ? String(localized: "peak \(ModelSelectorFormatService.tokenCount(peakTokens))") : nil

        let accessibilitySummary = String(
            localized: "\(title), total \(totalText) tokens, peak \(ModelSelectorFormatService.tokenCount(peakTokens))"
        )

        return AppBarChartData(
            title: title,
            totalText: totalText,
            peakText: peakText,
            bars: bars,
            accessibilitySummary: accessibilitySummary
        )
    }

    public static func emptyChartData() -> AppBarChartData {
        let title = String(localized: "No Usage Data")
        return AppBarChartData(
            title: title,
            totalText: "0",
            peakText: nil,
            bars: [],
            accessibilitySummary: title
        )
    }

    public static func chartData(from series: ModelDailyTokenSeries) -> AppBarChartData {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none

        let title = String(localized: "Last \(series.buckets.count) days")
        let totalText = ModelSelectorFormatService.tokenCount(series.totalTokens)
        let peakText: String? = series.peakTokens > 0
            ? String(localized: "peak \(ModelSelectorFormatService.tokenCount(series.peakTokens))")
            : nil

        let bars = series.buckets.enumerated().map { index, bucket in
            AppBarChartData.Bar(
                value: bucket.totalTokens,
                isHighlighted: index == series.buckets.indices.last,
                tooltip: String(
                    localized: "\(formatter.string(from: bucket.day)) · \(ModelSelectorFormatService.tokenCount(bucket.totalTokens)) tokens (in \(ModelSelectorFormatService.tokenCount(bucket.inputTokens)) / out \(ModelSelectorFormatService.tokenCount(bucket.outputTokens)))"
                )
            )
        }

        let accessibilitySummary = String(
            localized: "\(title), total \(totalText) tokens, peak \(ModelSelectorFormatService.tokenCount(series.peakTokens))"
        )

        return AppBarChartData(
            title: title,
            totalText: totalText,
            peakText: peakText,
            bars: bars,
            accessibilitySummary: accessibilitySummary
        )
    }
}
