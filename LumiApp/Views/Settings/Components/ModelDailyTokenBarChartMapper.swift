import Foundation
import LumiCoreKit
import LumiUI

enum ModelDailyTokenBarChartMapper {
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
