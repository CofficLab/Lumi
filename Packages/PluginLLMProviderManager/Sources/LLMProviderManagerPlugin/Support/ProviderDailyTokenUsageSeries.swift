import Foundation
import KernelLumi

struct ProviderDailyTokenUsagePoint: Equatable, Sendable, Identifiable {
    let day: Date
    let inputTokens: Int
    let outputTokens: Int

    var id: Date { day }
    var totalTokens: Int { inputTokens + outputTokens }
}

struct ProviderDailyTokenUsageSeries: Equatable, Sendable {
    let providerID: String
    let points: [ProviderDailyTokenUsagePoint]

    var totalTokens: Int {
        points.reduce(0) { $0 + $1.totalTokens }
    }

    var peakTokens: Int {
        points.map(\.totalTokens).max() ?? 0
    }

    var hasData: Bool {
        totalTokens > 0
    }

    var inputTokens: Int {
        points.reduce(0) { $0 + $1.inputTokens }
    }

    var outputTokens: Int {
        points.reduce(0) { $0 + $1.outputTokens }
    }

    static func build(providerID: String, usages: [MessageTokenUsage]) -> ProviderDailyTokenUsageSeries {
        let points = usages
            .sorted { $0.day < $1.day }
            .map {
                ProviderDailyTokenUsagePoint(
                    day: $0.day,
                    inputTokens: $0.inputTokens,
                    outputTokens: $0.outputTokens
                )
            }
        return ProviderDailyTokenUsageSeries(providerID: providerID, points: points)
    }
}
