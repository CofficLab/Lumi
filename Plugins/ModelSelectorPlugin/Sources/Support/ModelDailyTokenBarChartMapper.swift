import Foundation
import LumiCoreKit
import LumiCoreKit
import LumiUI

enum ModelDailyTokenBarChartMapper {
    static func chartData(from dailyUsage: [String: ModelDailyTokenSeries]) -> AppBarChartData {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none

        // 按日期聚合所有模型/供应商的 token 用量
        let allBuckets = dailyUsage.values.flatMap { $0.buckets }
        guard let firstDay = allBuckets.map(\.day).min(),
              let lastDay = allBuckets.map(\.day).max() else {
            return emptyChartData()
        }

        let calendar = Calendar.current
        let dayCount = calendar.dateComponents([.day], from: firstDay, to: lastDay).day ?? 0
        let totalDays = dayCount + 1

        // 生成连续日期的聚合数据
        var aggregatedData: [Date: (input: Int, output: Int)] = [:]
        for bucket in allBuckets {
            let day = calendar.startOfDay(for: bucket.day)
            let existing = aggregatedData[day] ?? (0, 0)
            aggregatedData[day] = (existing.input + bucket.inputTokens, existing.output + bucket.outputTokens)
        }

        // 计算窗口标题
        let title = String(
            format: String(localized: "last %lld days", defaultValue: "最近 %lld 天"),
            totalDays
        )

        // 生成柱状图数据
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
                format: String(
                    localized: "%1$@ · %2$@ tokens (in %3$@ / out %4$@)",
                    defaultValue: "%1$@ · %2$@ tokens（输入 %3$@ / 输出 %4$@）"
                ),
                formatter.string(from: day),
                TokenCountFormat.tokenCount(dayTotal),
                TokenCountFormat.tokenCount(usage.input),
                TokenCountFormat.tokenCount(usage.output)
            )

            bars.append(AppBarChartData.Bar(value: dayTotal, isHighlighted: isHighlighted, tooltip: tooltip))
        }

        let totalText = TokenCountFormat.tokenCount(totalTokens)
        let peakText = peakTokens > 0 ? String(
            format: String(localized: "peak %@", defaultValue: "峰值 %@"),
            TokenCountFormat.tokenCount(peakTokens)
        ) : nil

        let accessibilitySummary = String(
            format: String(
                localized: "%1$@, total %2$@ tokens, peak %3$@",
                defaultValue: "%1$@，共 %2$@ tokens，峰值 %3$@"
            ),
            title,
            totalText,
            TokenCountFormat.tokenCount(peakTokens)
        )

        return AppBarChartData(
            title: title,
            totalText: totalText,
            peakText: peakText,
            bars: bars,
            accessibilitySummary: accessibilitySummary
        )
    }

    static func emptyChartData() -> AppBarChartData {
        let title = String(localized: "No Usage Data", defaultValue: "暂无使用数据")
        return AppBarChartData(
            title: title,
            totalText: "0",
            peakText: nil,
            bars: [],
            accessibilitySummary: title
        )
    }

    static func chartData(from series: ModelDailyTokenSeries) -> AppBarChartData {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none

        let title = String(
            format: String(localized: "last %lld days", defaultValue: "最近 %lld 天"),
            series.buckets.count
        )
        let totalText = TokenCountFormat.tokenCount(series.totalTokens)
        let peakText: String? = series.peakTokens > 0
            ? String(
                format: String(localized: "peak %@", defaultValue: "峰值 %@"),
                TokenCountFormat.tokenCount(series.peakTokens)
            )
            : nil

        let bars = series.buckets.enumerated().map { index, bucket in
            AppBarChartData.Bar(
                value: bucket.totalTokens,
                isHighlighted: index == series.buckets.indices.last,
                tooltip: String(
                    format: String(
                        localized: "%1$@ · %2$@ tokens (in %3$@ / out %4$@)",
                        defaultValue: "%1$@ · %2$@ tokens（输入 %3$@ / 输出 %4$@）"
                    ),
                    formatter.string(from: bucket.day),
                    TokenCountFormat.tokenCount(bucket.totalTokens),
                    TokenCountFormat.tokenCount(bucket.inputTokens),
                    TokenCountFormat.tokenCount(bucket.outputTokens)
                )
            )
        }

        let accessibilitySummary = String(
            format: String(
                localized: "%1$@, total %2$@ tokens, peak %3$@",
                defaultValue: "%1$@，共 %2$@ tokens，峰值 %3$@"
            ),
            title,
            totalText,
            TokenCountFormat.tokenCount(series.peakTokens)
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
