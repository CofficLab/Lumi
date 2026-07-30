import SwiftUI
import Charts
import LumiUI

/// Line chart view displaying daily token consumption over time.
public struct TokenLineChartView: View {
    public let data: [ActivityDayToken]
    public let isLoading: Bool

    @State private var shimmerPhase: CGFloat = -1.2
    @State private var hoveredPoint: ActivityDayToken?

    private let lineColor = Color(hex: "6db0f0")
    private let areaGradient = LinearGradient(
        colors: [
            Color(hex: "6db0f0").opacity(0.3),
            Color(hex: "6db0f0").opacity(0.05)
        ],
        startPoint: .top,
        endPoint: .bottom
    )

    public init(data: [ActivityDayToken], isLoading: Bool = false) {
        self.data = data
        self.isLoading = isLoading
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Title and total
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
        .onAppear {
            updateShimmerState()
        }
        .onChange(of: isLoading) { _, _ in
            updateShimmerState()
        }
    }

    @ViewBuilder
    private var chartContent: some View {
        if data.isEmpty {
            emptyState
        } else {
            Chart(data) { day in
                LineMark(
                    x: .value(LumiPluginLocalization.string("Date", bundle: .module), day.date),
                    y: .value(LumiPluginLocalization.string("Tokens", bundle: .module), day.totalTokens)
                )
                .foregroundStyle(lineColor)
                .lineStyle(StrokeStyle(lineWidth: 2))

                AreaMark(
                    x: .value(LumiPluginLocalization.string("Date", bundle: .module), day.date),
                    y: .value(LumiPluginLocalization.string("Tokens", bundle: .module), day.totalTokens)
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
            .chartOverlay { proxy in
                GeometryReader { geometry in
                    ZStack(alignment: .topLeading) {
                        Color.clear
                            .contentShape(Rectangle())
                            .onContinuousHover { phase in
                                switch phase {
                                case let .active(location):
                                    guard let plotFrameAnchor = proxy.plotFrame else {
                                        hoveredPoint = nil
                                        return
                                    }
                                    let plotFrame = geometry[plotFrameAnchor]
                                    let plotX = location.x - plotFrame.origin.x
                                    guard plotX >= 0, plotX <= plotFrame.width,
                                          let date: Date = proxy.value(atX: plotX) else {
                                        hoveredPoint = nil
                                        return
                                    }
                                    hoveredPoint = data.min {
                                        abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date))
                                    }
                                case .ended:
                                    hoveredPoint = nil
                                }
                            }

                        if let hoveredPoint,
                           let x = proxy.position(forX: hoveredPoint.date),
                           let y = proxy.position(forY: hoveredPoint.totalTokens),
                           let plotFrameAnchor = proxy.plotFrame {
                            let plotFrame = geometry[plotFrameAnchor]
                            Path { path in
                                path.move(to: CGPoint(x: x, y: plotFrame.minY))
                                path.addLine(to: CGPoint(x: x, y: plotFrame.maxY))
                            }
                            .stroke(lineColor.opacity(0.35), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))

                            Circle()
                                .fill(lineColor)
                                .frame(width: 9, height: 9)
                                .position(x: x, y: y)

                            VStack(alignment: .leading, spacing: 3) {
                                Text(Self.tooltipDateFormatter.string(from: hoveredPoint.date))
                                    .font(.system(size: 10, weight: .medium))
                                Text(String(format: LumiPluginLocalization.string("X: %@", bundle: .module), Self.tooltipDateFormatter.string(from: hoveredPoint.date)))
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                                Text(String(format: LumiPluginLocalization.string("Y: %@ tokens", bundle: .module), formatNumber(hoveredPoint.totalTokens)))
                                    .font(.system(size: 11, weight: .semibold))
                                    .monospacedDigit()
                            }
                            .padding(8)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                            .fixedSize()
                            .position(x: min(max(x, 78), max(geometry.size.width - 78, 78)), y: 38)
                        }
                    }
                }
            }
            .overlay {
                if isLoading {
                    loadingOverlay
                }
            }
        }
    }

    private var loadingOverlay: some View {
        GeometryReader { proxy in
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(.ultraThinMaterial.opacity(0.82))

                LinearGradient(
                    colors: [
                        .clear,
                        lineColor.opacity(0.08),
                        Color.white.opacity(0.22),
                        lineColor.opacity(0.08),
                        .clear,
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: proxy.size.width * 0.7)
                .rotationEffect(.degrees(12))
                .offset(x: shimmerPhase * proxy.size.width)
                .blur(radius: 8)

                VStack(spacing: 7) {
                    ProgressView()
                        .controlSize(.small)
                        .tint(lineColor)
                    Text(LumiPluginLocalization.string("Loading token data…", bundle: .module))
                        .font(.appCaption)
                        .foregroundStyle(.secondary)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .allowsHitTesting(false)
    }

    private func updateShimmerState() {
        guard isLoading else {
            shimmerPhase = -1.2
            return
        }

        shimmerPhase = -1.2
        withAnimation(.linear(duration: 1.8).repeatForever(autoreverses: false)) {
            shimmerPhase = 1.2
        }
    }

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

    private static let tooltipDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}

#Preview("With Data") {
    let cal = Calendar.current
    let today = Date()
    let sampleData: [ActivityDayToken] = (0..<30).compactMap { offset -> ActivityDayToken? in
        guard let date = cal.date(byAdding: .day, value: -offset, to: today) else { return nil }
        return ActivityDayToken(
            date: date,
            totalTokens: Int.random(in: 0...5000)
        )
    }.reversed()
    return TokenLineChartView(data: sampleData)
        .frame(width: 480, height: 200)
        .padding()
}

#Preview("Empty") {
    TokenLineChartView(data: [])
        .frame(width: 480, height: 200)
        .padding()
}
