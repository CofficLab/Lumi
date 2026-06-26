import Foundation

/// Presentation data for a compact vertical bar chart.
public struct AppBarChartData: Equatable, Sendable {
    public struct Bar: Equatable, Sendable {
        public let value: Int
        public let isHighlighted: Bool
        public let tooltip: String

        public init(value: Int, isHighlighted: Bool = false, tooltip: String) {
            self.value = value
            self.isHighlighted = isHighlighted
            self.tooltip = tooltip
        }
    }

    public let title: String
    public let totalText: String
    public let peakText: String?
    public let bars: [Bar]
    public let accessibilitySummary: String

    public init(
        title: String,
        totalText: String,
        peakText: String?,
        bars: [Bar],
        accessibilitySummary: String
    ) {
        self.title = title
        self.totalText = totalText
        self.peakText = peakText
        self.bars = bars
        self.accessibilitySummary = accessibilitySummary
    }
}
